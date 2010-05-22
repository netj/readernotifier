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
}

@property(nonatomic, readonly) SEL successMethod;
@property(nonatomic, readonly) SEL failMethod;
@property(nonatomic, readonly) id<NSObject> secondParam;

- (id)initWithSuccess:(SEL)success andFail:(SEL)fail;
- (id)initWithSuccess:(SEL)success fail:(SEL)fail andSecondParam:(id<NSObject>)sp;

@end
