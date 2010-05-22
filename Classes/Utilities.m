//
//  Utilities.m
//  Reader Notifier
//
//  Created by Claudio Marforio on 5/22/10.
//  Copyright 2010 www.cloudgoessocial.net. All rights reserved.
//

#import "Utilities.h"


@implementation Utilities

+ (NSString *)flattenHTML:(NSString *)stringToFlatten {
	stringToFlatten = [self search:@"&quot;" andReplace:@"\"" inString:stringToFlatten];
	stringToFlatten = [self search:@"&amp;" andReplace:@"&" inString:stringToFlatten];
	stringToFlatten = [self search:@"&#39;" andReplace:@"'" inString:stringToFlatten];
	return stringToFlatten;
}

+ (NSString *)search:(NSString *)searchString andReplace:(NSString *)replaceString inString:(NSString *)inString {
	NSMutableString * mstr;
	NSRange substr;
	mstr = [NSMutableString stringWithString:inString];
	substr = [mstr rangeOfString:searchString];
	while (substr.location != NSNotFound) {
		[mstr replaceCharactersInRange:substr withString:replaceString];
        substr = [mstr rangeOfString:searchString];
    }
	return mstr;
}

+ (NSMutableArray *)reverseArray:(NSMutableArray *)array {
	NSUInteger i = 0;
	for (i = 0; i < (floor([array count]/2.0)); i++)
		[array exchangeObjectAtIndex:i withObjectAtIndex:([array count]-(i+1))];
	return array;
}

+ (NSString *)trimDownString:(NSString *)stringToTrim withMaxLenght:(NSInteger)maxLength {
	int initialLengthOfString = [stringToTrim length];
	stringToTrim = [stringToTrim substringToIndex:MIN(maxLength,[stringToTrim length])];
	// if we made a trim down, we add a couple of dots
	if (initialLengthOfString > maxLength)
		stringToTrim = [stringToTrim stringByAppendingString:@"..."];
	return stringToTrim;
}

@end
