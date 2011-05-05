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
	if (!stringToFlatten)
		return stringToFlatten;
	NSScanner * theScanner;
    NSString * text = nil;
    theScanner = [[NSScanner alloc] initWithString:stringToFlatten];
    while (![theScanner isAtEnd]) {
        [theScanner scanUpToString:@"<" intoString:NULL] ; 
        [theScanner scanUpToString:@">" intoString:&text] ;
		NSString * replacement;
		if ([text hasPrefix:@"<br"])
			replacement = @"\n";
		else
			replacement = @" ";
        stringToFlatten = [stringToFlatten stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@>", text] withString:replacement];
    } // while //
	[theScanner release];
	stringToFlatten = [stringToFlatten stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
	stringToFlatten = [stringToFlatten stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	stringToFlatten = [stringToFlatten stringByReplacingOccurrencesOfString:@"&#39;" withString:@"'"];
	stringToFlatten = [Utilities replaceMultiSpacesWithSingleSpace:stringToFlatten];
	stringToFlatten = [stringToFlatten stringByReplacingOccurrencesOfString:@"\n " withString:@"\n"];
	return stringToFlatten;
}

+ (NSString *)replaceMultiSpacesWithSingleSpace:(NSString *)s {
	while (YES) {
		NSRange r = [s rangeOfString:@"  "];
		if (r.location == NSNotFound)
			break;
		s = [s stringByReplacingOccurrencesOfString:@"  " withString:@" "];
	}
	return s;
}

+ (NSString *)trimDownString:(NSString *)stringToTrim withMaxLenght:(NSInteger)maxLength {
	if (maxLength >= [stringToTrim length])
		return stringToTrim;
	NSUInteger initialLengthOfString = [stringToTrim length];
	stringToTrim = [stringToTrim substringToIndex:maxLength];
	// if we made a trim down, we add 3 dots
	if (initialLengthOfString > maxLength)
		stringToTrim = [stringToTrim stringByAppendingString:@"..."];
	return stringToTrim;
}

+ (NSURL *)getFinalURLForURL:(NSURL *)url {
    NSMutableURLRequest * request =
    [NSMutableURLRequest requestWithURL:url
                            cachePolicy:NSURLRequestReloadIgnoringCacheData
                        timeoutInterval:10];
    [request setHTTPMethod:@"HEAD"];
    NSURLResponse * response;
    [NSURLConnection sendSynchronousRequest:request
                          returningResponse:&response
                                      error:nil];
    NSLog(@"final URL of %@ is %@", url, [response URL]);
    return [response URL];
}


@end
