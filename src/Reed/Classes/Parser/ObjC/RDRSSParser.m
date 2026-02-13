//
//  RDRSSParser.m
//  RDParser
//
//  Created by Brent Simmons on 1/6/15.
//  Copyright (c) 2015 Ranchero Software LLC. All rights reserved.
//

#import "RDRSSParser.h"
#import "RDSAXParser.h"
#import "RDParsedFeed.h"
#import "RDParsedArticle.h"
#import "RDParserInternal.h"
#import "NSString+Parser.h"
#import "RDDateParser.h"
#import "ParserData.h"
#import "RDParsedEnclosure.h"
#import "RDParsedAuthor.h"



#import <libxml/xmlstring.h>


@interface RDRSSParser () <RDSAXParserDelegate>

@property (nonatomic) NSData *feedData;
@property (nonatomic) NSString *urlString;
@property (nonatomic) NSDictionary *currentAttributes;
@property (nonatomic) RDSAXParser *parser;
@property (nonatomic) NSMutableArray *articles;
@property (nonatomic) BOOL parsingArticle;
@property (nonatomic) BOOL parsingAuthor;
@property (nonatomic, readonly) RDParsedArticle *currentArticle;
@property (nonatomic) BOOL parsingChannelImage;
@property (nonatomic, readonly) NSDate *currentDate;
@property (nonatomic) BOOL endRSSFound;
@property (nonatomic) NSString *homepageURLString;
@property (nonatomic) NSString *title;
@property (nonatomic) NSDate *dateParsed;
@property (nonatomic) BOOL isRDF;
@property (nonatomic) NSString *language;

@end


@implementation RDRSSParser

#pragma mark - Class Methods

+ (RDParsedFeed *)parseFeedWithData:(ParserData *)parserData {

	RDRSSParser *parser = [[[self class] alloc] initWithParserData:parserData];
	return [parser parseFeed];
}

#pragma mark - Init

- (instancetype)initWithParserData:(ParserData *)parserData {
	
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_feedData = parserData.data;
	_urlString = parserData.url;
	_parser = [[RDSAXParser alloc] initWithDelegate:self];
	_articles = [NSMutableArray new];

	return self;
}

#pragma mark - API

- (RDParsedFeed *)parseFeed {
	
	[self parse];

	RDParsedFeed *parsedFeed = [[RDParsedFeed alloc] initWithURLString:self.urlString title:self.title homepageURLString:self.homepageURLString language:self.language articles:self.articles];

	return parsedFeed;
}


#pragma mark - Constants

static NSString *kIsPermaLinkKey = @"isPermaLink";
static NSString *kURLKey = @"url";
static NSString *kLengthKey = @"length";
static NSString *kTypeKey = @"type";
static NSString *kFalseValue = @"false";
static NSString *kTrueValue = @"true";
static NSString *kContentEncodedKey = @"content:encoded";
static NSString *kDCDateKey = @"dc:date";
static NSString *kDCCreatorKey = @"dc:creator";
static NSString *kRDFAboutKey = @"rdf:about";

static const char *kItem = "item";
static const NSInteger kItemLength = 5;

static const char *kImage = "image";
static const NSInteger kImageLength = 6;

static const char *kLink = "link";
static const NSInteger kLinkLength = 5;

static const char *kTitle = "title";
static const NSInteger kTitleLength = 6;

static const char *kDC = "dc";
static const NSInteger kDCLength = 3;

static const char *kSource = "source";
static const NSInteger kSourceLength = 7;

static const char *kMarkdown = "markdown";
static const NSInteger kMarkdownLength = 9;

static const char *kCreator = "creator";
static const NSInteger kCreatorLength = 8;

static const char *kDate = "date";
static const NSInteger kDateLength = 5;

static const char *kContent = "content";
static const NSInteger kContentLength = 8;

static const char *kEncoded = "encoded";
static const NSInteger kEncodedLength = 8;

static const char *kGuid = "guid";
static const NSInteger kGuidLength = 5;

static const char *kPubDate = "pubDate";
static const NSInteger kPubDateLength = 8;

static const char *kAuthor = "author";
static const NSInteger kAuthorLength = 7;

static const char *kDescription = "description";
static const NSInteger kDescriptionLength = 12;

static const char *kRSS = "rss";
static const NSInteger kRSSLength = 4;

static const char *kURL = "url";
static const NSInteger kURLLength = 4;

static const char *kLength = "length";
static const NSInteger kLengthLength = 7;

static const char *kType = "type";
static const NSInteger kTypeLength = 5;

static const char *kIsPermaLink = "isPermaLink";
static const NSInteger kIsPermaLinkLength = 12;

static const char *kRDF = "rdf";
static const NSInteger kRDFlength = 4;

static const char *kAbout = "about";
static const NSInteger kAboutLength = 6;

static const char *kFalse = "false";
static const NSInteger kFalseLength = 6;

static const char *kTrue = "true";
static const NSInteger kTrueLength = 5;

static const char *kUppercaseRDF = "RDF";
static const NSInteger kUppercaseRDFLength = 4;

static const char *kEnclosure = "enclosure";
static const NSInteger kEnclosureLength = 10;

static const char *kLanguage = "language";
static const NSInteger kLanguageLength = 9;

#pragma mark - Parsing

- (void)parse {

	self.dateParsed = [NSDate date];

	@autoreleasepool {
		[self.parser parseData:self.feedData];
		[self.parser finishParsing];
	}
}


- (void)addArticle {

	RDParsedArticle *article = [[RDParsedArticle alloc] initWithFeedURL:self.urlString];
	article.dateParsed = self.dateParsed;
	
	[self.articles addObject:article];
}


- (RDParsedArticle *)currentArticle {

	return self.articles.lastObject;
}


- (void)addFeedElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix {

	if (prefix != NULL) {
		return;
	}

	if (RDSAXEqualTags(localName, kLink, kLinkLength)) {
		if (RDParserStringIsEmpty(self.homepageURLString)) {
			self.homepageURLString = [self currentString];
		}
	}

	else if (RDSAXEqualTags(localName, kTitle, kTitleLength)) {
		self.title = [self currentString];
	}

	else if (RDSAXEqualTags(localName, kLanguage, kLanguageLength)) {
		self.language = [self currentString];
	}
}

- (void)addAuthorWithString:(NSString *)authorString {

	if (RDParserStringIsEmpty(authorString)) {
		return;
	}
	
	RDParsedAuthor *author = [RDParsedAuthor authorWithSingleString:[self currentString]];
	[self.currentArticle addAuthor:author];
}

- (void)addDCElement:(const xmlChar *)localName {

	if (RDSAXEqualTags(localName, kCreator, kCreatorLength)) {
		[self addAuthorWithString:[self currentString]];
	}
	else if (RDSAXEqualTags(localName, kDate, kDateLength)) {
		self.currentArticle.datePublished = self.currentDate;
	}
}

- (void)addSourceElement:(const xmlChar *)localName {

	if (RDSAXEqualTags(localName, kMarkdown, kMarkdownLength)) {
		self.currentArticle.markdown = [self currentString];
	}
}

- (void)addGuid {

	NSString *guid = [self currentString];
	self.currentArticle.guid = guid;

	NSString *isPermaLinkValue = [self.currentAttributes rdparser_objectForCaseInsensitiveKey:@"ispermalink"];
	if (!isPermaLinkValue || ![isPermaLinkValue isEqualToString:@"false"]) {
		if ([self stringIsProbablyAURLOrRelativePath:guid]) {
			self.currentArticle.permalink = [self urlString:guid];
		}
	}
}

- (void)addEnclosure {

	NSDictionary *attributes = self.currentAttributes;
	NSString *url = attributes[kURLKey];
	if (!url || url.length < 1) {
		return;
	}

	RDParsedEnclosure *enclosure = [[RDParsedEnclosure alloc] init];
	enclosure.url = url;
	enclosure.length = [attributes[kLengthKey] integerValue];
	enclosure.mimeType = attributes[kTypeKey];

	[self.currentArticle addEnclosure:enclosure];
}

- (BOOL)stringIsProbablyAURLOrRelativePath:(NSString *)s {

	/*The RSS guid is defined as a permalink, except when it appears like this:
	 <guid isPermaLink="false">some—identifier</guid>
	 However, people often seem to think it’s *not* a permalink by default, even
	 though it is. So we try to detect the situation where the value is not a URL string,
	 and not even a relative path. This may need to evolve over time as we find
	 feeds broken in different ways.*/

	// https://github.com/Ranchero-Software/NetNewsWire/issues/1230
	if ([s rdparser_contains:@" "]) {
		return NO;
	}
	
	if (![s rdparser_contains:@"/"]) {
		// This seems to be just about the best possible check.
		// Bad guids are often just integers, for instance.
		return NO;
	}

	if ([s.lowercaseString hasPrefix:@"tag:"]) { // A common non-URL guid form
		return NO;
	}
	return YES;
}

- (NSString *)urlString:(NSString *)s {

	/*Resolve against home page URL (if available) or feed URL.*/

	if ([[s lowercaseString] hasPrefix:@"http"]) {
		return s;
	}

	if (!self.homepageURLString) {
		//TODO: get feed URL and use that to resolve URL.*/
		return s;
	}

	NSURL *baseURL = [NSURL URLWithString:self.homepageURLString];
	if (!baseURL) {
		return s;
	}

	NSURL *resolvedURL = [NSURL URLWithString:s relativeToURL:baseURL];
	if (resolvedURL.absoluteString) {
		return resolvedURL.absoluteString;
	}

	return s;
}


- (NSString *)currentString {

	return self.parser.currentStringWithTrimmedWhitespace;
}


- (void)addArticleElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix {

	if (RDSAXEqualTags(prefix, kDC, kDCLength)) {

		[self addDCElement:localName];
		return;
	}

	if (RDSAXEqualTags(prefix, kSource, kSourceLength)) {
		[self addSourceElement:localName];
		return;
	}

	if (RDSAXEqualTags(prefix, kContent, kContentLength) && RDSAXEqualTags(localName, kEncoded, kEncodedLength)) {
		NSString *s = [self currentString];
		if (!RDParserStringIsEmpty(s)) {
			self.currentArticle.body = s;
		}
		return;
	}

	if (prefix != NULL) {
		return;
	}

	if (RDSAXEqualTags(localName, kGuid, kGuidLength)) {
		[self addGuid];
	}
	else if (RDSAXEqualTags(localName, kPubDate, kPubDateLength)) {
		self.currentArticle.datePublished = self.currentDate;
	}
	else if (RDSAXEqualTags(localName, kAuthor, kAuthorLength)) {
		[self addAuthorWithString:[self currentString]];
	}
	else if (RDSAXEqualTags(localName, kLink, kLinkLength)) {
		RDParsedArticle *article = self.currentArticle;
		if (article.link == nil) {
			NSString *s = [self currentString];
			if (!RDParserStringIsEmpty(s)) {
				article.link = [self urlString:s];
			}
		}
	}
	else if (RDSAXEqualTags(localName, kDescription, kDescriptionLength)) {

		if (!self.currentArticle.body) {
			self.currentArticle.body = [self currentString];
		}
	}
	else if (!self.parsingAuthor && RDSAXEqualTags(localName, kTitle, kTitleLength)) {
        NSString *articleTitle = [self currentString];
        if (articleTitle != nil) {
            self.currentArticle.title = articleTitle;
        }
	}
	else if (RDSAXEqualTags(localName, kEnclosure, kEnclosureLength)) {
		[self addEnclosure];
	}
}


- (NSDate *)currentDate {

	return RDDateWithBytes(self.parser.currentCharacters.bytes, self.parser.currentCharacters.length);
}


#pragma mark - RDSAXParserDelegate

- (void)saxParser:(RDSAXParser *)SAXParser XMLStartElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri numberOfNamespaces:(NSInteger)numberOfNamespaces namespaces:(const xmlChar **)namespaces numberOfAttributes:(NSInteger)numberOfAttributes numberDefaulted:(int)numberDefaulted attributes:(const xmlChar **)attributes {

	if (self.endRSSFound) {
		return;
	}

	if (RDSAXEqualTags(localName, kUppercaseRDF, kUppercaseRDFLength)) {
		self.isRDF = YES;
		return;
	}

	NSDictionary *xmlAttributes = nil;
	if ((self.isRDF && RDSAXEqualTags(localName, kItem, kItemLength)) || RDSAXEqualTags(localName, kGuid, kGuidLength) || RDSAXEqualTags(localName, kEnclosure, kEnclosureLength)) {
		xmlAttributes = [self.parser attributesDictionary:attributes numberOfAttributes:numberOfAttributes];
	}
	if (self.currentAttributes != xmlAttributes) {
		self.currentAttributes = xmlAttributes;
	}

	if (!prefix && RDSAXEqualTags(localName, kItem, kItemLength)) {

		[self addArticle];
		self.parsingArticle = YES;

		if (self.isRDF && xmlAttributes && xmlAttributes[kRDFAboutKey]) { /*RSS 1.0 guid*/
			self.currentArticle.guid = xmlAttributes[kRDFAboutKey];
			self.currentArticle.permalink = self.currentArticle.guid;
		}
	}

	else if (!prefix && RDSAXEqualTags(localName, kImage, kImageLength)) {
		self.parsingChannelImage = YES;
	}
	else if (!prefix && RDSAXEqualTags(localName, kAuthor, kAuthorLength)) {
		if (self.parsingArticle) {
			self.parsingAuthor = true;
		}
	}

	if (!self.parsingChannelImage) {
		[self.parser beginStoringCharacters];
	}
}


- (void)saxParser:(RDSAXParser *)SAXParser XMLEndElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri {

	if (self.endRSSFound) {
		return;
	}

	if (self.isRDF && RDSAXEqualTags(localName, kUppercaseRDF, kUppercaseRDFLength)) {
		self.endRSSFound = YES;
	}

	else if (RDSAXEqualTags(localName, kRSS, kRSSLength)) {
		self.endRSSFound = YES;
	}

	else if (RDSAXEqualTags(localName, kImage, kImageLength)) {
		self.parsingChannelImage = NO;
	}

	else if (RDSAXEqualTags(localName, kItem, kItemLength)) {
		self.parsingArticle = NO;
	}

	else if (self.parsingArticle) {
		[self addArticleElement:localName prefix:prefix];
		if (RDSAXEqualTags(localName, kAuthor, kAuthorLength)) {
			self.parsingAuthor = NO;
		}
	}

	else if (!self.parsingChannelImage) {
		[self addFeedElement:localName prefix:prefix];
	}
}


- (NSString *)saxParser:(RDSAXParser *)SAXParser internedStringForName:(const xmlChar *)name prefix:(const xmlChar *)prefix {

	if (RDSAXEqualTags(prefix, kRDF, kRDFlength)) {

		if (RDSAXEqualTags(name, kAbout, kAboutLength)) {
			return kRDFAboutKey;
		}

		return nil;
	}

	if (prefix) {
		return nil;
	}

	if (RDSAXEqualTags(name, kIsPermaLink, kIsPermaLinkLength)) {
		return kIsPermaLinkKey;
	}

	if (RDSAXEqualTags(name, kURL, kURLLength)) {
		return kURLKey;
	}

	if (RDSAXEqualTags(name, kLength, kLengthLength)) {
		return kLengthKey;
	}

	if (RDSAXEqualTags(name, kType, kTypeLength)) {
		return kTypeKey;
	}

	return nil;
}


static BOOL equalBytes(const void *bytes1, const void *bytes2, NSUInteger length) {

	return memcmp(bytes1, bytes2, length) == 0;
}


- (NSString *)saxParser:(RDSAXParser *)SAXParser internedStringForValue:(const void *)bytes length:(NSUInteger)length {

	static const NSUInteger falseLength = kFalseLength - 1;
	static const NSUInteger trueLength = kTrueLength - 1;

	if (length == falseLength && equalBytes(bytes, kFalse, falseLength)) {
		return kFalseValue;
	}

	if (length == trueLength && equalBytes(bytes, kTrue, trueLength)) {
		return kTrueValue;
	}

	return nil;
}


@end
