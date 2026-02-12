//
//  RDOPMLDocument.h
//  RDParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

#import "RDOPMLItem.h"




@interface RDOPMLDocument : RDOPMLItem

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *url;

@end
