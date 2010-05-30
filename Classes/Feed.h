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
//  Feed.h
//  Reader Notifier
//
//  Created by Mike Godenzi on 5/28/10.
//  Copyright 2010 Mike Godenzi. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface Feed : NSObject {
	@private
	NSString * feedUrl;
	NSString * feedId;
	NSString * link;
	NSString * title;
	NSString * source;
	NSString * summary;
	NSString * torrentcastLink;
}

@property(nonatomic, retain) NSString * feedUrl;
@property(nonatomic, retain) NSString * feedId;
@property(nonatomic, retain) NSString * link;
@property(nonatomic, retain) NSString * title;
@property(nonatomic, retain) NSString * source;
@property(nonatomic, retain) NSString * summary;
@property(nonatomic, retain) NSString * torrentcastLink;

@end
