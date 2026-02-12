//
//  RDParserInternal.h
//  RDParser
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

BOOL RDParserObjectIsEmpty(id _Nullable obj);
BOOL RDParserStringIsEmpty(NSString * _Nullable s);


@interface NSDictionary (RDParserInternal)

- (nullable id)rdparser_objectForCaseInsensitiveKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

