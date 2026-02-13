//
//  RDOPMLParser.h
//  RDParser
//
//  Created by Brent Simmons on 7/12/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@class ParserData;
@class RDOPMLDocument;

typedef void (^OPMLParserCallback)(RDOPMLDocument *opmlDocument, NSError *error);

// Parses on background thread; calls back on main thread.
void RDParseOPML(ParserData *parserData, OPMLParserCallback callback);


@interface RDOPMLParser: NSObject

+ (RDOPMLDocument *)parseOPMLWithParserData:(ParserData *)parserData error:(NSError **)error;

@end

