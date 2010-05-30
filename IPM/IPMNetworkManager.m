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
#import "JSON.h"

@interface IPMNetworkManager (PrivateMethods)
- (void)sendGETNetworkRequest:(NSString *)urlrequest withPendingConnection:(IPMPendingConnection *)pc;
- (void)sendPOSTNetworkRequest:(NSString *)urlrequest withBody:(NSData *)requestBody andPendingConnection:(IPMPendingConnection *)pc;
- (void)sendNetworkRequest:(NSURLRequest *)request withPendingConnection:(IPMPendingConnection *)pc;
- (NSMutableData *)getDataForConnection:(NSURLConnection *)connection;
- (id<IPMNetworkManagerDelegate>)getDelegateForConnection:(NSURLConnection *)connection;
- (IPMPendingConnection *)getPendingConnection:(NSURLConnection *)connection;
- (NSString *)generateKeyForConnection:(NSURLConnection *)connection;
- (void)destroyDataforConnection:(NSURLConnection *)connection;
- (void)processJSONResponseForPendingConnection:(IPMPendingConnection *)pc;
- (void)processNSStringResponseForPendingConnection:(IPMPendingConnection *)pc;
- (void)processNSImageResponseForPendingConnection:(IPMPendingConnection *)pc;
- (void)processNSDataResponseForPendingConnection:(IPMPendingConnection *)pc;
@end


@implementation IPMNetworkManager

@synthesize userAgent, sid;

#pragma mark Memory Management

- (id)init {
	if (self = [super init]) {
		connectionsData = [[NSMutableDictionary alloc] init];
		userAgent = nil;
		sid = nil;
	}
	return self;
}

- (void)dealloc {
	[sid release];
	[userAgent release];
	[connectionsData release];
	[super dealloc];
}

#pragma mark Request Methods

- (void)sendGETNetworkRequest:(NSString *)url withResponseType:(IPM_NETWORK_RESPONSE_TYPE)type delegate:(id<IPMNetworkManagerDelegate>)delegate andParam:(id<NSObject>)param {
	IPMPendingConnection * pc = [[IPMPendingConnection alloc] initWithDelegate:delegate andParam:param];
	pc.nrt = type;
	[self sendGETNetworkRequest:url withPendingConnection:pc];
	[pc release];
}

- (void)sendPOSTNetworkRequest:(NSString *)url withBody:(NSString *)body withResponseType:(IPM_NETWORK_RESPONSE_TYPE)type delegate:(id<IPMNetworkManagerDelegate>)delegate andParam:(id<NSObject>)param {
	IPMPendingConnection * pc = [[IPMPendingConnection alloc] initWithDelegate:delegate andParam:param];
	pc.nrt = type;
	NSData * bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
	[self sendPOSTNetworkRequest:url withBody:bodyData andPendingConnection:pc];
	[pc release];
}

- (void)retrieveImageAtUrl:(NSString *)imageUrl withDelegate:(id<IPMNetworkManagerDelegate>)delegate andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:imageUrl withResponseType:NSIMAGE_NRT delegate:delegate andParam:param];
}

- (void)retrieveJsonAtUrl:(NSString *)url withDelegate:(id<IPMNetworkManagerDelegate>)delegate andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withResponseType:JSON_NRT delegate:delegate andParam:param];
}

- (void)retrieveStringAtUrl:(NSString *)url withDelegate:(id<IPMNetworkManagerDelegate>)delegate andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withResponseType:NSSTRING_NRT delegate:delegate andParam:param];
}

- (void)retrieveStringAtUrl:(NSString *)url withEncoding:(NSStringEncoding)enc andDelegate:(id<IPMNetworkManagerDelegate>)delegate andParam:(id<NSObject>)param {
	IPMPendingConnection * pc = [[IPMPendingConnection alloc] initWithDelegate:delegate andParam:param];
	pc.nrt = NSSTRING_NRT;
	pc.encoding = enc;
	[self sendGETNetworkRequest:url withPendingConnection:pc];
	[pc release];
}

- (void)retrieveDataAtUrl:(NSString *)url withDelegate:(id<IPMNetworkManagerDelegate>)delegate andParam:(id<NSObject>)param {
	[self sendGETNetworkRequest:url withResponseType:NSDATA_NRT delegate:delegate andParam:param];
}

#pragma mark -
#pragma mark Connection Callbacks

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // this method is called when the server has determined that it
    // has enough information to create the NSURLResponse
	
    // it can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
	NSHTTPURLResponse * httpRes = (NSHTTPURLResponse *)response;
	//NSLog(@"%i: %@", [httpRes statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpRes statusCode]]);
	//NSLog(@"Headers: \n%@", [httpRes allHeaderFields]);
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
	DLog(@"CHALLENGE RECEIVED");
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
	NSLog(@"request failed with error: %@", [error description]);
	IPMPendingConnection * pc = [self getPendingConnection:connection];
	if ([pc.delegate respondsToSelector:@selector(networkManagerDidNotReceiveResponse:withParam:)])
		[pc.delegate networkManagerDidNotReceiveResponse:error withParam:pc.param];
	[connection release];
	[self destroyDataforConnection:connection];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	//NSLog(@"Did finish loading: %@", [connection description]);
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
		case NSSTRING_NRT:
			[self processNSStringResponseForPendingConnection:pc];
			break;
		case NSDATA_NRT:
			[self processNSDataResponseForPendingConnection:pc];
			break;
		case NSIMAGE_NRT:
			[self processNSImageResponseForPendingConnection:pc];
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

- (void)processNSImageResponseForPendingConnection:(IPMPendingConnection *)pc {
	NSImage * image = [[NSImage alloc] initWithData:pc.receivedData];
	if ([pc.delegate respondsToSelector:@selector(networkManagerDidReceiveNSImageResponse:withParam:)])
		[pc.delegate networkManagerDidReceiveNSImageResponse:image withParam:pc.param];
	[image release];
}

- (void)processNSDataResponseForPendingConnection:(IPMPendingConnection *)pc {
	if ([pc.delegate respondsToSelector:@selector(networkManagerDidReceiveNSDataResponse:withParam:)])
		[pc.delegate networkManagerDidReceiveNSDataResponse:pc.receivedData withParam:pc.param];
}

#pragma mark -
#pragma mark PrivateMethods implementation

- (void)sendGETNetworkRequest:(NSString *)urlrequest withPendingConnection:(IPMPendingConnection *)pc {
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlrequest] 
															cachePolicy:NSURLRequestUseProtocolCachePolicy 
														timeoutInterval:10.0];
	if (userAgent)
		[request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	if (sid)
		[request setValue:sid forHTTPHeaderField:@"Cookie"];
	[self sendNetworkRequest:request withPendingConnection:pc];
}

- (void)sendPOSTNetworkRequest:(NSString *)urlrequest withBody:(NSData *)requestBody andPendingConnection:(IPMPendingConnection *)pc {
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlrequest] 
															cachePolicy:NSURLRequestReloadIgnoringCacheData 
														timeoutInterval:10.0];
	[request setHTTPMethod:@"POST"];
	if (userAgent)
		[request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	if (sid)
		[request setValue:sid forHTTPHeaderField:@"Cookie"];
	[request setHTTPBody:requestBody];
	[self sendNetworkRequest:request withPendingConnection:pc];
}

- (void)sendNetworkRequest:(NSURLRequest *)request withPendingConnection:(IPMPendingConnection *)pc {
	DLog(@"SENDING REQUEST: %@", [request description]);
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
