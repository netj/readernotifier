//
//  Utilities.h
//  Reader Notifier
//
//  Created by Claudio Marforio on 5/22/10.
//  Copyright 2010 www.cloudgoessocial.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface Utilities : NSObject {

}

+ (NSString *)flattenHTML:(NSString *)stringToFlatten;
+ (NSString *)search:(NSString *)searchString andReplace:(NSString *)replaceString inString:(NSString *)inString;
+ (NSMutableArray *)reverseArray:(NSMutableArray *)array;
+ (NSString *)trimDownString:(NSString *)stringToTrim withMaxLenght:(NSInteger)maxLength;

@end
