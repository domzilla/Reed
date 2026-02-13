//
//  RDHTMLTag.m
//  RDParser
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

#import "RDHTMLTag.h"

NSString *RDHTMLTagNameLink = @"link";
NSString *RDHTMLTagNameMeta = @"meta";

@implementation RDHTMLTag

- (instancetype)initWithType:(RDHTMLTagType)type attributes:(NSDictionary *)attributes {

	self = [super init];
	if (!self) {
		return nil;
	}

	_type = type;
	_attributes = attributes;
	
	return self;
}

+ (RDHTMLTag *)linkTagWithAttributes:(NSDictionary *)attributes {

	return [[self alloc] initWithType:RDHTMLTagTypeLink attributes:attributes];
}

+ (RDHTMLTag *)metaTagWithAttributes:(NSDictionary *)attributes {

	return [[self alloc] initWithType:RDHTMLTagTypeMeta attributes:attributes];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> type: %ld attributes: %@", NSStringFromClass([self class]), self, (long)self.type, self.attributes];
}

@end
