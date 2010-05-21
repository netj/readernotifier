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
//  PendingConnection.h
//
//  Copyright 
//      Mike Godenzi - godenzim@gmail.com
//      Mike Godenzi 
//      2010
//  All rights reserved.
//
#import "IPMNetworkManagerDelegate.h"

/*
 * This class is used by the IPMNetworkManager to keep track of all the connections and their results.
 */

@interface IPMPendingConnection : NSObject {
	@private
	NSMutableData * receivedData;
	id<IPMNetworkManagerDelegate> delegate;
	id<NSObject> param;
	IPM_NETWORK_RESPONSE_TYPE nrt;
	NSInteger statusCode;
	NSStringEncoding encoding;
}

@property(nonatomic, retain) NSMutableData * receivedData; // data received from the connection
@property(nonatomic, retain) id<IPMNetworkManagerDelegate> delegate; // object interested in the received data
@property(nonatomic, retain) id<NSObject> param; // param passed by the user when he/she initiated the request, this will be passed back with the request result
@property(nonatomic, assign) IPM_NETWORK_RESPONSE_TYPE nrt; // the type of the response
@property(nonatomic, assign) NSInteger statusCode; // response status code
@property(nonatomic, assign) NSStringEncoding encoding; // encoding for strings

- (id)initWithDelegate:(id<IPMNetworkManagerDelegate>)del andParam:(id<NSObject>)p;

@end
