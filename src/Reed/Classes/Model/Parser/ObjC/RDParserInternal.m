//
//  RDParserInternal.m
//  RDParser
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//


#import "RDParserInternal.h"
#import <CommonCrypto/CommonDigest.h>


static BOOL RDParserIsNil(id obj) {
	
	return obj == nil || obj == [NSNull null];
}

BOOL RDParserObjectIsEmpty(id obj) {
	
	if (RDParserIsNil(obj)) {
		return YES;
	}
	
	if ([obj respondsToSelector:@selector(count)]) {
		return [obj count] < 1;
	}
	
	if ([obj respondsToSelector:@selector(length)]) {
		return [obj length] < 1;
	}
	
	return NO; /*Shouldn't get here very often.*/
}

BOOL RDParserStringIsEmpty(NSString *s) {
	
	return RDParserIsNil(s) || s.length < 1;
}


@implementation NSDictionary (RDParserInternal)

- (nullable id)rdparser_objectForCaseInsensitiveKey:(NSString *)key {
	
	id obj = self[key];
	if (obj) {
		return obj;
	}
	
	for (NSString *oneKey in self.allKeys) {
		
		if ([oneKey isKindOfClass:[NSString class]] && [key caseInsensitiveCompare:oneKey] == NSOrderedSame) {
			return self[oneKey];
		}
	}
	
	return nil;
}

@end
