//
//  RDParsedFeed.h
//  RDParser
//
//  Created by Brent Simmons on 7/12/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@class RDParsedArticle;

@interface RDParsedFeed : NSObject

- (nonnull instancetype)initWithURLString:(NSString * _Nonnull)urlString title:(NSString * _Nullable)title homepageURLString:(NSString * _Nullable)homepageURLString language:(NSString * _Nullable)language articles:(NSArray <RDParsedArticle *>* _Nonnull)articles;

@property (nonatomic, readonly, nonnull) NSString *urlString;
@property (nonatomic, readonly, nullable) NSString *title;
@property (nonatomic, readonly, nullable) NSString *homepageURLString;
@property (nonatomic, readonly, nullable) NSString *language;
@property (nonatomic, readonly, nonnull) NSSet <RDParsedArticle *>*articles;

@end
