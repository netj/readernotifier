//
//  Feed.m
//  Reader Notifier
//
//  Created by Mike Godenzi on 5/28/10.
//  Copyright 2010 Mike Godenzi. All rights reserved.
//

#import "Feed.h"

@implementation Feed

@synthesize feedUrl, feedId, link, title, source, summary, torrentcastLink;

- (id)init {
	if (self = [super init]) {
		feedUrl = nil;
		feedId = nil;
		link = nil;
		title = nil;
		source = nil;
		summary = nil;
		torrentcastLink = nil;
	}
	return self;
}

- (void)dealloc {
	[feedUrl release];
	[feedId release];
	[link release];
	[title release];
	[source release];
	[summary release];
	[torrentcastLink release];
	[super dealloc];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"\n[\nfeedUrl: %@\nfeedId: %@\nlink: %@\ntitle: %@\nsource: %@\nsummary: %@\ntorrentcastLink: %@\n]\n",
			feedUrl, feedId, link, title, source, summary, torrentcastLink];
}

- (BOOL)isEqualToFeed:(Feed *)f {
	if ([f.feedId isEqualToString:feedId])
		return YES;
	return NO;
}

- (BOOL)isEqual:(id)object {
	if ([object isKindOfClass:[self class]]) {
		Feed * f = (Feed *)object;
		return [self isEqualToFeed:f];
	}
	return NO;
}

@end
