//
//  RDOPMLError.h
//  RDParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

extern NSString *RDOPMLErrorDomain;


typedef NS_ENUM(NSInteger, RDOPMLErrorCode) {
	RDOPMLErrorCodeDataIsWrongFormat = 1024
};


NSError *RDOPMLWrongFormatError(NSString *fileName);
