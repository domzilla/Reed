//
//  RDHTMLMetadata.m
//  RDParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RDHTMLMetadata.h"
#import "RDParserInternal.h"
#import "RDHTMLTag.h"



static NSString *urlStringFromDictionary(NSDictionary *d);
static NSString *absoluteURLStringWithRelativeURLString(NSString *relativeURLString, NSString *baseURLString);
static NSString *absoluteURLStringWithDictionary(NSDictionary *d, NSString *baseURLString);
static NSArray *objectsOfClassWithTags(Class class, NSArray *tags, NSString *baseURLString);
static NSString *relValue(NSDictionary *d);
static BOOL typeIsFeedType(NSString *type);

static NSString *kIconRelValue = @"icon";
static NSString *kHrefKey = @"href";
static NSString *kSrcKey = @"src";
static NSString *kAppleTouchIconValue = @"apple-touch-icon";
static NSString *kAppleTouchIconPrecomposedValue = @"apple-touch-icon-precomposed";
static NSString *kSizesKey = @"sizes";
static NSString *kTitleKey = @"title";
static NSString *kRelKey = @"rel";
static NSString *kAlternateKey = @"alternate";
static NSString *kRSSSuffix = @"/rss+xml";
static NSString *kAtomSuffix = @"/atom+xml";
static NSString *kJSONSuffix = @"/json";
static NSString *kTypeKey = @"type";

@interface RDHTMLMetadataAppleTouchIcon ()

- (instancetype)initWithTag:(RDHTMLTag *)tag baseURLString:(NSString *)baseURLString;

@end


@interface RDHTMLMetadataFeedLink ()

- (instancetype)initWithTag:(RDHTMLTag *)tag baseURLString:(NSString *)baseURLString;

@end

@interface RDHTMLMetadataFavicon ()

- (instancetype)initWithTag:(RDHTMLTag *)tag baseURLString:(NSString *)baseURLString;

@end

@implementation RDHTMLMetadata

#pragma mark - Init

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RDHTMLTag *> *)tags {

	self = [super init];
	if (!self) {
		return nil;
	}

	_baseURLString = urlString;
	_tags = tags;

	_favicons = [self resolvedFaviconLinks];
	
	NSArray *appleTouchIconTags = [self appleTouchIconTags];
	_appleTouchIcons = objectsOfClassWithTags([RDHTMLMetadataAppleTouchIcon class], appleTouchIconTags, urlString);

	NSArray *feedLinkTags = [self feedLinkTags];
	_feedLinks = objectsOfClassWithTags([RDHTMLMetadataFeedLink class], feedLinkTags, urlString);

	_openGraphProperties = [[RDHTMLOpenGraphProperties alloc] initWithURLString:urlString tags:tags];
	_twitterProperties = [[RDHTMLTwitterProperties alloc] initWithURLString:urlString tags:tags];
	
	return self;
}

#pragma mark - Private

- (NSArray<RDHTMLTag *> *)linkTagsWithMatchingRel:(NSString *)valueToMatch {

	// Case-insensitive; matches a whitespace-delimited word

	NSMutableArray<RDHTMLTag *> *tags = [NSMutableArray array];

	for (RDHTMLTag *tag in self.tags) {

		if (tag.type != RDHTMLTagTypeLink || RDParserStringIsEmpty(urlStringFromDictionary(tag.attributes))) {
			continue;
		}
		NSString *oneRelValue = relValue(tag.attributes);
		if (oneRelValue) {
			NSArray *relValues = [oneRelValue componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

			for (NSString *relValue in relValues) {
				if ([relValue compare:valueToMatch options:NSCaseInsensitiveSearch] == NSOrderedSame) {
					[tags addObject:tag];
					break;
				}
			}
		}
	}

	return tags;
}


- (NSArray<RDHTMLTag *> *)appleTouchIconTags {

	NSMutableArray *tags = [NSMutableArray new];

	for (RDHTMLTag *tag in self.tags) {

		if (tag.type != RDHTMLTagTypeLink) {
			continue;
		}
		NSString *oneRelValue = relValue(tag.attributes).lowercaseString;
		if ([oneRelValue isEqualToString:kAppleTouchIconValue] || [oneRelValue isEqualToString:kAppleTouchIconPrecomposedValue]) {
			[tags addObject:tag];
		}
	}

	return tags;
}


- (NSArray<RDHTMLTag *> *)feedLinkTags {

	NSMutableArray *tags = [NSMutableArray new];

	for (RDHTMLTag *tag in self.tags) {

		if (tag.type != RDHTMLTagTypeLink) {
			continue;
		}

		NSDictionary *oneDictionary = tag.attributes;
		NSString *oneRelValue = relValue(oneDictionary).lowercaseString;
		if (![oneRelValue isEqualToString:kAlternateKey]) {
			continue;
		}

		NSString *oneType = [oneDictionary rdparser_objectForCaseInsensitiveKey:kTypeKey];
		if (!typeIsFeedType(oneType)) {
			continue;
		}

		if (RDParserStringIsEmpty(urlStringFromDictionary(oneDictionary))) {
			continue;
		}

		[tags addObject:tag];
	}

	return tags;
}

- (NSArray<NSString *> *)faviconLinks {
	NSMutableArray *urls = [NSMutableArray array];

	for (RDHTMLMetadataFavicon *favicon in self.favicons) {
		[urls addObject:favicon.urlString];
	}

	return urls;
}

- (NSArray<RDHTMLMetadataFavicon *> *)resolvedFaviconLinks {
	NSArray<RDHTMLTag *> *tags = [self linkTagsWithMatchingRel:kIconRelValue];
	NSMutableArray *links = [NSMutableArray array];
	NSMutableSet<NSString *> *seenHrefs = [NSMutableSet setWithCapacity:tags.count];

	for (RDHTMLTag *tag in tags) {
		RDHTMLMetadataFavicon *link = [[RDHTMLMetadataFavicon alloc] initWithTag:tag baseURLString:self.baseURLString];
		NSString *urlString = link.urlString;
		if (urlString == nil) {
			continue;
		}
		if (![seenHrefs containsObject:urlString]) {
			[links addObject:link];
			[seenHrefs addObject:urlString];
		}
	}

	return links;
}

@end


static NSString *relValue(NSDictionary *d) {

	return [d rdparser_objectForCaseInsensitiveKey:kRelKey];
}


static NSString *urlStringFromDictionary(NSDictionary *d) {

	NSString *urlString = [d rdparser_objectForCaseInsensitiveKey:kHrefKey];
	if (urlString) {
		return urlString;
	}

	return [d rdparser_objectForCaseInsensitiveKey:kSrcKey];
}


static NSString *absoluteURLStringWithRelativeURLString(NSString *relativeURLString, NSString *baseURLString) {

	NSURL *url = [NSURL URLWithString:baseURLString];
	if (!url) {
		return nil;
	}

	NSURL *absoluteURL = [NSURL URLWithString:relativeURLString relativeToURL:url];
	return absoluteURL.absoluteURL.standardizedURL.absoluteString;
}


static NSString *absoluteURLStringWithDictionary(NSDictionary *d, NSString *baseURLString) {

	NSString *urlString = urlStringFromDictionary(d);
	if (RDParserStringIsEmpty(urlString)) {
		return nil;
	}
	return absoluteURLStringWithRelativeURLString(urlString, baseURLString);
}


static NSArray *objectsOfClassWithTags(Class class, NSArray *tags, NSString *baseURLString) {

	NSMutableArray *objects = [NSMutableArray new];

	for (RDHTMLTag *tag in tags) {

		id oneObject = [[class alloc] initWithTag:tag baseURLString:baseURLString];
		if (oneObject) {
			[objects addObject:oneObject];
		}
	}

	return objects;
}


static BOOL typeIsFeedType(NSString *type) {

	type = type.lowercaseString;
	return [type hasSuffix:kRSSSuffix] || [type hasSuffix:kAtomSuffix] || [type hasSuffix:kJSONSuffix];
}


@implementation RDHTMLMetadataAppleTouchIcon

- (instancetype)initWithTag:(RDHTMLTag *)tag baseURLString:(NSString *)baseURLString {

	self = [super init];
	if (!self) {
		return nil;
	}

	NSDictionary *d = tag.attributes;
	_urlString = absoluteURLStringWithDictionary(d, baseURLString);
	_sizes = [d rdparser_objectForCaseInsensitiveKey:kSizesKey];
	_rel = [d rdparser_objectForCaseInsensitiveKey:kRelKey];

	_size = CGSizeZero;
	if (_sizes) {
		NSArray *components = [_sizes componentsSeparatedByString:@"x"];
		if (components.count == 2) {
			CGFloat width = [components[0] floatValue];
			CGFloat height = [components[1] floatValue];
			_size = CGSizeMake(width, height);
		}
	}
	
	return self;
}

@end


@implementation RDHTMLMetadataFeedLink

- (instancetype)initWithTag:(RDHTMLTag *)tag baseURLString:(NSString *)baseURLString {

	self = [super init];
	if (!self) {
		return nil;
	}

	NSDictionary *d = tag.attributes;
	_urlString = absoluteURLStringWithDictionary(d, baseURLString);
	_title = [d rdparser_objectForCaseInsensitiveKey:kTitleKey];
	_type = [d rdparser_objectForCaseInsensitiveKey:kTypeKey];

	return self;
}

@end

@implementation RDHTMLMetadataFavicon

- (instancetype)initWithTag:(RDHTMLTag *)tag baseURLString:(NSString *)baseURLString {

	self = [super init];
	if (!self) {
		return nil;
	}

	NSDictionary *d = tag.attributes;
	_urlString = absoluteURLStringWithDictionary(d, baseURLString);
	_type = [d rdparser_objectForCaseInsensitiveKey:kTypeKey];

	return self;
}

@end

@interface RDHTMLOpenGraphImage ()

@property (nonatomic, readwrite) NSString *url;
@property (nonatomic, readwrite) NSString *secureURL;
@property (nonatomic, readwrite) NSString *mimeType;
@property (nonatomic, readwrite) CGFloat width;
@property (nonatomic, readwrite) CGFloat height;
@property (nonatomic, readwrite) NSString *altText;

@end

@implementation RDHTMLOpenGraphImage


@end

@interface RDHTMLOpenGraphProperties ()

@property (nonatomic) NSMutableArray *ogImages;
@end

@implementation RDHTMLOpenGraphProperties

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RDHTMLTag *> *)tags {

	self = [super init];
	if (!self) {
		return nil;
	}

	_ogImages = [NSMutableArray new];

	[self parseTags:tags];
	return self;
}


- (RDHTMLOpenGraphImage *)currentImage {

	return self.ogImages.lastObject;
}


- (RDHTMLOpenGraphImage *)pushImage {

	RDHTMLOpenGraphImage *image = [RDHTMLOpenGraphImage new];
	[self.ogImages addObject:image];
	return image;
}

- (RDHTMLOpenGraphImage *)ensureImage {

	RDHTMLOpenGraphImage *image = [self currentImage];
	if (image != nil) {
		return image;
	}
	return [self pushImage];
}


- (NSArray *)images {

	return self.ogImages;
}

static NSString *ogPrefix = @"og:";
static NSString *ogImage = @"og:image";
static NSString *ogImageURL = @"og:image:url";
static NSString *ogImageSecureURL = @"og:image:secure_url";
static NSString *ogImageType = @"og:image:type";
static NSString *ogImageWidth = @"og:image:width";
static NSString *ogImageHeight = @"og:image:height";
static NSString *ogImageAlt = @"og:image:alt";
static NSString *ogPropertyKey = @"property";
static NSString *ogContentKey = @"content";

- (void)parseTags:(NSArray *)tags {

	for (RDHTMLTag *tag in tags) {

		if (tag.type != RDHTMLTagTypeMeta) {
			continue;
		}

		NSString *propertyName = tag.attributes[ogPropertyKey];
		if (!propertyName || ![propertyName hasPrefix:ogPrefix]) {
			continue;
		}
		NSString *content = tag.attributes[ogContentKey];
		if (!content) {
			continue;
		}

		if ([propertyName isEqualToString:ogImage]) {
			RDHTMLOpenGraphImage *image = [self currentImage];
			if (!image || image.url) { // Most likely case, since og:image will probably appear before other image attributes.
				image = [self pushImage];
			}
			image.url = content;
		}

		else if ([propertyName isEqualToString:ogImageURL]) {
			[self ensureImage].url = content;
		}
		else if ([propertyName isEqualToString:ogImageSecureURL]) {
			[self ensureImage].secureURL = content;
		}
		else if ([propertyName isEqualToString:ogImageType]) {
			[self ensureImage].mimeType = content;
		}
		else if ([propertyName isEqualToString:ogImageAlt]) {
			[self ensureImage].altText = content;
		}
		else if ([propertyName isEqualToString:ogImageWidth]) {
			[self ensureImage].width = [content floatValue];
		}
		else if ([propertyName isEqualToString:ogImageHeight]) {
			[self ensureImage].height = [content floatValue];
		}
	}
}

@end

@implementation RDHTMLTwitterProperties

static NSString *twitterNameKey = @"name";
static NSString *twitterContentKey = @"content";
static NSString *twitterImageSrc = @"twitter:image:src";

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RDHTMLTag *> *)tags {

	self = [super init];
	if (!self) {
		return nil;
	}

	for (RDHTMLTag *tag in tags) {

		if (tag.type != RDHTMLTagTypeMeta) {
			continue;
		}
		NSString *name = tag.attributes[twitterNameKey];
		if (!name || ![name isEqualToString:twitterImageSrc]) {
			continue;
		}
		NSString *content = tag.attributes[twitterContentKey];
		if (!content || content.length < 1) {
			continue;
		}
		_imageURL = content;
		break;
	}

	return self;
}

@end

