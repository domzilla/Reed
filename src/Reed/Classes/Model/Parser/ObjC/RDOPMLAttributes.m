//
//  RDOPMLAttributes.m
//  RDParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RDOPMLAttributes.h"
#import "RDParserInternal.h"




NSString *OPMLTextKey = @"text";
NSString *OPMLTitleKey = @"title";
NSString *OPMLDescriptionKey = @"description";
NSString *OPMLTypeKey = @"type";
NSString *OPMLVersionKey = @"version";
NSString *OPMLHMTLURLKey = @"htmlUrl";
NSString *OPMLXMLURLKey = @"xmlUrl";


@implementation NSDictionary (RDOPMLAttributes)

- (NSString *)opml_text {

	return [self rdparser_objectForCaseInsensitiveKey:OPMLTextKey];
}


- (NSString *)opml_title {

	return [self rdparser_objectForCaseInsensitiveKey:OPMLTitleKey];
}


- (NSString *)opml_description {

	return [self rdparser_objectForCaseInsensitiveKey:OPMLDescriptionKey];
}


- (NSString *)opml_type {

	return [self rdparser_objectForCaseInsensitiveKey:OPMLTypeKey];
}


- (NSString *)opml_version {

	return [self rdparser_objectForCaseInsensitiveKey:OPMLVersionKey];
}


- (NSString *)opml_htmlUrl {

	return [self rdparser_objectForCaseInsensitiveKey:OPMLHMTLURLKey];
}


- (NSString *)opml_xmlUrl {

	return [self rdparser_objectForCaseInsensitiveKey:OPMLXMLURLKey];
}


@end
