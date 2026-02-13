//
//  RDHTMLMetadata.h
//  RDParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;
@import CoreGraphics;

@class RDHTMLMetadataFeedLink;
@class RDHTMLMetadataAppleTouchIcon;
@class RDHTMLMetadataFavicon;
@class RDHTMLOpenGraphProperties;
@class RDHTMLOpenGraphImage;
@class RDHTMLTag;
@class RDHTMLTwitterProperties;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface RDHTMLMetadata : NSObject

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RDHTMLTag *> *)tags;

@property (nonatomic, readonly) NSString *baseURLString;
@property (nonatomic, readonly) NSArray <RDHTMLTag *> *tags;

@property (nonatomic, readonly) NSArray <NSString *> *faviconLinks DEPRECATED_MSG_ATTRIBUTE("Use the favicons property instead.");
@property (nonatomic, readonly) NSArray <RDHTMLMetadataFavicon *> *favicons;
@property (nonatomic, readonly) NSArray <RDHTMLMetadataAppleTouchIcon *> *appleTouchIcons;
@property (nonatomic, readonly) NSArray <RDHTMLMetadataFeedLink *> *feedLinks;

@property (nonatomic, readonly) RDHTMLOpenGraphProperties *openGraphProperties;
@property (nonatomic, readonly) RDHTMLTwitterProperties *twitterProperties;

@end


@interface RDHTMLMetadataAppleTouchIcon : NSObject

@property (nonatomic, readonly) NSString *rel;
@property (nonatomic, nullable, readonly) NSString *sizes;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, nullable, readonly) NSString *urlString; // Absolute.

@end


@interface RDHTMLMetadataFeedLink : NSObject

@property (nonatomic, nullable, readonly) NSString *title;
@property (nonatomic, nullable, readonly) NSString *type;
@property (nonatomic, nullable, readonly) NSString *urlString; // Absolute.

@end

@interface RDHTMLMetadataFavicon : NSObject

@property (nonatomic, nullable, readonly) NSString *type;
@property (nonatomic, nullable, readonly) NSString *urlString;

@end

@interface RDHTMLOpenGraphProperties : NSObject

// TODO: the rest. At this writing (Nov. 26, 2017) I just care about og:image.
// See http://ogp.me/

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RDHTMLTag *> *)tags;

@property (nonatomic, readonly) NSArray <RDHTMLOpenGraphImage *> *images;

@end

@interface RDHTMLOpenGraphImage : NSObject

@property (nonatomic, nullable, readonly) NSString *url;
@property (nonatomic, nullable, readonly) NSString *secureURL;
@property (nonatomic, nullable, readonly) NSString *mimeType;
@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic, nullable, readonly) NSString *altText;

@end

@interface RDHTMLTwitterProperties : NSObject

// TODO: the rest. At this writing (Nov. 26, 2017) I just care about twitter:image:src.

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RDHTMLTag *> *)tags;

@property (nonatomic, nullable, readonly) NSString *imageURL; // twitter:image:src

@end

NS_ASSUME_NONNULL_END
