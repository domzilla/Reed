//
//  FMResultSet+Reed.m
//  RDDatabase
//
//  Created by Brent Simmons on 2/19/13.
//  Copyright (c) 2013 Ranchero Software, LLC. All rights reserved.
//

#import "FMResultSet+Reed.h"


@implementation FMResultSet (Reed)


- (id)valueForKey:(NSString *)key {

	if ([key containsString:@"Date"] || [key containsString:@"date"]) {
		return [self dateForColumn:key];
	}
	
    return [self objectForColumnName:key];
}


- (NSArray *)rd_arrayForSingleColumnResultSet {

	NSMutableArray *results = [NSMutableArray new];

	while ([self next]) {
		id oneObject = [self objectForColumnIndex:0];
		[results addObject:oneObject];
	}

	return [results copy];
}


- (NSSet *)rd_setForSingleColumnResultSet {
	
	NSMutableSet *results = [NSMutableSet new];
	
	while ([self next]) {
		id oneObject = [self objectForColumnIndex:0];
		[results addObject:oneObject];
	}
	
	return [results copy];
}


@end
