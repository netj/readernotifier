//
//  NetParam.m
//  Reader Notifier
//
//  Created by Mike Godenzi on 5/20/10.
//  Copyright 2010 Mike Godenzi. All rights reserved.
//

#import "NetParam.h"


@implementation NetParam

@synthesize successMethod, failMethod, secondParam, target;

- (id)initWithSuccess:(SEL)success andFail:(SEL)fail onTarget:(id<NSObject>)t {
	if (self = [super init]) {
		successMethod = success;
		failMethod = fail;
		secondParam = nil;
		target = [t retain];
	}
	return self;
}

- (id)initWithSuccess:(SEL)success fail:(SEL)fail andSecondParam:(id<NSObject>)sp onTarget:(id<NSObject>)t {
	if (self = [super init]) {
		successMethod = success;
		failMethod = fail;
		secondParam = [sp retain];
		target = [t retain];
	}
	return self;
}

- (void)invokeSuccessWithFirstParam:(id)firstParam {
	DLog(@"INVOKING WITH SECOND PARAM: %@", [secondParam description]);
	[target performSelector:successMethod withObject:firstParam withObject:secondParam];
}

- (void)invokeFailWithError:(NSError *)error {
	[target performSelector:failMethod withObject:error];
}

- (void)dealloc {
	[secondParam release];
	[target release];
	[super dealloc];
}

@end
