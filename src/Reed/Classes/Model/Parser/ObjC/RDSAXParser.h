//
//  RDSAXParser.h
//  RDParser
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

/*Thread-safe, not re-entrant.

 Calls to the delegate will happen on the same thread where the parser runs.

 This is a low-level streaming XML parser, a thin wrapper for libxml2's SAX parser. It doesn't do much Foundation-ifying quite on purpose -- because the goal is performance and low memory use.

 This class is not meant to be sub-classed. Use the delegate methods.
 */


@class RDSAXParser;

@protocol RDSAXParserDelegate <NSObject>

@optional

- (void)saxParser:(RDSAXParser *)SAXParser XMLStartElement:(const unsigned char *)localName prefix:(const unsigned char *)prefix uri:(const unsigned char *)uri numberOfNamespaces:(NSInteger)numberOfNamespaces namespaces:(const unsigned char **)namespaces numberOfAttributes:(NSInteger)numberOfAttributes numberDefaulted:(int)numberDefaulted attributes:(const unsigned char **)attributes;

- (void)saxParser:(RDSAXParser *)SAXParser XMLEndElement:(const unsigned char *)localName prefix:(const unsigned char *)prefix uri:(const unsigned char *)uri;

// Length is guaranteed to be greater than 0.
- (void)saxParser:(RDSAXParser *)SAXParser XMLCharactersFound:(const unsigned char *)characters length:(NSUInteger)length;

- (void)saxParserDidReachEndOfDocument:(RDSAXParser *)SAXParser; /*If canceled, may not get called (but might).*/

- (NSString *)saxParser:(RDSAXParser *)SAXParser internedStringForName:(const unsigned char *)name prefix:(const unsigned char *)prefix; /*Okay to return nil. Prefix may be nil.*/

- (NSString *)saxParser:(RDSAXParser *)SAXParser internedStringForValue:(const void *)bytes length:(NSUInteger)length;

@end


void RDSAXInitLibXMLParser(void); // Needed by RDSAXHTMLParser.

/*For use by delegate.*/

BOOL RDSAXEqualTags(const unsigned char *localName, const char *tag, NSInteger tagLength);


@interface RDSAXParser : NSObject

- (instancetype)initWithDelegate:(id<RDSAXParserDelegate>)delegate;

- (void)parseData:(NSData *)data;
- (void)parseBytes:(const void *)bytes numberOfBytes:(NSUInteger)numberOfBytes;
- (void)finishParsing;
- (void)cancel;

@property (nonatomic, strong, readonly) NSData *currentCharacters; /*nil if not storing characters. UTF-8 encoded.*/
@property (nonatomic, strong, readonly) NSString *currentString; /*Convenience to get string version of currentCharacters.*/
@property (nonatomic, strong, readonly) NSString *currentStringWithTrimmedWhitespace;

- (void)beginStoringCharacters; /*Delegate can call from XMLStartElement. Characters will be available in XMLEndElement as currentCharacters property. Storing characters is stopped after each XMLEndElement.*/

/*Delegate can call from within XMLStartElement. Returns nil if numberOfAttributes < 1.*/

- (NSDictionary *)attributesDictionary:(const unsigned char **)attributes numberOfAttributes:(NSInteger)numberOfAttributes;

@end
