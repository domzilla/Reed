//
//  RDHTMLLinkParser.h
//  RDParser
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/*Returns all <a href="some_url">some_text</a> as RDHTMLLink object array.*/

@class ParserData;
@class RDHTMLLink;

@interface RDHTMLLinkParser : NSObject

+ (NSArray <RDHTMLLink *> *)htmlLinksWithParserData:(ParserData *)parserData;

@end


@interface RDHTMLLink : NSObject

// Any of these, even urlString, may be nil, because HTML can be bad.

@property (nonatomic, nullable, readonly) NSString *urlString; //absolute
@property (nonatomic, nullable, readonly) NSString *text;
@property (nonatomic, nullable, readonly) NSString *title; //title attribute inside anchor tag

@end

NS_ASSUME_NONNULL_END
