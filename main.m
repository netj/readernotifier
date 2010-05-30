// Copyright (C) 2010 Mike Godenzi, Claudio Marforio
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
//  main.m
//  Google Reader
//
//  Created by Troels Bay on 2006-11-02.
//  Copyright 2006. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[]) {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
#ifndef DEBUG
	NSString * logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/ReaderNotifierDebug.log"];
	FILE * f = freopen([logPath fileSystemRepresentation], "a", stderr);
#endif
	DLog(@"@============== READER NOTIFIER RELOADED ==============@");
	int retVal = NSApplicationMain(argc, (const char **)argv);
#ifndef DEBUG
	fclose(f);
#endif
	[pool release];
    return retVal;
}
