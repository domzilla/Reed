//
//  RDHTMLTag.h
//  RDParser
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

extern NSString *RDHTMLTagNameLink; // @"link"
extern NSString *RDHTMLTagNameMeta; // @"meta"

typedef NS_ENUM(NSInteger, RDHTMLTagType) {
	RDHTMLTagTypeLink,
	RDHTMLTagTypeMeta
};

@interface RDHTMLTag : NSObject

- (instancetype)initWithType:(RDHTMLTagType)type attributes:(NSDictionary *)attributes;

+ (RDHTMLTag *)linkTagWithAttributes:(NSDictionary *)attributes;
+ (RDHTMLTag *)metaTagWithAttributes:(NSDictionary *)attributes;

@property (nonatomic, readonly) RDHTMLTagType type;
@property (nonatomic, readonly) NSDictionary *attributes;

@end

NS_ASSUME_NONNULL_END
