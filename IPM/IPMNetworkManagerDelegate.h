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
//  NetworkManagerDelegate.h
//
//  Copyright 
//      Mike Godenzi - godenzim@gmail.com
//      Mike Godenzi 
//      2010
//  All rights reserved.
//

@protocol IPMNetworkManagerDelegate<NSObject>
@optional

/*
 * This method is called by the IPMNetworkManager when a request for a JSON object has finished
 */
- (void)networkManagerDidReceiveJSONResponse:(id)jsonItem withParam:(id<NSObject>)param;

/*
 * This method is called by the IPMNetworkManager when a request for a NSString object has finished
 */
- (void)networkManagerDidReceiveNSStringResponse:(NSString *)response withParam:(id<NSObject>)param;

/*
 * This method is called by the IPMNetworkManager when a request for a UIImage object has finished
 */
- (void)networkManagerDidReceiveUIImageResponse:(NSImage *)response withParam:(id<NSObject>)param;

/*
 * This method is called by the IPMNetworkManager when a request has finished
 */
- (void)networkManagerDidReceiveNSDataResponse:(NSData *)response withParam:(id<NSObject>)param;

/*
 * This method is called by the IPMNetworkManager when an error occured during a request
 */
- (void)networkManagerDidNotReceiveResponse:(NSError *)error withParam:(id<NSObject>)param;

/*
 * This method is called by the IPMNetworkManager when an authentication challenge araise
 */
- (NSString *)usernameForAuthenticationChallengeWithParam:(id<NSObject>)param;

/*
 * This method is called by the IPMNetworkManager when an authentication challenge araise
 */
- (NSString *)passwordForAuthenticationChallengeWithParam:(id<NSObject>)param;
@end
