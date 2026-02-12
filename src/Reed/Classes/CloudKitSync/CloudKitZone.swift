//
//  CloudKitZone.swift
//  Core
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import CloudKit
import DZFoundation

enum CloudKitZoneError: LocalizedError, Sendable {
    case userDeletedZone
    case corruptAccount
    case unknown

    var errorDescription: String? {
        switch self {
        case .userDeletedZone:
            NSLocalizedString(
                "The iCloud data was deleted.  Please remove the application iCloud account and add it again to continue using the application's iCloud support.",
                comment: "User deleted zone."
            )
        case .corruptAccount:
            NSLocalizedString(
                "There is an unrecoverable problem with your application iCloud account. Please make sure you have iCloud and iCloud Drive enabled in System Preferences. Then remove the application iCloud account and add it again.",
                comment: "Corrupt account."
            )
        default:
            NSLocalizedString(
                "An unexpected CloudKit error occurred.",
                comment: "An unexpected CloudKit error occurred."
            )
        }
    }
}

// Wrapper to safely transfer non-Sendable values in @Sendable closures
// Generic over the Success type of the Result
private struct CloudKitZoneCaptures<Success>: @unchecked Sendable {
    weak var zone: (any CloudKitZone)?
    let completion: (Result<Success, Error>) -> Void
}

protocol CloudKitZoneDelegate: AnyObject {
    func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey]) async throws
}

typealias CloudKitRecordKey = (recordType: CKRecord.RecordType, recordID: CKRecord.ID)

@MainActor
protocol CloudKitZone: AnyObject {
    static var qualityOfService: QualityOfService { get }

    var zoneID: CKRecordZone.ID { get }

    var container: CKContainer? { get }
    var database: CKDatabase? { get }
    var delegate: CloudKitZoneDelegate? { get set }

    /// Reset the change token used to determine what point in time we are doing changes fetches
    func resetChangeToken()

    /// Generates a new CKRecord.ID using a UUID for the record's name
    func generateRecordID() -> CKRecord.ID

    /// Subscribe to changes at a zone level
    func subscribeToZoneChanges()

    /// Process a remove notification
    func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async
}

extension CloudKitZone {
    // .userInitiated is too aggressive on iOS and can lead the UI slowing down and appearing to block.
    static var qualityOfService: QualityOfService {
        .default
    }

    var oldChangeTokenKey: String {
        "cloudkit.server.token.\(zoneID.zoneName)"
    }

    var changeTokenKey: String {
        "cloudkit.server.token.\(zoneID.zoneName).\(zoneID.ownerName)"
    }

    var changeToken: CKServerChangeToken? {
        get {
            guard let tokenData = UserDefaults.standard.object(forKey: changeTokenKey) as? Data else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }
        set {
            guard
                let token = newValue, let data = try? NSKeyedArchiver.archivedData(
                    withRootObject: token,
                    requiringSecureCoding: false
                ) else
            {
                UserDefaults.standard.removeObject(forKey: self.changeTokenKey)
                return
            }
            UserDefaults.standard.set(data, forKey: self.changeTokenKey)
        }
    }

    /// Moves the change token to the new key name.  This can eventually be removed.
    func migrateChangeToken() {
        if
            let tokenData = UserDefaults.standard.object(forKey: oldChangeTokenKey) as? Data,
            let oldChangeToken = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: tokenData
            )
        {
            self.changeToken = oldChangeToken
            UserDefaults.standard.removeObject(forKey: self.oldChangeTokenKey)
        }
    }

    /// Reset the change token used to determine what point in time we are doing changes fetches
    func resetChangeToken() {
        self.changeToken = nil
    }

    func generateRecordID() -> CKRecord.ID {
        CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
    }

    func retryIfPossible(after: Double, block: @escaping @MainActor () -> Void) {
        let delayTime = DispatchTime.now() + after
        DispatchQueue.main.asyncAfter(deadline: delayTime) {
            block()
        }
    }

    func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
        let note = CKRecordZoneNotification(fromRemoteNotificationDictionary: userInfo)
        guard note?.recordZoneID?.zoneName == zoneID.zoneName else {
            return
        }

        do {
            try await self.fetchChangesInZone()
        } catch {
            DZLog("CloudKit: \(self.zoneID.zoneName) remote notification fetch error: \(error.localizedDescription)")
        }
    }

    /// Creates the zone record
    func createZoneRecord(completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        guard let database else {
            Task { @MainActor in
                completion(.failure(CloudKitZoneError.unknown))
            }
            return
        }

        database.save(CKRecordZone(zoneID: zoneID)) { _, error in
            Task { @MainActor in
                if let error {
                    completion(.failure(CloudKitError(error)))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    /// Subscribes to zone changes
    func subscribeToZoneChanges() {
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: zoneID.zoneName)

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        self.save(subscription) { result in
            if case let .failure(error) = result {
                DZLog(
                    "CloudKit: \(self.zoneID.zoneName) zone subscribe to changes error: \(error.localizedDescription)"
                )
            }
        }
    }

    /// Issue a CKQuery and return the resulting CKRecords.
    func query(
        _ ckQuery: CKQuery,
        desiredKeys: [String]? = nil,
        completion: @escaping (Result<[CKRecord], Error>) -> Void
    ) {
        var records = [CKRecord]()

        let op = CKQueryOperation(query: ckQuery)
        op.qualityOfService = Self.qualityOfService

        if let desiredKeys {
            op.desiredKeys = desiredKeys
        }

        op.recordMatchedBlock = { _, result in
            if let record = try? result.get() {
                records.append(record)
            }
        }

        op.queryResultBlock = { [weak self] result in
            guard let self else {
                completion(.failure(CloudKitZoneError.unknown))
                return
            }

            switch result {
            case let .success(cursor):
                DispatchQueue.main.async {
                    if let cursor {
                        self.query(
                            cursor: cursor,
                            desiredKeys: desiredKeys,
                            carriedRecords: records,
                            completion: completion
                        )
                    } else {
                        completion(.success(records))
                    }
                }
            case let .failure(error):
                switch CloudKitZoneResult.resolve(error) {
                case .success:
                    DispatchQueue.main.async {
                        completion(.success(records))
                    }
                case .zoneNotFound:
                    self.createZoneRecord { result in
                        switch result {
                        case .success:
                            self.query(ckQuery, desiredKeys: desiredKeys, completion: completion)
                        case let .failure(error):
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }
                case let .retry(timeToWait):
                    DZLog("CloudKit: \(self.zoneID.zoneName) zone query retry in \(timeToWait) seconds")
                    self.retryIfPossible(after: timeToWait) {
                        self.query(ckQuery, desiredKeys: desiredKeys, completion: completion)
                    }
                case .userDeletedZone:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitZoneError.userDeletedZone))
                    }
                default:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitError(error)))
                    }
                }
            }
        }

        database?.add(op)
    }

    /// Query CKRecords using a CKQuery Cursor
    func query(
        cursor: CKQueryOperation.Cursor,
        desiredKeys: [String]? = nil,
        carriedRecords: [CKRecord],
        completion: @escaping (Result<[CKRecord], Error>) -> Void
    ) {
        var records = carriedRecords

        let op = CKQueryOperation(cursor: cursor)
        op.qualityOfService = Self.qualityOfService

        if let desiredKeys {
            op.desiredKeys = desiredKeys
        }

        op.recordMatchedBlock = { _, result in
            if let record = try? result.get() {
                records.append(record)
            }
        }

        op.queryResultBlock = { [weak self] result in
            guard let self else {
                completion(.failure(CloudKitZoneError.unknown))
                return
            }

            switch result {
            case let .success(newCursor):
                DispatchQueue.main.async {
                    if let newCursor {
                        self.query(
                            cursor: newCursor,
                            desiredKeys: desiredKeys,
                            carriedRecords: records,
                            completion: completion
                        )
                    } else {
                        completion(.success(records))
                    }
                }
            case let .failure(error):
                switch CloudKitZoneResult.resolve(error) {
                case .success:
                    DispatchQueue.main.async {
                        completion(.success(records))
                    }
                case .zoneNotFound:
                    self.createZoneRecord { result in
                        switch result {
                        case .success:
                            self.query(
                                cursor: cursor,
                                desiredKeys: desiredKeys,
                                carriedRecords: records,
                                completion: completion
                            )
                        case let .failure(error):
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }
                case let .retry(timeToWait):
                    DZLog("CloudKit: \(self.zoneID.zoneName) zone query retry in \(timeToWait) seconds")
                    self.retryIfPossible(after: timeToWait) {
                        self.query(
                            cursor: cursor,
                            desiredKeys: desiredKeys,
                            carriedRecords: records,
                            completion: completion
                        )
                    }
                case .userDeletedZone:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitZoneError.userDeletedZone))
                    }
                default:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitError(error)))
                    }
                }
            }
        }

        database?.add(op)
    }

    /// Fetch a CKRecord by using its externalID
    func fetch(externalID: String?, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard let externalID else {
            completion(.failure(CloudKitZoneError.corruptAccount))
            return
        }

        let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)

        // Wrapper to safely transfer non-Sendable values in @Sendable closure
        let captures = CloudKitZoneCaptures(zone: self, completion: completion)

        database?.fetch(withRecordID: recordID) { record, error in
            Task { @MainActor in
                guard let self = captures.zone else {
                    captures.completion(.failure(CloudKitZoneError.unknown))
                    return
                }

                switch CloudKitZoneResult.resolve(error) {
                case .success:
                    DispatchQueue.main.async {
                        if let record {
                            captures.completion(.success(record))
                        } else {
                            captures.completion(.failure(CloudKitZoneError.unknown))
                        }
                    }
                case .zoneNotFound:
                    self.createZoneRecord { result in
                        switch result {
                        case .success:
                            self.fetch(externalID: externalID, completion: captures.completion)
                        case let .failure(error):
                            DispatchQueue.main.async {
                                captures.completion(.failure(error))
                            }
                        }
                    }
                case let .retry(timeToWait):
                    DZLog("CloudKit: \(self.zoneID.zoneName) zone fetch retry in \(timeToWait) seconds")
                    self.retryIfPossible(after: timeToWait) {
                        self.fetch(externalID: externalID, completion: captures.completion)
                    }
                case .userDeletedZone:
                    DispatchQueue.main.async {
                        captures.completion(.failure(CloudKitZoneError.userDeletedZone))
                    }
                default:
                    DispatchQueue.main.async {
                        captures.completion(.failure(CloudKitError(error!)))
                    }
                }
            }
        }
    }

    /// Save the CKRecord
    func save(_ record: CKRecord, completion: @escaping (Result<Void, Error>) -> Void) {
        self.modify(recordsToSave: [record], recordIDsToDelete: [], completion: completion)
    }

    /// Save the CKRecords
    func save(_ records: [CKRecord], completion: @escaping (Result<Void, Error>) -> Void) {
        self.modify(recordsToSave: records, recordIDsToDelete: [], completion: completion)
    }

    /// Saves or modifies the records as long as they are unchanged relative to the local version
    func saveIfNew(_ records: [CKRecord], completion: @escaping (Result<Void, Error>) -> Void) {
        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [CKRecord.ID]())
        op.savePolicy = .ifServerRecordUnchanged
        op.isAtomic = false
        op.qualityOfService = Self.qualityOfService

        op.modifyRecordsResultBlock = { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            case let .failure(error):
                switch CloudKitZoneResult.resolve(error) {
                case .success, .partialFailure:
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }

                case .zoneNotFound:
                    self.createZoneRecord { result in
                        switch result {
                        case .success:
                            self.saveIfNew(records, completion: completion)
                        case let .failure(error):
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }

                case .userDeletedZone:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitZoneError.userDeletedZone))
                    }

                case let .retry(timeToWait):
                    self.retryIfPossible(after: timeToWait) {
                        self.saveIfNew(records, completion: completion)
                    }

                case .limitExceeded:
                    var chunkedRecords = records.chunked(into: 200)

                    @MainActor
                    func saveChunksIfNew() {
                        if let records = chunkedRecords.popLast() {
                            self.saveIfNew(records) { result in
                                switch result {
                                case .success:
                                    DZLog("CloudKit: Saved \(records.count) chunked new records.")
                                    saveChunksIfNew()
                                case let .failure(error):
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            completion(.success(()))
                        }
                    }

                    saveChunksIfNew()

                default:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitError(error)))
                    }
                }
            }
        }

        database?.add(op)
    }

    /// Save the CKSubscription
    func save(_ subscription: CKSubscription, completion: @escaping (Result<CKSubscription, Error>) -> Void) {
        // Wrapper to safely transfer non-Sendable values in @Sendable closure
        let captures = CloudKitZoneCaptures(zone: self, completion: completion)

        database?.save(subscription) { savedSubscription, error in
            Task { @MainActor in
                guard let self = captures.zone else {
                    captures.completion(.failure(CloudKitZoneError.unknown))
                    return
                }

                switch CloudKitZoneResult.resolve(error) {
                case .success:
                    DispatchQueue.main.async {
                        captures.completion(.success(savedSubscription!))
                    }
                case .zoneNotFound:
                    self.createZoneRecord { result in
                        switch result {
                        case .success:
                            self.save(subscription, completion: captures.completion)
                        case let .failure(error):
                            DispatchQueue.main.async {
                                captures.completion(.failure(error))
                            }
                        }
                    }
                case let .retry(timeToWait):
                    DZLog("CloudKit: \(self.zoneID.zoneName) save subscription retry in \(timeToWait) seconds")
                    self.retryIfPossible(after: timeToWait) {
                        self.save(subscription, completion: captures.completion)
                    }
                default:
                    DispatchQueue.main.async {
                        captures.completion(.failure(CloudKitError(error!)))
                    }
                }
            }
        }
    }

    /// Delete CKRecords using a CKQuery
    func delete(ckQuery: CKQuery, completion: @escaping (Result<Void, Error>) -> Void) {
        var records = [CKRecord]()

        let op = CKQueryOperation(query: ckQuery)
        op.qualityOfService = Self.qualityOfService
        op.recordMatchedBlock = { _, result in
            if let record = try? result.get() {
                records.append(record)
            }
        }

        op.queryResultBlock = { [weak self] result in
            guard let self else {
                completion(.failure(CloudKitZoneError.unknown))
                return
            }

            switch result {
            case let .success(cursor):
                if let cursor {
                    self.delete(cursor: cursor, carriedRecords: records, completion: completion)
                } else {
                    guard !records.isEmpty else {
                        DispatchQueue.main.async {
                            completion(.success(()))
                        }
                        return
                    }

                    let recordIDs = records.map(\.recordID)
                    self.modify(recordsToSave: [], recordIDsToDelete: recordIDs, completion: completion)
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    completion(.failure(CloudKitError(error)))
                }
            }
        }

        database?.add(op)
    }

    /// Delete CKRecords using a CKQuery
    func delete(
        cursor: CKQueryOperation.Cursor,
        carriedRecords: [CKRecord],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var records = [CKRecord]()

        let op = CKQueryOperation(cursor: cursor)
        op.qualityOfService = Self.qualityOfService
        op.recordMatchedBlock = { _, result in
            if let record = try? result.get() {
                records.append(record)
            }
        }

        op.queryResultBlock = { [weak self] result in
            guard let self else {
                completion(.failure(CloudKitZoneError.unknown))
                return
            }

            switch result {
            case let .success(cursor):
                records.append(contentsOf: carriedRecords)

                if let cursor {
                    self.delete(cursor: cursor, carriedRecords: records, completion: completion)
                } else {
                    let recordIDs = records.map(\.recordID)
                    self.modify(recordsToSave: [], recordIDsToDelete: recordIDs, completion: completion)
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    completion(.failure(CloudKitError(error)))
                }
            }
        }

        database?.add(op)
    }

    /// Delete a CKRecord using its recordID
    func delete(recordID: CKRecord.ID, completion: @escaping (Result<Void, Error>) -> Void) {
        self.modify(recordsToSave: [], recordIDsToDelete: [recordID], completion: completion)
    }

    /// Delete CKRecords
    func delete(recordIDs: [CKRecord.ID], completion: @escaping (Result<Void, Error>) -> Void) {
        self.modify(recordsToSave: [], recordIDsToDelete: recordIDs, completion: completion)
    }

    /// Delete a CKRecord using its externalID
    func delete(externalID: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let externalID else {
            completion(.failure(CloudKitZoneError.corruptAccount))
            return
        }

        let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)
        self.modify(recordsToSave: [], recordIDsToDelete: [recordID], completion: completion)
    }

    /// Delete a CKSubscription
    func delete(subscriptionID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Wrapper to safely transfer non-Sendable values in @Sendable closure
        let captures = CloudKitZoneCaptures(zone: self, completion: completion)

        database?.delete(withSubscriptionID: subscriptionID) { _, error in
            Task { @MainActor in
                guard let self = captures.zone else {
                    captures.completion(.failure(CloudKitZoneError.unknown))
                    return
                }

                switch CloudKitZoneResult.resolve(error) {
                case .success:
                    DispatchQueue.main.async {
                        captures.completion(.success(()))
                    }
                case let .retry(timeToWait):
                    DZLog("CloudKit: \(self.zoneID.zoneName) delete subscription retry in \(timeToWait) seconds")
                    self.retryIfPossible(after: timeToWait) {
                        self.delete(subscriptionID: subscriptionID, completion: captures.completion)
                    }
                default:
                    DispatchQueue.main.async {
                        captures.completion(.failure(CloudKitError(error!)))
                    }
                }
            }
        }
    }

    /// Modify and delete the supplied CKRecords and CKRecord.IDs
    func modify(
        recordsToSave: [CKRecord],
        recordIDsToDelete: [CKRecord.ID],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !(recordsToSave.isEmpty && recordIDsToDelete.isEmpty) else {
            DispatchQueue.main.async {
                completion(.success(()))
            }
            return
        }

        let op = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
        op.savePolicy = .changedKeys
        op.isAtomic = true
        op.qualityOfService = Self.qualityOfService

        op.modifyRecordsResultBlock = { [weak self] result in
            guard let self else {
                completion(.failure(CloudKitZoneError.unknown))
                return
            }

            switch result {
            case .success:
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            case let .failure(error):
                switch CloudKitZoneResult.resolve(error) {
                case .success:
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                case .zoneNotFound:
                    self.createZoneRecord { result in
                        switch result {
                        case .success:
                            self.modify(
                                recordsToSave: recordsToSave,
                                recordIDsToDelete: recordIDsToDelete,
                                completion: completion
                            )
                        case let .failure(error):
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }
                case .userDeletedZone:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitZoneError.userDeletedZone))
                    }
                case let .retry(timeToWait):
                    DZLog("CloudKit: \(self.zoneID.zoneName) zone modify retry in \(timeToWait) seconds")
                    self.retryIfPossible(after: timeToWait) {
                        self.modify(
                            recordsToSave: recordsToSave,
                            recordIDsToDelete: recordIDsToDelete,
                            completion: completion
                        )
                    }
                case .limitExceeded:
                    var recordToSaveChunks = recordsToSave.chunked(into: 200)
                    var recordIDsToDeleteChunks = recordIDsToDelete.chunked(into: 200)

                    @MainActor
                    func saveChunks(completion: @escaping (Result<Void, Error>) -> Void) {
                        if !recordToSaveChunks.isEmpty {
                            let records = recordToSaveChunks.removeFirst()
                            self.modify(recordsToSave: records, recordIDsToDelete: []) { result in
                                switch result {
                                case .success:
                                    DZLog("CloudKit: Saved \(records.count) chunked records")
                                    saveChunks(completion: completion)
                                case let .failure(error):
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            completion(.success(()))
                        }
                    }

                    @MainActor
                    func deleteChunks() {
                        if !recordIDsToDeleteChunks.isEmpty {
                            let records = recordIDsToDeleteChunks.removeFirst()
                            self.modify(recordsToSave: [], recordIDsToDelete: records) { result in
                                switch result {
                                case .success:
                                    DZLog("CloudKit: Deleted \(records.count) chunked records")
                                    deleteChunks()
                                case let .failure(error):
                                    DispatchQueue.main.async {
                                        completion(.failure(error))
                                    }
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                completion(.success(()))
                            }
                        }
                    }

                    saveChunks { result in
                        switch result {
                        case .success:
                            deleteChunks()
                        case let .failure(error):
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }
                default:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitError(error)))
                    }
                }
            }
        }

        database?.add(op)
    }

    /// Fetch all the changes in the CKZone since the last time we checked
    func fetchChangesInZone(completion: @escaping (Result<Void, Error>) -> Void) {
        var savedChangeToken = self.changeToken

        var changedRecords = [CKRecord]()
        var deletedRecordKeys = [CloudKitRecordKey]()

        let zoneConfig = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        zoneConfig.previousServerChangeToken = self.changeToken
        let op = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: zoneConfig]
        )
        op.fetchAllChanges = true
        op.qualityOfService = Self.qualityOfService

        op.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            savedChangeToken = token
        }

        op.recordWasChangedBlock = { _, result in
            if let record = try? result.get() {
                changedRecords.append(record)
            }
        }

        op.recordWithIDWasDeletedBlock = { recordID, recordType in
            let recordKey = CloudKitRecordKey(recordType: recordType, recordID: recordID)
            deletedRecordKeys.append(recordKey)
        }

        op.recordZoneFetchResultBlock = { _, result in
            if case let .success((serverChangeToken, _, _)) = result {
                savedChangeToken = serverChangeToken
            }
        }

        op.fetchRecordZoneChangesResultBlock = { [weak self] result in
            guard let self else {
                completion(.failure(CloudKitZoneError.unknown))
                return
            }

            switch result {
            case .success:
                Task { @MainActor in
                    do {
                        try await self.delegate?.cloudKitDidModify(changed: changedRecords, deleted: deletedRecordKeys)
                        self.changeToken = savedChangeToken
                        completion(.success(()))
                    } catch {
                        completion(.failure(error))
                    }
                }
            case let .failure(error):
                switch CloudKitZoneResult.resolve(error) {
                case .success:
                    Task { @MainActor in
                        do {
                            try await self.delegate?.cloudKitDidModify(
                                changed: changedRecords,
                                deleted: deletedRecordKeys
                            )
                            self.changeToken = savedChangeToken
                            completion(.success(()))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                case .zoneNotFound:
                    self.createZoneRecord { result in
                        switch result {
                        case .success:
                            self.fetchChangesInZone(completion: completion)
                        case let .failure(error):
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }
                case .userDeletedZone:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitZoneError.userDeletedZone))
                    }
                case let .retry(timeToWait):
                    DZLog("CloudKit: \(self.zoneID.zoneName) zone fetch changes retry in \(timeToWait) seconds")
                    self.retryIfPossible(after: timeToWait) {
                        self.fetchChangesInZone(completion: completion)
                    }
                case .changeTokenExpired:
                    DispatchQueue.main.async {
                        self.changeToken = nil
                        self.fetchChangesInZone(completion: completion)
                    }
                default:
                    DispatchQueue.main.async {
                        completion(.failure(CloudKitError(error)))
                    }
                }
            }
        }

        database?.add(op)
    }

    // MARK: - Async Wrappers

    func createZoneRecord() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.createZoneRecord { result in
                continuation.resume(with: result)
            }
        }
    }

    func query(_ ckQuery: CKQuery, desiredKeys: [String]? = nil) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            self.query(ckQuery, desiredKeys: desiredKeys) { result in
                continuation.resume(with: result)
            }
        }
    }

    func fetch(externalID: String?) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            self.fetch(externalID: externalID) { result in
                continuation.resume(with: result)
            }
        }
    }

    func save(_ record: CKRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.save(record) { result in
                continuation.resume(with: result)
            }
        }
    }

    func save(_ records: [CKRecord]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.save(records) { result in
                continuation.resume(with: result)
            }
        }
    }

    func saveIfNew(_ records: [CKRecord]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.saveIfNew(records) { result in
                continuation.resume(with: result)
            }
        }
    }

    func save(_ subscription: CKSubscription) async throws -> CKSubscription {
        try await withCheckedThrowingContinuation { continuation in
            self.save(subscription) { result in
                continuation.resume(with: result)
            }
        }
    }

    func delete(ckQuery: CKQuery) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.delete(ckQuery: ckQuery) { result in
                continuation.resume(with: result)
            }
        }
    }

    func delete(recordID: CKRecord.ID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.delete(recordID: recordID) { result in
                continuation.resume(with: result)
            }
        }
    }

    func delete(recordIDs: [CKRecord.ID]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.delete(recordIDs: recordIDs) { result in
                continuation.resume(with: result)
            }
        }
    }

    func delete(externalID: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.delete(externalID: externalID) { result in
                continuation.resume(with: result)
            }
        }
    }

    func delete(subscriptionID: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.delete(subscriptionID: subscriptionID) { result in
                continuation.resume(with: result)
            }
        }
    }

    func modify(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.modify(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete) { result in
                continuation.resume(with: result)
            }
        }
    }

    func fetchChangesInZone() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.fetchChangesInZone { result in
                continuation.resume(with: result)
            }
        }
    }
}
