// Copyright (C) 2010 Mike Godenzi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

//
//  PendingConnection.m
//
//  Copyright 
//      Mike Godenzi - godenzim@gmail.com
//      Mike Godenzi 
//      2010
//  All rights reserved.
//

#import "IPMPendingConnection.h"


/*
@interface PendingConnection (PrivateMethods)

@end
*/

@implementation IPMPendingConnection

@synthesize receivedData, delegate, param, nrt, statusCode, encoding;

#pragma mark Memory Management

- (id)initWithDelegate:(id<IPMNetworkManagerDelegate>)del andParam:(id<NSObject>)p {
	if (self = [super init]) {
		self.delegate = del;
		self.param = p;
		nrt = NORESPONSE_NRT;
		encoding = NSUTF8StringEncoding;
		NSMutableData * data = [[NSMutableData alloc] init];
		self.receivedData = data;
		[data release];
	}
	return self;
}

- (void)dealloc {
	[delegate release];
	[receivedData release];
	[param release];
	[super dealloc];
}

#pragma mark -

@end
