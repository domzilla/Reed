//
//  NSString+RDParser.h
//  RDParser
//
//  Created by Brent Simmons on 9/25/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSString (RDParser)

- (NSString *)rdparser_stringByDecodingHTMLEntities;

/// Returns a copy of \c self with <, >, and & entity-encoded.
@property (readonly, copy)	NSString	*rdparser_stringByEncodingRequiredEntities;

- (NSString *)rdparser_md5Hash;

- (BOOL)rdparser_contains:(NSString *)s;

@end

NS_ASSUME_NONNULL_END
