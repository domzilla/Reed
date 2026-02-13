//
//  RDOPMLItem.h
//  RDParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@class RDOPMLFeedSpecifier;

NS_ASSUME_NONNULL_BEGIN

@interface RDOPMLItem : NSObject

@property (nonatomic, nullable) NSDictionary *attributes;
@property (nonatomic, nullable) NSArray <RDOPMLItem *> *children;

- (void)addChild:(RDOPMLItem *)child;

@property (nonatomic, nullable, readonly) RDOPMLFeedSpecifier *feedSpecifier;

@property (nonatomic, nullable, readonly) NSString *titleFromAttributes;
@property (nonatomic, readonly) BOOL isFolder;

@end

NS_ASSUME_NONNULL_END

