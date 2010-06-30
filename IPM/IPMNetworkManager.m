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
//  NetworkManager.m
//  Copyright 
//      Mike Godenzi - godenzim@gmail.com
//      Mike Godenzi 
//      2010
//  All rights reserved.
//

#import "IPMNetworkManager.h"
#import "IPMPendingConnection.h"
#import "IPMNetworkManagerDelegate.h"
#import "JSON.h"

@interface IPMNetworkManager (PrivateMethods)
- (void)execNetworkRequest:(NSString *)urlrequest 
				withMethod:(NSString *)method 
			  headerFields:(NSDictionary *)headers 
					  body:(NSData *)requestBody 
	  andPendingConnection:(IPMPendingConnection *)pc;

- (void)sendJSONNetworkRequest:(NSString *)url 
					withMethod:(NSString *)method
					  JSONBody:(NSDictionary *)body 
				  headerFields:(NSDictionary *)headers 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param;

- (void)sendNetworkRequest:(NSURLRequest *)request 
	 withPendingConnection:(IPMPendingConnection *)pc;

- (NSMutableData *)getDataForConnection:(NSURLConnection *)connection;

- (id<IPMNetworkManagerDelegate>)getDelegateForConnection:(NSURLConnection *)connection;

- (IPMPendingConnection *)getPendingConnection:(NSURLConnection *)connection;

- (NSString *)generateKeyForConnection:(NSURLConnection *)connection;

- (void)destroyDataforConnection:(NSURLConnection *)connection;

- (void)processJSONResponseForPendingConnection:(IPMPendingConnection *)pc;

- (void)processNSStringResponseForPendingConnection:(IPMPendingConnection *)pc;

- (void)processUIImageResponseForPendingConnection:(IPMPendingConnection *)pc;

- (void)processNSDataResponseForPendingConnection:(IPMPendingConnection *)pc;

- (void)addHeaders:(NSDictionary *)headers toRequest:(NSMutableURLRequest *)request;
@end


@implementation IPMNetworkManager

@synthesize userAgent;

#pragma mark Memory Management

- (id)init {
	if (self = [super init]) {
		connectionsData = [[NSMutableDictionary alloc] init];
		userAgent = nil;
	}
	return self;
}

- (void)dealloc {
	[userAgent release];
	[connectionsData release];
	[super dealloc];
}

#pragma mark Request Methods

- (void)sendGETNetworkRequest:(NSString *)url 
			 withHeaderFields:(NSDictionary *)headers 
				 responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					 delegate:(id<IPMNetworkManagerDelegate>)delegate 
					 andParam:(id<NSObject>)param {
	IPMPendingConnection * pc = [[IPMPendingConnection alloc] initWithDelegate:delegate andParam:param];
	pc.nrt = type;
	[self execNetworkRequest:url withMethod:@"GET" headerFields:headers body:nil andPendingConnection:pc];
	[pc release];
}

- (void)sendGETNetworkRequest:(NSString *)url 
			 withResponseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					 delegate:(id<IPMNetworkManagerDelegate>)delegate 
					 andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withHeaderFields:nil responseType:type delegate:delegate andParam:param];
}

- (void)sendPOSTNetworkRequest:(NSString *)url 
					  withBody:(NSString *)body 
				  headerFields:(NSDictionary *)headers 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param {
	IPMPendingConnection * pc = [[IPMPendingConnection alloc] initWithDelegate:delegate andParam:param];
	pc.nrt = type;
	NSData * bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
	[self execNetworkRequest:url withMethod:@"POST" headerFields:headers body:bodyData andPendingConnection:pc];
	[pc release];
}

- (void)sendPOSTNetworkRequest:(NSString *)url 
					  withBody:(NSString *)body 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param {
	[self sendPOSTNetworkRequest:url withBody:body headerFields:nil responseType:type delegate:delegate andParam:param];
}

- (void)sendPOSTNetworkRequest:(NSString *)url 
				  withJSONBody:(NSDictionary *)body 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param {
	[self sendPOSTNetworkRequest:url withJSONBody:body headerFields:nil responseType:type delegate:delegate andParam:param];
}

- (void)sendPOSTNetworkRequest:(NSString *)url 
				  withJSONBody:(NSDictionary *)body 
				  headerFields:(NSDictionary *)headers 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param {
	[self sendJSONNetworkRequest:url withMethod:@"POST" JSONBody:body headerFields:headers responseType:type delegate:delegate andParam:param];
}

- (void)sendPUTNetworkRequest:(NSString *)url 
					 withBody:(NSString *)body 
				 headerFields:(NSDictionary *)headers 
				 responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					 delegate:(id<IPMNetworkManagerDelegate>)delegate 
					 andParam:(id<NSObject>)param {
	IPMPendingConnection * pc = [[IPMPendingConnection alloc] initWithDelegate:delegate andParam:param];
	pc.nrt = type;
	NSData * bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
	[self execNetworkRequest:url withMethod:@"PUT" headerFields:headers body:bodyData andPendingConnection:pc];
	[pc release];
}

- (void)sendPUTNetworkRequest:(NSString *)url 
				 withJSONBody:(NSDictionary *)body 
				 headerFields:(NSDictionary *)headers 
				 responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					 delegate:(id<IPMNetworkManagerDelegate>)delegate 
					 andParam:(id<NSObject>)param {
	[self sendJSONNetworkRequest:url withMethod:@"PUT" JSONBody:body headerFields:headers responseType:type delegate:delegate andParam:param];
}

- (void)sendJSONNetworkRequest:(NSString *)url 
					withMethod:(NSString *)method
					  JSONBody:(NSDictionary *)body 
				  headerFields:(NSDictionary *)headers 
				  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
					  delegate:(id<IPMNetworkManagerDelegate>)delegate 
					  andParam:(id<NSObject>)param {
	IPMPendingConnection * pc = [[IPMPendingConnection alloc] initWithDelegate:delegate andParam:param];
	pc.nrt = type;
	NSString * bodyString = [body JSONRepresentation];
	NSData * bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
	NSMutableDictionary * allHeaders;
	if (headers) {
		allHeaders = [NSMutableDictionary dictionaryWithDictionary:headers];
		[allHeaders setObject:@"application/json" forKey:@"Content-Type"];
	} else
		allHeaders = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"application/json", @"Content-Type", nil];
	[self execNetworkRequest:url withMethod:method headerFields:allHeaders body:bodyData andPendingConnection:pc];
	[pc release];
}

- (void)sendNetworkRequest:(NSString *)url 
				withMethod:(NSString *)method
					  body:(NSData *)body 
			  headerFields:(NSDictionary *)headers 
			  responseType:(IPM_NETWORK_RESPONSE_TYPE)type 
				  delegate:(id<IPMNetworkManagerDelegate>)delegate 
				  andParam:(id<NSObject>)param {
	IPMPendingConnection * pc = [[IPMPendingConnection alloc] initWithDelegate:delegate andParam:param];
	pc.nrt = type;
	[self execNetworkRequest:url withMethod:method headerFields:headers body:body andPendingConnection:pc];
	[pc release];
}

- (void)retrieveImageAtUrl:(NSString *)imageUrl 
		  withHeaderFields:(NSDictionary *)headers 
				  delegate:(id<IPMNetworkManagerDelegate>)delegate 
				  andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:imageUrl withHeaderFields:headers responseType:NSIMAGE_NRT delegate:delegate andParam:param];
}

- (void)retrieveImageAtUrl:(NSString *)imageUrl 
			  withDelegate:(id<IPMNetworkManagerDelegate>)delegate 
				  andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:imageUrl withHeaderFields:nil responseType:NSIMAGE_NRT delegate:delegate andParam:param];
}

- (void)retrieveJsonAtUrl:(NSString *)url 
		 withHeaderFields:(NSDictionary *)headers 
				 delegate:(id<IPMNetworkManagerDelegate>)delegate 
				 andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withHeaderFields:headers responseType:JSON_NRT delegate:delegate andParam:param];
}

- (void)retrieveJsonAtUrl:(NSString *)url 
			 withDelegate:(id<IPMNetworkManagerDelegate>)delegate 
				 andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withHeaderFields:nil responseType:JSON_NRT delegate:delegate andParam:param];
}

- (void)retrieveStringAtUrl:(NSString *)url 
		   withHeaderFields:(NSDictionary *)headers
				   delegate:(id<IPMNetworkManagerDelegate>)delegate 
				   andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withHeaderFields:headers responseType:NSSTRING_NRT delegate:delegate andParam:param];
}

- (void)retrieveStringAtUrl:(NSString *)url 
			   withDelegate:(id<IPMNetworkManagerDelegate>)delegate 
				   andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withHeaderFields:nil responseType:NSSTRING_NRT delegate:delegate andParam:param];
}

- (void)retrieveStringAtUrl:(NSString *)url 
		   withHeaderFields:(NSDictionary *)headers
				   encoding:(NSStringEncoding)enc 
				   delegate:(id<IPMNetworkManagerDelegate>)delegate 
				   andParam:(id<NSObject>)param {
	IPMPendingConnection * pc = [[IPMPendingConnection alloc] initWithDelegate:delegate andParam:param];
	pc.nrt = NSSTRING_NRT;
	pc.encoding = enc;
	[self execNetworkRequest:url withMethod:@"GET" headerFields:headers body:nil andPendingConnection:pc];
	[pc release];
}

- (void)retrieveStringAtUrl:(NSString *)url 
			   withEncoding:(NSStringEncoding)enc 
				   delegate:(id<IPMNetworkManagerDelegate>)delegate 
				   andParam:(id<NSObject>)param {
	[self retrieveStringAtUrl:url withHeaderFields:nil encoding:enc delegate:delegate andParam:param];
}

- (void)retrieveDataAtUrl:(NSString *)url 
		 withHeaderFields:(NSDictionary *)headers 
				 delegate:(id<IPMNetworkManagerDelegate>)delegate 
				 andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withHeaderFields:headers responseType:NSDATA_NRT delegate:delegate andParam:param];
}

- (void)retrieveDataAtUrl:(NSString *)url 
			 withDelegate:(id<IPMNetworkManagerDelegate>)delegate 
				 andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withHeaderFields:nil responseType:NSDATA_NRT delegate:delegate andParam:param];
}

#pragma mark -
#pragma mark Connection Callbacks

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	NSHTTPURLResponse * httpRes = (NSHTTPURLResponse *)response;
	//DLog(@"%i: %@", [httpRes statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpRes statusCode]]);
	//DLog(@"Headers: \n%@", [httpRes allHeaderFields]);
	IPMPendingConnection * pc = [self getPendingConnection:connection];
	if (pc) {
		pc.statusCode = [httpRes statusCode];
		[pc.receivedData setLength:0];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    // append the new data to the receivedData
    // receivedData is declared as a method instance elsewhere
	NSMutableData * receivedData = [self getDataForConnection:connection];
	[receivedData appendData:data];
}

-(void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	IPMPendingConnection * pc = [self getPendingConnection:connection];
	if (![pc.delegate respondsToSelector:@selector(usernameForAuthenticationChallengeWithParam:)] 
		|| ![pc.delegate respondsToSelector:@selector(passwordForAuthenticationChallengeWithParam:)])
		return;
	
	if ([challenge previousFailureCount] == 0) {
		NSString * uname = [pc.delegate usernameForAuthenticationChallengeWithParam:pc.param];
		NSString * pass = [pc.delegate passwordForAuthenticationChallengeWithParam:pc.param];
		NSURLCredential * credential = [NSURLCredential credentialWithUser:(uname == nil) ? @"" : uname
																  password:(pass == nil) ? @"" : pass
															   persistence:NSURLCredentialPersistenceForSession];
		[[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
	} else
		[[challenge sender] cancelAuthenticationChallenge:challenge];
		
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	DLog(@"REQUEST: %@ FAILED with error: %@", [connection description], [error description]);
	IPMPendingConnection * pc = [self getPendingConnection:connection];
	/*NSString * readableString = [[NSString alloc] initWithData:pc.receivedData encoding:pc.encoding];
	DLog(@"and DATA: %@", readableString);
	[readableString release];*/
	if ([pc.delegate respondsToSelector:@selector(networkManagerDidNotReceiveResponse:withParam:)])
		[pc.delegate networkManagerDidNotReceiveResponse:error withParam:pc.param];
	[connection release];
	[self destroyDataforConnection:connection];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	//DLog(@"Did finish loading: %@", [connection description]);
	IPMPendingConnection * pc = [self getPendingConnection:connection];
	if (pc.statusCode >= 400) {
		NSError * error = [[NSError alloc] initWithDomain:@"" code:pc.statusCode userInfo:nil];
		[self connection:connection didFailWithError:error];
		[error release];
		return;
	}
	switch (pc.nrt) {
		case JSON_NRT:
			[self processJSONResponseForPendingConnection:pc];
			break;
		case NSIMAGE_NRT:
			[self processUIImageResponseForPendingConnection:pc];
			break;
		case NSSTRING_NRT:
			[self processNSStringResponseForPendingConnection:pc];
			break;
		case NSDATA_NRT:
			[self processNSDataResponseForPendingConnection:pc];
			break;
		default:
			break;
	}
	[connection release];
	[self destroyDataforConnection:connection];
}

#pragma mark Response Processing

- (void)processJSONResponseForPendingConnection:(IPMPendingConnection *)pc {
	NSString * readableString = [[NSString alloc] initWithData:pc.receivedData encoding:pc.encoding];
	id jsonItem = [readableString JSONValue];
	if ([pc.delegate respondsToSelector:@selector(networkManagerDidReceiveJSONResponse:withParam:)])
		[pc.delegate networkManagerDidReceiveJSONResponse:jsonItem withParam:pc.param];
	[readableString release];
}

- (void)processNSStringResponseForPendingConnection:(IPMPendingConnection *)pc {
	NSString * readableString = [[NSString alloc] initWithData:pc.receivedData encoding:pc.encoding];
	if ([pc.delegate respondsToSelector:@selector(networkManagerDidReceiveNSStringResponse:withParam:)])
		[pc.delegate networkManagerDidReceiveNSStringResponse:readableString withParam:pc.param];
	[readableString release];
}

- (void)processUIImageResponseForPendingConnection:(IPMPendingConnection *)pc {
	NSImage * image = [[NSImage alloc] initWithData:pc.receivedData];
	if ([pc.delegate respondsToSelector:@selector(networkManagerDidReceiveUIImageResponse:withParam:)])
		[pc.delegate networkManagerDidReceiveUIImageResponse:image withParam:pc.param];
	[image release];
}

- (void)processNSDataResponseForPendingConnection:(IPMPendingConnection *)pc {
	if ([pc.delegate respondsToSelector:@selector(networkManagerDidReceiveNSDataResponse:withParam:)])
		[pc.delegate networkManagerDidReceiveNSDataResponse:pc.receivedData withParam:pc.param];
}

#pragma mark -
#pragma mark PrivateMethods implementation

- (void)execNetworkRequest:(NSString *)urlrequest 
				withMethod:(NSString *)method 
			  headerFields:(NSDictionary *)headers 
					  body:(NSData *)requestBody 
	  andPendingConnection:(IPMPendingConnection *)pc {
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlrequest] 
															cachePolicy:NSURLRequestReloadIgnoringCacheData 
														timeoutInterval:10.0];
	[request setHTTPShouldHandleCookies:NO];
	[request setHTTPMethod:method];
	if (userAgent)
		[request setValue:userAgent forHTTPHeaderField:@"User-agent"];
	if (headers)
		[self addHeaders:headers toRequest:request];
	if (requestBody)
		[request setHTTPBody:requestBody];
	[self sendNetworkRequest:request withPendingConnection:pc];
}

- (void)addHeaders:(NSDictionary *)headers toRequest:(NSMutableURLRequest *)request {
	NSArray * keys = [headers allKeys];
	for (NSString * key in keys) {
		NSString * value = [headers objectForKey:key];
		[request setValue:value forHTTPHeaderField:key];
		DLog(@"SETTING HEADER: %@: %@", key, value);
	}
}

- (void)sendNetworkRequest:(NSURLRequest *)request withPendingConnection:(IPMPendingConnection *)pc {
	DLog(@"SENDING REQUEST: %@", [request description]);
#ifdef DEBUG
	NSString * bodyString = [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding];
	DLog(@"WITH BODY: %@", bodyString);
	DLog(@"AND HEADERS:%@", [[request allHTTPHeaderFields] description]);
	[bodyString release];
#endif
	NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection) {
		[connectionsData setObject:pc forKey:[self generateKeyForConnection:connection]];
		[connection start];
	} else {
		// inform the user that the download could not be made
		[connection release];
		NSDictionary * errorDict = [NSDictionary dictionaryWithObject:@"Connection creation failed" forKey:@"errorMessage"];
		NSError * error = [NSError errorWithDomain:@"" code:1 userInfo:errorDict];
		if ([pc.delegate respondsToSelector:@selector(networkManagerDidNotReceiveResponse:withParam:)])
			[pc.delegate networkManagerDidNotReceiveResponse:error withParam:pc.param];
	}
}

- (NSMutableData *)getDataForConnection:(NSURLConnection *)connection {
	NSString * key = [self generateKeyForConnection:connection];
	IPMPendingConnection * pc = [connectionsData objectForKey:key];
	return pc.receivedData;
}

- (id<IPMNetworkManagerDelegate>)getDelegateForConnection:(NSURLConnection *)connection {
	NSString * key = [self generateKeyForConnection:connection];
	IPMPendingConnection * pc = [connectionsData objectForKey:key];
	return pc.delegate;
}

- (IPMPendingConnection *)getPendingConnection:(NSURLConnection *)connection {
	NSString * key = [self generateKeyForConnection:connection];
	return [connectionsData objectForKey:key];
}

- (NSString *)generateKeyForConnection:(NSURLConnection *)connection {
	return [NSString stringWithFormat:@"%i", [connection hash]];
}

- (void)destroyDataforConnection:(NSURLConnection *)connection {
	NSString * key = [self generateKeyForConnection:connection];
	[connectionsData removeObjectForKey:key];
}

@end
