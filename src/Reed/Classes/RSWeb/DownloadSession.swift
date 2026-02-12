//
//  DownloadSession.swift
//  RSWeb
//
//  Created by Brent Simmons on 3/12/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import DZFoundation
import Foundation

// Create a DownloadSessionDelegate, then create a DownloadSession.
// To download things: call download with a set of URLs. DownloadSession will call the various delegate methods.

@MainActor
protocol DownloadSessionDelegate {
    func downloadSession(_ downloadSession: DownloadSession, conditionalGetInfoFor: URL) -> HTTPConditionalGetInfo?
    func downloadSession(
        _ downloadSession: DownloadSession,
        downloadDidComplete: URL,
        response: URLResponse?,
        data: Data,
        error: NSError?
    )
    func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData: Data, url: URL) -> Bool
    func downloadSessionDidComplete(_ downloadSession: DownloadSession)
}

struct HTTP4xxResponse {
    let statusCode: Int
    let date: Date

    init(_ statusCode: Int) {
        self.statusCode = statusCode
        self.date = Date()
    }
}

@MainActor @objc
final class DownloadSession: NSObject {
    let downloadProgress = DownloadProgress(numberOfTasks: 0)
    private var urlSession: URLSession!
    private var tasksInProgress = Set<URLSessionTask>()
    private var tasksPending = Set<URLSessionTask>()
    private var taskIdentifierToInfoDictionary = [Int: DownloadInfo]()
    private var urlsInSession = Set<URL>()
    private let delegate: DownloadSessionDelegate
    private var redirectCache = [URL: URL]()
    private var queue = [URL]()
    private let cache = DownloadCache.shared

    // 429 Too Many Requests responses
    private var retryAfterMessages = [String: HTTPResponse429]()

    /// URLs with 400-499 responses (except for 429).
    /// These URLs are skipped for a period of time.
    private var http4xxResponses = [URL: HTTP4xxResponse]()

    init(delegate: DownloadSessionDelegate) {
        self.delegate = delegate

        super.init()

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfiguration.timeoutIntervalForRequest = 15.0
        sessionConfiguration.httpShouldSetCookies = false
        sessionConfiguration.httpCookieAcceptPolicy = .never
        sessionConfiguration.httpMaximumConnectionsPerHost = 1
        sessionConfiguration.httpCookieStorage = nil
        sessionConfiguration.urlCache = nil

        if let userAgentHeaders = UserAgent.headers() {
            sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
        }

        self.urlSession = URLSession(
            configuration: sessionConfiguration,
            delegate: self,
            delegateQueue: OperationQueue.main
        )
    }

    deinit {
        urlSession.invalidateAndCancel()
    }

    // MARK: - API

    func cancelAll() {
        self.urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            dataTasks.forEach { $0.cancel() }
            uploadTasks.forEach { $0.cancel() }
            downloadTasks.forEach { $0.cancel() }
        }
    }

    @MainActor
    func download(_ urls: Set<URL>) {
        cleanUp4xxResponsesCache()

        let filteredURLs = Self.filteredURLs(urls)
        for url in filteredURLs {
            addDataTask(url)
        }

        self.urlsInSession = filteredURLs
        updateDownloadProgress()
    }
}

// MARK: - URLSessionTaskDelegate

extension DownloadSession: @preconcurrency URLSessionTaskDelegate {
    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        MainActor.assumeIsolated {
            defer {
                removeTask(task)
            }

            guard let info = infoForTask(task) else {
                if let url = task.originalRequest?.url {
                    DZLog("DownloadSession: no task info found for \(url)")
                } else {
                    DZLog("DownloadSession: no task info found for unknown URL")
                }
                return
            }

            if let url = task.originalRequest?.url, error == nil {
                DZLog("DownloadSession: Caching response for \(url)")
                self.cache.add(url.absoluteString, data: info.data as Data, response: info.urlResponse)
            }

            self.delegate.downloadSession(
                self,
                downloadDidComplete: info.url,
                response: info.urlResponse,
                data: info.data as Data,
                error: error as NSError?
            )
        }
    }

    private static let redirectStatusCodes = Set([
        HTTPResponseCode.redirectPermanent,
        HTTPResponseCode.redirectTemporary,
        HTTPResponseCode.redirectVeryTemporary,
        HTTPResponseCode.redirectPermanentPreservingMethod,
    ])

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if Self.redirectStatusCodes.contains(response.statusCode) {
            if let oldURL = task.originalRequest?.url, let newURL = request.url {
                cacheRedirect(oldURL, newURL)
            }
        }

        var modifiedRequest = request

        modifiedRequest.addSpecialCaseUserAgentIfNeeded()

        completionHandler(modifiedRequest)
    }
}

// MARK: - URLSessionDataDelegate

extension DownloadSession: @preconcurrency URLSessionDataDelegate {
    func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        MainActor.assumeIsolated {
            defer {
                updateDownloadProgress()
            }

            self.tasksInProgress.insert(dataTask)
            self.tasksPending.remove(dataTask)

            let taskInfo = infoForTask(dataTask)
            if let taskInfo {
                taskInfo.urlResponse = response
            }

            let statusCode = response.forcedStatusCode
            if statusCode >= 400 {
                if statusCode != HTTPResponseCode.tooManyRequests {
                    if let urlString = response.url?.absoluteString {
                        DZLog("DownloadSession: Caching >= 400 response for \(urlString)")
                        self.cache.add(urlString, data: nil, response: response)
                    }
                }

                DZLog("DownloadSession: canceling task due to >= 400 response \(response)")

                completionHandler(.cancel)
                removeTask(dataTask)

                if statusCode == HTTPResponseCode.tooManyRequests {
                    handle429Response(dataTask, response)
                } else if (400...499).contains(statusCode), let url = response.url {
                    self.http4xxResponses[url] = HTTP4xxResponse(statusCode)
                }

                return
            }

            addDataTaskFromQueueIfNecessary()
            completionHandler(.allow)
        }
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        MainActor.assumeIsolated {
            guard let info = infoForTask(dataTask) else {
                return
            }
            info.addData(data)

            if
                !self.delegate
                    .downloadSession(self, shouldContinueAfterReceivingData: info.data as Data, url: info.url)
            {
                dataTask.cancel()
                removeTask(dataTask)
            }
        }
    }
}

// MARK: - Private

extension DownloadSession {
    @MainActor
    private func addDataTask(_ url: URL) {
        guard self.tasksPending.count < 500 else {
            self.queue.insert(url, at: 0)
            return
        }

        // If received permanent redirect earlier, use that URL.
        let urlToUse = self.cachedRedirect(for: url) ?? url

        if self.requestShouldBeDroppedDueToActive429(urlToUse) {
            DZLog("DownloadSession: Dropping request for previous 429: \(urlToUse)")
            return
        }
        if self.requestShouldBeDroppedDueToPrevious400(urlToUse) {
            DZLog("DownloadSession: Dropping request for previous 400-499: \(urlToUse)")
            return
        }

        // Check cache
        if let cachedResponse = cache[urlToUse.absoluteString] {
            DZLog(
                "DownloadSession: using cached response for \(urlToUse) - \(cachedResponse.response?.forcedStatusCode ?? -1)"
            )
            self.delegate.downloadSession(
                self,
                downloadDidComplete: url,
                response: cachedResponse.response,
                data: cachedResponse.data ?? Data(),
                error: nil
            )
            return
        }

        let urlRequest: URLRequest = {
            var request = URLRequest(url: urlToUse)
            if let conditionalGetInfo = delegate.downloadSession(self, conditionalGetInfoFor: url) {
                conditionalGetInfo.addRequestHeadersToURLRequest(&request)
            }
            request.addSpecialCaseUserAgentIfNeeded()
            return request
        }()

        DZLog("DownloadSession: adding dataTask for \(urlToUse)")
        let task = self.urlSession.dataTask(with: urlRequest)

        let info = DownloadInfo(url)
        self.taskIdentifierToInfoDictionary[task.taskIdentifier] = info

        self.tasksPending.insert(task)
        task.resume()
    }

    @MainActor
    private func addDataTaskFromQueueIfNecessary() {
        guard self.tasksPending.count < 500, let url = queue.popLast() else { return }
        self.addDataTask(url)
    }

    private func infoForTask(_ task: URLSessionTask) -> DownloadInfo? {
        self.taskIdentifierToInfoDictionary[task.taskIdentifier]
    }

    @MainActor
    private func removeTask(_ task: URLSessionTask) {
        self.tasksInProgress.remove(task)
        self.tasksPending.remove(task)
        self.taskIdentifierToInfoDictionary[task.taskIdentifier] = nil

        self.addDataTaskFromQueueIfNecessary()

        self.updateDownloadProgress()
    }

    private func urlStringIsBlackListedRedirect(_ urlString: String) -> Bool {
        // Hotels and similar often do permanent redirects. We can catch some of those.

        let s = urlString.lowercased()
        let badStrings = [
            "solutionip",
            "lodgenet",
            "monzoon",
            "landingpage",
            "btopenzone",
            "register",
            "login",
            "authentic",
        ]

        for oneBadString in badStrings {
            if s.contains(oneBadString) {
                return true
            }
        }

        return false
    }

    private func cacheRedirect(_ oldURL: URL, _ newURL: URL) {
        if self.urlStringIsBlackListedRedirect(newURL.absoluteString) {
            return
        }
        self.redirectCache[oldURL] = newURL
    }

    private func cachedRedirect(for url: URL) -> URL? {
        // Follow chains of redirects, but avoid loops.

        var urls = Set<URL>()
        urls.insert(url)

        var currentURL = url

        while true {
            if let oneRedirectURL = redirectCache[currentURL] {
                if urls.contains(oneRedirectURL) {
                    // Cycle. Bail.
                    return nil
                }
                urls.insert(oneRedirectURL)
                currentURL = oneRedirectURL
            }

            else {
                break
            }
        }

        if currentURL == url {
            return nil
        }
        return currentURL
    }

    // MARK: - Download Progress

    @MainActor
    private func updateDownloadProgress() {
        let numberRemaining = self.tasksPending.count + self.tasksInProgress.count + self.queue.count

        if self.urlsInSession.count > 0, numberRemaining < 1 {
            self.urlsInSession.removeAll()
            self.delegate.downloadSessionDidComplete(self)
        }
    }

    // MARK: - 429 Too Many Requests

    @MainActor
    private func handle429Response(_ dataTask: URLSessionDataTask, _ response: URLResponse) {
        guard let message = createHTTPResponse429(dataTask, response) else {
            return
        }

        self.retryAfterMessages[message.host] = message
        self.cancelAndRemoveTasksWithHost(message.host)
    }

    private func createHTTPResponse429(_ dataTask: URLSessionDataTask, _ response: URLResponse) -> HTTPResponse429? {
        guard let url = dataTask.currentRequest?.url ?? dataTask.originalRequest?.url else {
            return nil
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return nil
        }
        guard let retryAfterValue = httpResponse.value(forHTTPHeaderField: HTTPResponseHeader.retryAfter) else {
            return nil
        }
        guard let retryAfter = TimeInterval(retryAfterValue), retryAfter > 0 else {
            return nil
        }

        return HTTPResponse429(url: url, retryAfter: retryAfter)
    }

    @MainActor
    private func cancelAndRemoveTasksWithHost(_ host: String) {
        self.cancelAndRemoveTasksWithHost(host, in: self.tasksInProgress)
        self.cancelAndRemoveTasksWithHost(host, in: self.tasksPending)
    }

    @MainActor
    private func cancelAndRemoveTasksWithHost(_ host: String, in tasks: Set<URLSessionTask>) {
        let lowercaseHost = host.lowercased(with: localeForLowercasing)

        let tasksToRemove = tasks.filter { task in
            if let taskHost = task.lowercaseHost, taskHost.contains(lowercaseHost) {
                return false
            }
            return true
        }

        for task in tasksToRemove {
            task.cancel()
        }
        for task in tasksToRemove {
            self.removeTask(task)
        }
    }

    private func requestShouldBeDroppedDueToActive429(_ url: URL) -> Bool {
        guard let host = url.host() else {
            return false
        }
        guard let retryAfterMessage = retryAfterMessages[host] else {
            return false
        }

        if retryAfterMessage.resumeDate < Date() {
            self.retryAfterMessages[host] = nil
            return false
        }

        return true
    }

    // MARK: - 400-499 responses

    // Remove 4xx responses placed in the cache more than a while ago.
    private func cleanUp4xxResponsesCache() {
        let oldDate = Date().bySubtracting(hours: 53)

        for url in self.http4xxResponses.keys {
            guard let response = http4xxResponses[url] else {
                continue
            }
            if response.date < oldDate {
                self.http4xxResponses[url] = nil
            }
        }
    }

    private func requestShouldBeDroppedDueToPrevious400(_ url: URL) -> Bool {
        if self.http4xxResponses[url] != nil {
            return true
        }
        if let redirectedURL = cachedRedirect(for: url), http4xxResponses[redirectedURL] != nil {
            return true
        }

        return false
    }

    // MARK: - Filtering URLs

    private static let lastOpenRSSOrgFeedRefreshKey = "lastOpenRSSOrgFeedRefresh"
    private static var lastOpenRSSOrgFeedRefresh: Date {
        get {
            UserDefaults.standard.value(forKey: lastOpenRSSOrgFeedRefreshKey) as? Date ?? Date.distantPast
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: lastOpenRSSOrgFeedRefreshKey)
        }
    }

    private static var canDownloadFromOpenRSSOrg: Bool {
        let okayToDownloadDate = lastOpenRSSOrgFeedRefresh + TimeInterval(60 * 60 * 10) // 10 minutes (arbitrary)
        return Date() > okayToDownloadDate
    }

    fileprivate static func filteredURLs(_ urls: Set<URL>) -> Set<URL> {
        // Possibly remove some openrss.org URLs.
        // Can be extended later if necessary.

        if self.canDownloadFromOpenRSSOrg {
            // Allow only one feed from openrss.org per refresh session
            self.lastOpenRSSOrgFeedRefresh = Date()
            return urls.byRemovingAllButOneRandomOpenRSSOrgURL()
        }

        return urls.byRemovingOpenRSSOrgURLs()
    }
}

extension URLSessionTask {
    var lowercaseHost: String? {
        guard let request = currentRequest ?? originalRequest else {
            return nil
        }
        return request.url?.host()?.lowercased(with: localeForLowercasing)
    }
}

// MARK: - DownloadInfo

private final class DownloadInfo {
    let url: URL
    let data = NSMutableData()
    var urlResponse: URLResponse?

    init(_ url: URL) {
        self.url = url
    }

    func addData(_ d: Data) {
        self.data.append(d)
    }
}
