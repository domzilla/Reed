//
//  RDParsedArticle.h
//  RDParser
//
//  Created by Brent Simmons on 12/6/14.
//  Copyright (c) 2014 Ranchero Software LLC. All rights reserved.
//

@import Foundation;

@class RDParsedEnclosure;
@class RDParsedAuthor;

@interface RDParsedArticle : NSObject

- (nonnull instancetype)initWithFeedURL:(NSString * _Nonnull)feedURL;

@property (nonatomic, readonly, nonnull) NSString *feedURL;
@property (nonatomic, nonnull) NSString *articleID; //guid, if present, or calculated from other attributes. Should be unique to the feed, but not necessarily unique across different feeds. (Not suitable for a database ID.)

@property (nonatomic, nullable) NSString *guid;
@property (nonatomic, nullable) NSString *title;
@property (nonatomic, nullable) NSString *body;
@property (nonatomic, nullable) NSString *markdown;
@property (nonatomic, nullable) NSString *link;
@property (nonatomic, nullable) NSString *permalink;
@property (nonatomic, nullable) NSSet<RDParsedAuthor *> *authors;
@property (nonatomic, nullable) NSSet<RDParsedEnclosure *> *enclosures;
@property (nonatomic, nullable) NSDate *datePublished;
@property (nonatomic, nullable) NSDate *dateModified;
@property (nonatomic, nonnull) NSDate *dateParsed;
@property (nonatomic, nullable)	NSString *language;

- (void)addEnclosure:(RDParsedEnclosure *_Nonnull)enclosure;
- (void)addAuthor:(RDParsedAuthor *_Nonnull)author;

@end

