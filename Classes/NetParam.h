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
