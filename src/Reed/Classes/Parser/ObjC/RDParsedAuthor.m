//
//  RDParsedAuthor.m
//  RDParserTests
//
//  Created by Brent Simmons on 12/19/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

#import "NSString+RDParser.h"

#import "RDParsedAuthor.h"

@implementation RDParsedAuthor

+ (instancetype)authorWithSingleString:(NSString *)s {

	// The author element in RSS is supposed to be email address — but often it’s a name, and sometimes a URL.
	
	RDParsedAuthor *author = [[self alloc] init];

	if ([s rdparser_contains:@"@"]) {
		author.emailAddress = s;
	}
	else if ([s.lowercaseString hasPrefix:@"http"]) {
		author.url = s;
	}
	else {
		author.name = s;
	}

 	return author;
}

- (BOOL)isEmpty {
	
	return !self.name && !self.url && !self.emailAddress;
}

@end
