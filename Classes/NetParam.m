//
//  NetParam.m
//  Reader Notifier
//
//  Created by Mike Godenzi on 5/20/10.
//  Copyright 2010 Mike Godenzi. All rights reserved.
//

#import "NetParam.h"


@implementation NetParam

@synthesize successMethod, failMethod, secondParam;

- (id)initWithSuccess:(SEL)success andFail:(SEL)fail {
	if (self = [super init]) {
		successMethod = success;
		failMethod = fail;
		secondParam = nil;
	}
	return self;
}

- (id)initWithSuccess:(SEL)success fail:(SEL)fail andSecondParam:(id<NSObject>)sp {
	if (self = [super init]) {
		successMethod = success;
		failMethod = fail;
		secondParam = [sp retain];
	}
	return self;
}

- (void)dealloc {
	[secondParam release];
	[super dealloc];
}

@end
