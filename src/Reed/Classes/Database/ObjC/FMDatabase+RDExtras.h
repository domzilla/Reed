//
//  FMDatabase+QSKit.h
//  RDDatabase
//
//  Created by Brent Simmons on 3/3/14.
//  Copyright (c) 2014 Ranchero Software, LLC. All rights reserved.
//

#import "FMDatabase.h"

@import Foundation;

typedef NS_ENUM(NSInteger, RDDatabaseInsertType) {
	RDDatabaseInsertNormal,
	RDDatabaseInsertOrReplace,
	RDDatabaseInsertOrIgnore
};

NS_ASSUME_NONNULL_BEGIN

@interface FMDatabase (RDExtras)


// Keys and table names are assumed to be trusted. Values are not.


// delete from tableName where key in (?, ?, ?)

- (BOOL)rd_deleteRowsWhereKey:(NSString *)key inValues:(NSArray *)values tableName:(NSString *)tableName;

// delete from tableName where key=?

- (BOOL)rd_deleteRowsWhereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName;


// select * from tableName where key in (?, ?, ?)

- (FMResultSet * _Nullable)rd_selectRowsWhereKey:(NSString *)key inValues:(NSArray *)values tableName:(NSString *)tableName;

// select * from tableName where key = ?

- (FMResultSet * _Nullable)rd_selectRowsWhereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName;

// select * from tableName where key = ? limit 1

- (FMResultSet * _Nullable)rd_selectSingleRowWhereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName;

// select * from tableName

- (FMResultSet * _Nullable)rd_selectAllRows:(NSString *)tableName;

// select key from tableName;

- (FMResultSet * _Nullable)rd_selectColumnWithKey:(NSString *)key tableName:(NSString *)tableName;

// select 1 from tableName where key = value limit 1;

- (BOOL)rd_rowExistsWithValue:(id)value forKey:(NSString *)key tableName:(NSString *)tableName;

// select 1 from tableName limit 1;

- (BOOL)rd_tableIsEmpty:(NSString *)tableName;


// update tableName set key1=?, key2=? where key = value

- (BOOL)rd_updateRowsWithDictionary:(NSDictionary *)d whereKey:(NSString *)key equalsValue:(id)value tableName:(NSString *)tableName;

// update tableName set key1=?, key2=? where key in (?, ?, ?)

- (BOOL)rd_updateRowsWithDictionary:(NSDictionary *)d whereKey:(NSString *)key inValues:(NSArray *)keyValues tableName:(NSString *)tableName;

// update tableName set valueKey=? where where key in (?, ?, ?)

- (BOOL)rd_updateRowsWithValue:(id)value valueKey:(NSString *)valueKey whereKey:(NSString *)key inValues:(NSArray *)keyValues tableName:(NSString *)tableName;

// insert (or replace, or ignore) into tablename (key1, key2) values (val1, val2)

- (BOOL)rd_insertRowWithDictionary:(NSDictionary *)d insertType:(RDDatabaseInsertType)insertType tableName:(NSString *)tableName;

@end

NS_ASSUME_NONNULL_END
