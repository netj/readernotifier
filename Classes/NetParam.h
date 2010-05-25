//
//  NetParam.h
//  Reader Notifier
//
//  Created by Mike Godenzi on 5/20/10.
//  Copyright 2010 Mike Godenzi. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NetParam : NSObject {
	@private
	SEL successMethod;
	SEL failMethod;
	id<NSObject> secondParam;
	id<NSObject> target;
}

@property(nonatomic, readonly) SEL successMethod;
@property(nonatomic, readonly) SEL failMethod;
@property(nonatomic, readonly) id<NSObject> secondParam;
@property(nonatomic, readonly) id<NSObject> target;

- (id)initWithSuccess:(SEL)success andFail:(SEL)fail onTarget:(id<NSObject>)t;
- (id)initWithSuccess:(SEL)success fail:(SEL)fail andSecondParam:(id<NSObject>)sp onTarget:(id<NSObject>)t;
- (void)invokeSuccessWithFirstParam:(id)firstParam;
- (void)invokeFailWithError:(NSError *)error;
@end
