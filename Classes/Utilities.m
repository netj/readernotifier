// Copyright (C) 2010 Claudio Marforio
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
//  Utilities.m
//  Reader Notifier
//
//  Created by Claudio Marforio on 5/22/10.
//  Copyright 2010 www.cloudgoessocial.net. All rights reserved.
//

#import "Utilities.h"


@implementation Utilities

+ (NSString *)flattenHTML:(NSString *)stringToFlatten {
	stringToFlatten = [stringToFlatten stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
	stringToFlatten = [stringToFlatten stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	stringToFlatten = [stringToFlatten stringByReplacingOccurrencesOfString:@"&#39;" withString:@"'"];
	return stringToFlatten;
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
