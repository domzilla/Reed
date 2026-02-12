//
//  RDOPMLItem.m
//  RDParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RDOPMLItem.h"
#import "RDOPMLAttributes.h"
#import "RDOPMLFeedSpecifier.h"
#import "RDParserInternal.h"



@interface RDOPMLItem ()

@property (nonatomic) NSMutableArray *mutableChildren;

@end


@implementation RDOPMLItem

@synthesize children = _children;
@synthesize feedSpecifier = _feedSpecifier;


- (NSArray *)children {

	return [self.mutableChildren copy];
}


- (void)setChildren:(NSArray *)children {

	_children = children;
	self.mutableChildren = [_children mutableCopy];
}


- (void)addChild:(RDOPMLItem *)child {

	if (!self.mutableChildren) {
		self.mutableChildren = [NSMutableArray new];
	}

	[self.mutableChildren addObject:child];
}


- (RDOPMLFeedSpecifier *)feedSpecifier {

	if (_feedSpecifier) {
		return _feedSpecifier;
	}

	NSString *feedURL = self.attributes.opml_xmlUrl;
	if (RDParserObjectIsEmpty(feedURL)) {
		return nil;
	}

	_feedSpecifier = [[RDOPMLFeedSpecifier alloc] initWithTitle:self.titleFromAttributes feedDescription:self.attributes.opml_description homePageURL:self.attributes.opml_htmlUrl feedURL:feedURL];

	return _feedSpecifier;
}

- (NSString *)titleFromAttributes {
	
	NSString *title = self.attributes.opml_title;
	if (title) {
		return title;
	}
	title = self.attributes.opml_text;
	if (title) {
		return title;
	}
	
	return nil;
}

- (BOOL)isFolder {
	
	return self.mutableChildren.count > 0;
}

@end
