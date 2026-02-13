//
//  RDHTMLMetadataParser.h
//  RDParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@class RDHTMLMetadata;
@class ParserData;

NS_ASSUME_NONNULL_BEGIN

@interface RDHTMLMetadataParser : NSObject

+ (RDHTMLMetadata *)HTMLMetadataWithParserData:(ParserData *)parserData;


@end

NS_ASSUME_NONNULL_END
