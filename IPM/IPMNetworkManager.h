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
//  NetworkManager.h
//  Copyright 
//      Mike Godenzi - godenzim@gmail.com
//      Mike Godenzi 
//      2010
//  All rights reserved.
//

/*
 * This class allows you to easily execute network requests, it uses an enum defined in IPMConfiguration.h to distinguish between 4 types of responses:
 * - NSString
 * - NSData
 * - UIImage
 * - JSON
 * Once the request finishes, a callback is called on the delegate object passed as paramenter on each method. Please refere to the IPMNetworkManagerDelegate.h
 * to learn more about these callbacks.
 */

#import "IPMNetworkManagerDelegate.h"

@interface IPMNetworkManager : NSObject {
	@private
	NSMutableDictionary * connectionsData;
	NSString * userAgent;
}

@property(nonatomic, retain) NSString * userAgent; // the user agent to set for each request, it can be left as nil

/*
 * This method is used to download an image.
 * - imageUrl: the image url
 * - delegate: when the image is downloaded, the method networkManagerDidReceiveUIImageResponse:withParam: will be called on the delegate
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */
- (void)retrieveImageAtUrl:(NSString *)imageUrl 
			  withDelegate:(id<IPMNetworkManagerDelegate>)delegate 
				  andParam:(id<NSObject>)param;

/* - headers: additional http headers, can be nil */
- (void)retrieveImageAtUrl:(NSString *)imageUrl 
		  withHeaderFields:(NSDictionary *)headers 
				  delegate:(id<IPMNetworkManagerDelegate>)delegate 
				  andParam:(id<NSObject>)param;

/*
 * This method is used to retrieve a Json object.
 * - url: the request url
 * - delegate: when the image is downloaded, the method networkManagerDidReceiveJSONResponse:withParam: will be called on the delegate
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */
- (void)retrieveJsonAtUrl:(NSString *)url
			 withDelegate:(id<IPMNetworkManagerDelegate>)delegate 
				 andParam:(id<NSObject>)param;

/* - headers: additional http headers, can be nil */
- (void)retrieveJsonAtUrl:(NSString *)url 
		 withHeaderFields:(NSDictionary *)headers
				 delegate:(id<IPMNetworkManagerDelegate>)delegate 
				 andParam:(id<NSObject>)param;

/*
 * This method is used to retrieve a NSString object.
 * - url: the request url
 * - enc: the encoding type
 * - delegate: when the image is downloaded, the method networkManagerDidReceiveNSStringResponse:withParam: will be called on the delegate
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */
- (void)retrieveStringAtUrl:(NSString *)url 
			   withEncoding:(NSStringEncoding)enc 
				   delegate:(id<IPMNetworkManagerDelegate>)delegate 
				   andParam:(id<NSObject>)param;

/* - headers: additional http headers, can be nil */
- (void)retrieveStringAtUrl:(NSString *)url 
		   withHeaderFields:(NSDictionary *)headers
				   encoding:(NSStringEncoding)enc 
				   delegate:(id<IPMNetworkManagerDelegate>)delegate 
				   andParam:(id<NSObject>)param;

/*
 * This method is used to retrieve a NSString object with UTF8 string encoding.
 * - url: the request url
 * - delegate: when the image is downloaded, the method networkManagerDidReceiveNSStringResponse:withParam: will be called on the delegate
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */
- (void)retrieveStringAtUrl:(NSString *)url
			   withDelegate:(id<IPMNetworkManagerDelegate>)delegate 
				   andParam:(id<NSObject>)param;

/* - headers: additional http headers, can be nil */
- (void)retrieveStringAtUrl:(NSString *)url 
		   withHeaderFields:(NSDictionary *)headers
				   delegate:(id<IPMNetworkManagerDelegate>)delegate 
				   andParam:(id<NSObject>)param;

/*
 * This method is used to retrieve a NSData object.
 * - url: the request url
 * - delegate: when the image is downloaded, the method networkManagerDidReceiveNSDataResponse:withParam: will be called on the delegate
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */
- (void)retrieveDataAtUrl:(NSString *)url
			 withDelegate:(id<IPMNetworkManagerDelegate>)delegate 
				 andParam:(id<NSObject>)param;

/* - headers: additional http headers, can be nil */
- (void)retrieveDataAtUrl:(NSString *)url 
		 withHeaderFields:(NSDictionary *)headers 
				 delegate:(id<IPMNetworkManagerDelegate>)delegate 
				 andParam:(id<NSObject>)param;

/*
 * This is a general method to initiate a GET network request.
 * - url: request url
 * - type: response type
 * - delegate: the delegate will receive the response through a callback (the callback changes depending on the respose type)
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */
- (void)sendGETNetworkRequest:(NSString *)url 
			 withResponseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					 delegate:(id<IPMNetworkManagerDelegate>)delegate 
					 andParam:(id<NSObject>)param;

/* - headers: additional http headers, can be nil */
- (void)sendGETNetworkRequest:(NSString *)url 
			 withHeaderFields:(NSDictionary *)headers 
				 responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					 delegate:(id<IPMNetworkManagerDelegate>)delegate 
					 andParam:(id<NSObject>)param;

/*
 * This is a general method to initiate a POST network request.
 * - url: request url
 * - body: the body of the request
 * - type: response type
 * - delegate: the delegate will receive the response through a callback (the callback changes depending on the respose type)
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */
- (void)sendPOSTNetworkRequest:(NSString *)url 
					  withBody:(NSString *)body 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param;

/* - headers: additional http headers, can be nil */
- (void)sendPOSTNetworkRequest:(NSString *)url 
					  withBody:(NSString *)body 
				  headerFields:(NSDictionary *)headers 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param;

/*
 * This method is used to POST a Json object.
 * - url: request url
 * - body: the body of the request, it will be used to create a Json object first and then added as the request body
 * - type: response type
 * - delegate: the delegate will receive the response through a callback (the callback changes depending on the respose type)
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */
- (void)sendPOSTNetworkRequest:(NSString *)url 
				  withJSONBody:(NSDictionary *)body 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param;

/* - headers: additional http headers, can be nil */
- (void)sendPOSTNetworkRequest:(NSString *)url 
				  withJSONBody:(NSDictionary *)body 
				  headerFields:(NSDictionary *)headers 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param;

/*
 * This is a general method to initiate a PUT network request.
 * - url: request url
 * - body: the body of the request
 * - headers: additional http headers, can be nil
 * - type: response type
 * - delegate: the delegate will receive the response through a callback (the callback changes depending on the respose type)
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */

- (void)sendPUTNetworkRequest:(NSString *)url 
					 withBody:(NSString *)body 
				 headerFields:(NSDictionary *)headers 
				 responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					 delegate:(id<IPMNetworkManagerDelegate>)delegate 
					 andParam:(id<NSObject>)param;

/*
 * This method is used to PUT a Json object.
 * - url: request url
 * - body: the body of the request, it will be used to create a Json object first and then added as the request body
 * - headers: additional http headers, can be nil
 * - type: response type
 * - delegate: the delegate will receive the response through a callback (the callback changes depending on the respose type)
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */

- (void)sendPUTNetworkRequest:(NSString *)url 
				 withJSONBody:(NSDictionary *)body 
				 headerFields:(NSDictionary *)headers 
				 responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					 delegate:(id<IPMNetworkManagerDelegate>)delegate 
					 andParam:(id<NSObject>)param;

/*
 * This is a general method to initiate a network request.
 * - url: request url
 * - method: request method (i.e. @"GET", @"POST", @"PUT", ...)
 * - body: the body of the request, can be nil
 * - headers: additional http headers, can be nil
 * - type: response type
 * - delegate: the delegate will receive the response through a callback (the callback changes depending on the respose type)
 * - param: this object will be passed back with the reponse callback, it can be used to distinguish between several request, it can be nil
 */
- (void)sendNetworkRequest:(NSString *)url 
				withMethod:(NSString *)method
					  body:(NSData *)body 
			  headerFields:(NSDictionary *)headers 
			  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
				  delegate:(id<IPMNetworkManagerDelegate>)delegate 
				  andParam:(id<NSObject>)param;

@end
