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
+ (NSString *)trimDownString:(NSString *)stringToTrim withMaxLenght:(NSInteger)maxLength;
+ (NSString *)replaceMultiSpacesWithSingleSpace:(NSString *)s;
+ (NSURL *)getFinalURLForURL:(NSURL *)url;

@end
