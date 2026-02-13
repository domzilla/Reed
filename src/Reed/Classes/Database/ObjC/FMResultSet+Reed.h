//
//  FMResultSet+Reed.h
//  RDDatabase
//
//  Created by Brent Simmons on 2/19/13.
//  Copyright (c) 2013 Ranchero Software, LLC. All rights reserved.
//


#import "FMResultSet.h"

NS_ASSUME_NONNULL_BEGIN

@interface FMResultSet (Reed)


- (NSArray *)rd_arrayForSingleColumnResultSet; // Doesn't handle dates.

- (NSSet *)rd_setForSingleColumnResultSet;

@end

NS_ASSUME_NONNULL_END
