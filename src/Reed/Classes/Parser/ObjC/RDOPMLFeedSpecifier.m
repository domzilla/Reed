//
//  RDOPMLFeedSpecifier.m
//  RDParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RDOPMLFeedSpecifier.h"
#import "RDParserInternal.h"



@implementation RDOPMLFeedSpecifier

- (instancetype)initWithTitle:(NSString *)title feedDescription:(NSString *)feedDescription homePageURL:(NSString *)homePageURL feedURL:(NSString *)feedURL {

	NSParameterAssert(!RDParserStringIsEmpty(feedURL));
	
	self = [super init];
	if (!self) {
		return nil;
	}

	if (RDParserStringIsEmpty(title)) {
		_title = nil;
	}
	else {
		_title = title;
	}

	if (RDParserStringIsEmpty(feedDescription)) {
		_feedDescription = nil;
	}
	else {
		_feedDescription = feedDescription;
	}

	if (RDParserStringIsEmpty(homePageURL)) {
		_homePageURL = nil;
	}
	else {
		_homePageURL = homePageURL;
	}

	_feedURL = feedURL;

	return self;
}

@end
