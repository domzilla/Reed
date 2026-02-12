//
//  RDHTMLMetadataParser.m
//  RDParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RDHTMLMetadataParser.h"
#import "RDHTMLMetadata.h"
#import "RDSAXHTMLParser.h"
#import "RDSAXHTMLParser.h"
#import "RDSAXParser.h"
#import "RDParserInternal.h"
#import "ParserData.h"
#import "RDHTMLTag.h"

#import <libxml/xmlstring.h>


@interface RDHTMLMetadataParser () <RDSAXHTMLParserDelegate>

@property (nonatomic, readonly) ParserData *parserData;
@property (nonatomic, readwrite) RDHTMLMetadata *metadata;
@property (nonatomic) NSMutableArray *tags;
@property (nonatomic) BOOL didFinishParsing;
@property (nonatomic) BOOL shouldScanPastHeadSection;

@end


@implementation RDHTMLMetadataParser


#pragma mark - Class Methods

+ (RDHTMLMetadata *)HTMLMetadataWithParserData:(ParserData *)parserData {

	RDHTMLMetadataParser *parser = [[self alloc] initWithParserData:parserData];
	return parser.metadata;
}


#pragma mark - Init

- (instancetype)initWithParserData:(ParserData *)parserData {

	NSParameterAssert(parserData.data);
	NSParameterAssert(parserData.url);

	self = [super init];
	if (!self) {
		return nil;
	}

	_parserData = parserData;
	_tags = [NSMutableArray new];

	// YouTube has a weird bug where, on some pages, it puts the feed link tag after the head section, in the body section.
	// This allows for a special case where we continue to scan after the head section.
	// (Yes, this match could yield false positives, but it’s harmless.)
	_shouldScanPastHeadSection = [parserData.url rangeOfString:@"youtube" options:NSCaseInsensitiveSearch].location != NSNotFound;

	[self parse];

	return self;
}


#pragma mark - Parse

- (void)parse {

	RDSAXHTMLParser *parser = [[RDSAXHTMLParser alloc] initWithDelegate:self];
	[parser parseData:self.parserData.data];
	[parser finishParsing];

	self.metadata = [[RDHTMLMetadata alloc] initWithURLString:self.parserData.url tags:self.tags];
}


static NSString *kHrefKey = @"href";
static NSString *kSrcKey = @"src";
static NSString *kRelKey = @"rel";

- (NSString *)linkForDictionary:(NSDictionary *)d {

	NSString *link = [d rdparser_objectForCaseInsensitiveKey:kHrefKey];
	if (link) {
		return link;
	}

	return [d rdparser_objectForCaseInsensitiveKey:kSrcKey];
}

- (void)handleLinkAttributes:(NSDictionary *)d {

	if (RDParserStringIsEmpty([d rdparser_objectForCaseInsensitiveKey:kRelKey])) {
		return;
	}
	if (RDParserStringIsEmpty([self linkForDictionary:d])) {
		return;
	}

	RDHTMLTag *tag = [RDHTMLTag linkTagWithAttributes:d];
	[self.tags addObject:tag];
}

- (void)handleMetaAttributes:(NSDictionary *)d {

	RDHTMLTag *tag = [RDHTMLTag metaTagWithAttributes:d];
	[self.tags addObject:tag];
}

#pragma mark - RDSAXHTMLParserDelegate

static const char *kBody = "body";
static const NSInteger kBodyLength = 5;
static const char *kLink = "link";
static const NSInteger kLinkLength = 5;
static const char *kMeta = "meta";
static const NSInteger kMetaLength = 5;

- (void)saxParser:(RDSAXHTMLParser *)SAXParser XMLStartElement:(const xmlChar *)localName attributes:(const xmlChar **)attributes {

	if (self.didFinishParsing) {
		return;
	}
	
	if (RDSAXEqualTags(localName, kBody, kBodyLength) && !self.shouldScanPastHeadSection) {
		self.didFinishParsing = YES;
		return;
	}

	if (RDSAXEqualTags(localName, kLink, kLinkLength)) {
		NSDictionary *d = [SAXParser attributesDictionary:attributes];
		if (!RDParserObjectIsEmpty(d)) {
			[self handleLinkAttributes:d];
		}
		return;
	}

	if (RDSAXEqualTags(localName, kMeta, kMetaLength)) {
		NSDictionary *d = [SAXParser attributesDictionary:attributes];
		if (!RDParserObjectIsEmpty(d)) {
			[self handleMetaAttributes:d];
		}
	}
}

@end
