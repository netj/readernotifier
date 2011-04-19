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
//  MainController.m
//  Reader Notifier
//
//  Created by Eli Dourado on 12/8/05.
//  Modified by Troels Bay (troelsbay@troelsbay.eu)
//	Modified by Mike Godenzi (godenzim@gmail.com) and Claudio Marforio (www.cloudgoessocial.net) on 5/20/10
//

#import "MainController.h"
#import "Keychain.h"
#import "IPMNetworkManager.h"
#import "NetParam.h"
#import "Utilities.h"
#import "Feed.h"

typedef enum _FIRST_FIELDS {
	READER_FF,
	SUBSCRIBE_FF,
	PREFERENCES_FF,
	CHECKNOW_FF,
	SEPARATOR_FF
} FIRST_FIELDS;

typedef enum _NORMAL_BUTTON_OFFSETS {
	SEPARATOR1_NBO,
	MARK_ALL_NBO,
	OPEN_ALL_NBO,
	SEPARATOR2_NBO
} NORMAL_BUTTON_OFFSETS;

// 27 with special icons, 29 else
#define ourStatusItemWithLength 29
#define versionBuildNumber 110
#define indexOfPreviewFields (SEPARATOR_FF + 1)
#define maxLettersInSummary 5000
#define maxLettersInSource 20
#define maxLettersInTitle 60
#define secondsToSleep 60
#define kUserAgent @"reader-notifier-reloaded/2.2.1"

@interface MainController (PrivateMethods)
- (void)shareFeed:(Feed *)f;
- (void)processLoginToGoogle:(NSString *)result;
- (void)processFailLoginToGoogle:(NSError *)error;
- (void)processGoogleFeed:(id)jsonItem;
- (void)processFailGoogleFeed:(NSError *)error;
- (void)processUnreadCount:(id)jsonItem withDeferred:(NetParam *)dc;
- (void)processFailUnreadCount:(NSError *)error;
- (void)processDownloadFile:(NSData *)result withName:(NSString *)filename;
- (void)processTokenFromGoogle:(NSString *)result;
- (void)processFailTokenFromGoogle:(NSError *)error;
- (void)printStatus;
- (void)printFeeds;
- (void)setUpMarkAllAsRead;
- (void)downloadAndManageTorrentFileForFeed:(Feed *)f;
- (void)updateTorrentCasting;
- (void)updateNormalButtons;
- (void)updateFeeds;
- (void)updateNotifications;
- (void)updateShowCount;
- (void)updateReadLabel;
- (void)parseUnreadCount:(NSDictionary *)dict;
- (void)setUpMainFeedItem:(NSMenuItem *)item withTitleTag:(NSString *)trimmedTitleTag sourceTag:(NSString *)trimmedSourceTag forFeed:(Feed *)f;
- (void)setUpCommandFeedItem:(NSMenuItem *)item withSourceTag:(NSString *)trimmedSourceTag forFeed:(Feed *)f;
- (void)setUpShiftFeedItem:(NSMenuItem *)item withSourceTag:(NSString *)trimmedSourceTag forFeed:(Feed *)f;
- (Feed *)findFeedWithId:(NSString *)feedId;
- (Feed *)feedForIndex:(NSUInteger)index;
- (void)removeFeed:(Feed *)f;
@end

@implementation MainController

#pragma mark MemoryManagement

- (id)init {
	if (self = [super init]) {
		[self setupEventHandlers];
		oldFeeds = [[NSMutableArray alloc] init];
		feeds = [[NSMutableArray alloc] init];
		newFeeds = [[NSMutableArray alloc] init];
		cookieHeader = nil;
		NSMutableDictionary * defaultPrefs = [NSMutableDictionary dictionary];
		[defaultPrefs setObject:@"20" forKey:@"maxItems"];
		[defaultPrefs setObject:@"10" forKey:@"timeDelay"];
		[defaultPrefs setObject:@"" forKey:@"Label"];
		[defaultPrefs setObject:@"5" forKey:@"maxNotifications"];
		[defaultPrefs setObject:@"NO" forKey:@"EnableTorrentCastMode"];
		prefs = [[NSUserDefaults standardUserDefaults] retain];
		[prefs registerDefaults:defaultPrefs];	
		networkManager = [[IPMNetworkManager alloc] init];
		networkManager.userAgent = kUserAgent;
		currentToken = nil;
		endOfFeedIndex = indexOfPreviewFields;
		needToRemoveNormalButtons = NO;
		// in earlier versions this was set to the actual user password, which we would want to override
		[prefs setObject:@"NotForYourEyes" forKey:@"Password"];
		NSArray * o = [NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:14.0], nil];
		NSArray * k = [NSArray arrayWithObjects: NSFontAttributeName, nil];
		normalAttrsDictionary = [[NSDictionary alloc] initWithObjects:o 
															  forKeys:k];
		o = [NSArray arrayWithObjects:[NSFont fontWithName:@"Lucida Grande" size:12.0], [NSColor grayColor], nil];
		k = [NSArray arrayWithObjects:NSFontAttributeName, NSForegroundColorAttributeName, nil];
		smallAttrsDictionary = [[NSDictionary alloc] initWithObjects:o 
															 forKeys:k];
		// we need this to know when the computer wakes from sleep
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(awakenFromSleep) name:NSWorkspaceDidWakeNotification object:nil];
	}
	return self;
}

- (void)dealloc {
	[cookieHeader release];
    [statusItem release];
	[lastCheckTimer invalidate];
	[lastCheckTimer release];
	[prefs release];
	[networkManager release];
	[currentToken release];
	[nounreadItemsImage release];
	[unreadItemsImage release];
	[errorImage release];
	[highlightedImage release];
	[oldFeeds release];
	[feeds release];
	[newFeeds release];
	[normalAttrsDictionary release];
	[smallAttrsDictionary release];
    [super dealloc];
}

- (void)awakeFromNib {
	[NSApp activateIgnoringOtherApps:YES];
	// Growl
	[GrowlApplicationBridge setGrowlDelegate:self];
	if ([[prefs valueForKey:@"useColoredNoUnreadItemsIcon"] intValue] == 1)
		nounreadItemsImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"nounreadalt" ofType:@"png"]];	
	else
		nounreadItemsImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"nounread" ofType:@"png"]];
	if ([[prefs valueForKey:@"useColoredNoUnreadItemsIcon"] intValue] == 2) {
		unreadItemsImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"nounread" ofType:@"png"]];
		errorImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"bwerror" ofType:@"png"]];
	} else {
		unreadItemsImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"unread" ofType:@"png"]];
		errorImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"error" ofType:@"png"]];
	}
	highlightedImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"highunread" ofType:@"png"]];
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:ourStatusItemWithLength] retain]; //NSVariableStatusItemLength] retain];
	[statusItem setHighlightMode:YES];
	[statusItem setTitle:@""];
	[statusItem setMenu:GRMenu];
    [statusItem setImage:nounreadItemsImage];
    [statusItem setAlternateImage:highlightedImage];
	[statusItem setEnabled:YES];
	lastCheckMinute = 0;
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Go to Google Reader",nil) 
						  action:@selector(launchSite:) 
				   keyEquivalent:@"" atIndex:READER_FF] setTarget:self];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Subscribe to Feed...",nil) 
						  action:@selector(openAddFeedWindow:) 
				   keyEquivalent:@"" atIndex:SUBSCRIBE_FF] setTarget:self];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Preferences...",nil) 
						  action:@selector(openPrefs:) keyEquivalent:@"" 
						 atIndex:PREFERENCES_FF] setTarget:self];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Check Now",nil) 
						  action:@selector(checkNow:) keyEquivalent:@"" 
						 atIndex:CHECKNOW_FF] setTarget:self];	
	[[GRMenu itemAtIndex:CHECKNOW_FF] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) andSmallText:@""]];
	[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:SEPARATOR_FF];
	[cookieHeader release];
	cookieHeader = nil;
	[self loginToGoogle];
	if ([prefs boolForKey:@"SUCheckAtStartup"]) {
		DLog(@"CHECKING FOR UPDATES");
		[updater checkForUpdatesInBackground];
	}
	// Get the info dictionary (Info.plist)
	NSString * bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
	NSString * bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	DLog(@"Hello. %@ Build %@", bundleName, bundleVersion);
	if ([prefs valueForKey:@"torrentCastFolderPath"])
		[torrentCastFolderPath setStringValue:[prefs valueForKey:@"torrentCastFolderPath"]];
	DLog(@"We're on %@", [[NSProcessInfo processInfo] operatingSystemVersionString]);
	NSString * versionText = [[NSString alloc] initWithFormat:@"%@ version %@", bundleName, bundleVersion];
	[versionLabel setTitleWithMnemonic:versionText];
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)gitHubButtonPressed:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://github.com/godenzim/readernotifier"]];
}

- (IBAction)blogButtonPressed:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.cloudgoessocial.net/"]];
}

- (IBAction)checkNow:(id)sender {	
	// first we check if the user has put in a password and username beforehand
	if ([[self getUserPasswordFromKeychain] isEqualToString:@""]) {
		[self displayAlertWithHeader:NSLocalizedString(@"Error", nil) 
							 andBody:NSLocalizedString(@"It seems you do not have a password in the Keychain. "
													   @"Please go to the preferences now and supply your password", nil)];
		[self errorImageOn];
		[cookieHeader release];
		cookieHeader = nil;
	} else if ([[prefs valueForKey:@"Username"] isEqualToString:@""] || ![prefs valueForKey:@"Username"]) {
		[self displayAlertWithHeader:NSLocalizedString(@"Error",nil) 
							 andBody:NSLocalizedString(@"It seems you do not have a username filled in. "
													   @"Please go to the preferences now and supply your username", nil)];
		[self errorImageOn];
		[cookieHeader release];
		cookieHeader = nil;
	} else {
		// then we make sure it has validated and provided us with a login
		if (cookieHeader) {
			[self createLastCheckTimer];
			[lastCheckTimer fire];
			[self retrieveGoogleFeed];
		} else
			[self loginToGoogle];
	}
}

- (IBAction)launchSite:(id)sender {
	NSString * format = @"https://www.google.com/accounts/SetSID?ssdc=1&sidt=%@&continue=http%%3A%%2F%%2Fgoogle.com%%2Freader%%2Fview%%2F";
	NSString * url = [NSString stringWithFormat:format, [cookieHeader objectForKey:@"Cookie"]];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

- (IBAction)openAllItems:(id)sender {
	for (Feed * f in feeds) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:f.link]];
		NSString * feedstring = [f.feedUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSString * format = @"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/"
							@"-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@";
		NSString * url = [NSString stringWithFormat:format, [self getURLPrefix], feedstring, f.feedId, currentToken];
		[networkManager sendPOSTNetworkRequest:url withBody:@"" headerFields:cookieHeader responseType:NORESPONSE_NRT delegate:nil andParam:nil];
	}
	totalUnreadCount -= [feeds count];
	[self checkNow:nil];
}

- (IBAction)markAllAsRead:(id)sender {
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(markAllAsReadDeferred) andFail:0 onTarget:self];
	[self getUnreadCountWithDeferredCall:np];
	[np release];
}

- (IBAction)launchLink:(id)sender {
	// Because we cannot be absolutely sure that the user has not clicked the GRMenu before a new update has occored 
	// (we make use of the id - and hopefully it will be an absolute).
	Feed * f = nil;
	if (f = [self findFeedWithId:[sender title]]) {
		if ([[prefs valueForKey:@"showCount"] boolValue])
			[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d", totalUnreadCount - 1]]];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:f.link]];
		[self markOneAsRead:f];
	} else
		DLog(@"Item has already gone away, so we cannot refetch it");
}

- (IBAction)doCommandActionFromMenu:(id)sender {
	Feed * f = nil;
	if (f = [self findFeedWithId:[sender title]]) {
		if ([[prefs valueForKey:@"onOptionalActAlsoStarItem"] boolValue])
			[self markOneAsStarred:f];
		else
			[self markOneAsRead:f];
	} else
		DLog(@"Item has already gone away, so we cannot refetch it");
}

- (IBAction)doShiftActionFromMenu:(id)sender {
	Feed * f = nil;
	if (f = [self findFeedWithId:[sender title]]) {
		if ([[prefs valueForKey:@"shareOnShift"] boolValue])
			[self shareFeed:f];
		else
			[self markOneAsRead:f];
	} else
		DLog(@"Item has already gone away, so we cannot refetch it");
}

- (IBAction)launchErrorHelp:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://troelsbay.eu/software/reader"]];
}

- (IBAction)openPrefs:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	[preferences makeKeyAndOrderFront:nil];
}

- (IBAction)openAddFeedWindow:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	[addfeedwindow makeKeyAndOrderFront:nil];
	[addNewFeedUrlField setStringValue:@"http://"];
}

- (IBAction)addFeedFromUI:(id)sender {
	[addfeedwindow close];
	[self addFeed:[addNewFeedUrlField stringValue]];
}

- (IBAction)checkGoogleAuth:(id)sender {
	[prefs setObject:[NSString stringWithString:[usernameField stringValue]] forKey:@"Username"];
	NSString * password = [passwordField stringValue];
	if ([Keychain checkForExistanceOfKeychain])
		[Keychain modifyKeychainItem:password];
	else
		[Keychain addKeychainItem:password];
	isCheckingCredential = YES;
	[self loginToGoogle];
}

- (IBAction)selectTorrentCastFolder:(id)sender {
	NSOpenPanel * op = [NSOpenPanel openPanel];
	[op setCanChooseDirectories:YES];
	[op setCanChooseFiles:NO];
	[op setAllowsMultipleSelection:NO];
	[op setResolvesAliases:NO];
	[op beginSheetForDirectory:nil 
						  file:@"" 
						 types:nil
				modalForWindow:preferences 
				 modalDelegate:self 
				didEndSelector:@selector(selectTorrentCastFolderEnded:returnCode:contextInfo:) 
				   contextInfo:nil];
}

#pragma mark -
#pragma mark Growl Method

- (void)growlNotificationWasClicked:(id)clickContext {
	[self launchLink:[GRMenu itemWithTitle:clickContext]];
}


- (NSDictionary *)registrationDictionaryForGrowl {
	NSArray * notifications = [NSArray arrayWithObjects:
							   NSLocalizedString(@"New Unread Items",nil),
							   NSLocalizedString(@"New Subscription",nil),
							   nil];
	NSDictionary * regDict = [NSDictionary dictionaryWithObjectsAndKeys:
							  @"Google Reader Notifier", GROWL_APP_NAME,
							  notifications, GROWL_NOTIFICATIONS_ALL,
							  notifications, GROWL_NOTIFICATIONS_DEFAULT,
							  nil];
	return regDict;
}

#pragma mark -
#pragma mark Netowrk methods

- (void)getUnreadCountWithDeferredCall:(NetParam *)dc {
	NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/unread-count?all=true&autorefresh=true&output=json&client=%@", 
					  [self getURLPrefix], kUserAgent];
	NetParam * np;
	if (dc)
		np = [[NetParam alloc] initWithSuccess:@selector(processUnreadCount:withDeferred:) fail:@selector(processFailUnreadCount:) andSecondParam:dc onTarget:self];
	else
		np = [[NetParam alloc] initWithSuccess:@selector(processUnreadCount:withDeferred:) andFail:@selector(processFailUnreadCount:) onTarget:self];
	[networkManager retrieveJsonAtUrl:url withHeaderFields:cookieHeader delegate:self andParam:np];
	[np release];
}

- (void)retrieveGoogleFeed {
	// in case we had an error before, clear the highlightedimage and displaymessage
	[statusItem setAlternateImage:highlightedImage];
	@synchronized(feeds) {
		[oldFeeds setArray:feeds];
		[feeds removeAllObjects];
		[newFeeds removeAllObjects];
	}
	/* new */
	NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/stream/contents/user/-/%@?r=d&xt=user/-/state/com.google/read&n=%d",
					  [self getURLPrefix], [self getLabel], [[prefs valueForKey:@"maxItems"] intValue] + 1];
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(processGoogleFeed:) andFail:@selector(processFailGoogleFeed:) onTarget:self];
	DLog(@"retrieving with headers: %@", [cookieHeader description]);
	[networkManager retrieveJsonAtUrl:url withHeaderFields:cookieHeader delegate:self andParam:np];
	[np release];
}

- (void)downloadFile:(NSString *)filename atUrl:(NSString *)url {
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(processDownloadFile:withName:) fail:0 andSecondParam:filename onTarget:self];
	[networkManager retrieveDataAtUrl:url withDelegate:self andParam:np];
	[np release];
}

- (void)loginToGoogle {
	NSString * p1 = [self usernameForAuthenticationChallengeWithParam:nil];
	NSString * p2 = [self passwordForAuthenticationChallengeWithParam:nil];
	DLog(@"LOG IN WITH USERNAME: %@ PASSWORD: %@", p1, p2);
	NSString * params = [NSString stringWithFormat:@"accountType=HOSTED_OR_GOOGLE&Email=%@&Passwd=%@&service=reader&source=%@", 
						 p1, p2, kUserAgent];
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(processLoginToGoogle:) andFail:@selector(processFailLoginToGoogle:) onTarget:self];
	NSDictionary * headers = [NSDictionary dictionaryWithObjectsAndKeys:@"application/x-www-form-urlencoded", @"Content-type", nil];
	[networkManager sendPOSTNetworkRequest:@"https://www.google.com/accounts/ClientLogin"
									withBody:params 
								headerFields:headers 
								responseType:NSSTRING_NRT 
									delegate:self 
									andParam:np];
	[np release];
}

- (void)getTokenFromGoogle {
	NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/token?client=%@", [self getURLPrefix], kUserAgent];
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(processTokenFromGoogle:) andFail:@selector(processFailTokenFromGoogle:) onTarget:self];
	DLog(@"RETRIEVING TOKEN WITH HEADERS: %@", [cookieHeader description]);
	[networkManager retrieveStringAtUrl:url withHeaderFields:cookieHeader delegate:self andParam:np];
	[np release];
}

- (void)markOneAsStarred:(Feed *)f {
	NSString * feedstring = [f.feedUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString * idsstring = [f.feedId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?client=%@", [self getURLPrefix], kUserAgent];
	NSString * body = [NSString stringWithFormat:@"s=%@&i=%@&ac=edit-tags&a=user%%2F-%%2Fstate%%2Fcom.google%%2Fstarred&T=%@", 
					   feedstring, idsstring, currentToken];
	[networkManager sendPOSTNetworkRequest:url withBody:body headerFields:cookieHeader responseType:NORESPONSE_NRT delegate:nil andParam:nil];
	[self markOneAsRead:f];
}

- (void)shareFeed:(Feed *)f {
	NSString * feedstring = [f.feedUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString * idsstring = [f.feedId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?client=%@", [self getURLPrefix], kUserAgent];
	NSString * body = [NSString stringWithFormat:@"s=%@&i=%@&ac=edit-tags&a=user%%2F-%%2Fstate%%2Fcom.google%%2Fbroadcast&T=%@", 
					   feedstring, idsstring, currentToken];
	[networkManager sendPOSTNetworkRequest:url withBody:body headerFields:cookieHeader responseType:NORESPONSE_NRT delegate:nil andParam:nil];
	[self markOneAsRead:f];
}

- (void)markOneAsRead:(Feed *)f {
	NSString * feedstring = [f.feedUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString * format = @"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/"
						@"-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@";
	NSString * url = [NSString stringWithFormat:format, [self getURLPrefix], feedstring, f.feedId, currentToken];
	[networkManager sendPOSTNetworkRequest:url withBody:@"" headerFields:cookieHeader responseType:NORESPONSE_NRT delegate:nil andParam:nil];
	totalUnreadCount--;
	[oldFeeds setArray:feeds];
	[self removeFeed:f];
	[self printStatus];
	[self updateMenu];
}

- (void)markAllAsReadDeferred {
	if (totalUnreadCount == [feeds count] || [[prefs valueForKey:@"alwaysEnableMarkAllAsRead"] boolValue]) {
		NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/mark-all-as-read?client=%@", [self getURLPrefix], kUserAgent];
		NSString * replacedLabel = [[self getLabel] stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
		NSString * body = [NSString stringWithFormat:@"s=user%%2F-%%2F%@&T=%@", 
						   replacedLabel, currentToken];
		[networkManager sendPOSTNetworkRequest:url withBody:body headerFields:cookieHeader responseType:NORESPONSE_NRT delegate:nil andParam:nil];
		[oldFeeds setArray:feeds];
		[feeds removeAllObjects];
		totalUnreadCount = 0;
		[self updateMenu];
	} else if (totalUnreadCount != -1) {
		[self displayAlertWithHeader:NSLocalizedString(@"Warning",nil) 
							 andBody:NSLocalizedString(@"There are new unread items available online. Mark all as read has been canceled.", nil)];
		[self checkNow:nil];
	}
}

- (void)addFeed:(NSString *)url {
	NSString * sanitizedUrl = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	if (![[prefs valueForKey:@"dontVerifySubscription"] boolValue]) {
		NSString * completeUrl = [NSString stringWithFormat:@"%@://www.google.com/reader/preview/*/feed/%@", [self getURLPrefix], sanitizedUrl];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:completeUrl]];
	} else {
		NSString * sendString = [NSString stringWithFormat:@"%@://www.google.com/reader/quickadd=%@&T=%@", [self getURLPrefix], sanitizedUrl, currentToken];
		[networkManager sendPOSTNetworkRequest:sendString withBody:@"" headerFields:cookieHeader responseType:NORESPONSE_NRT delegate:nil andParam:nil];
		// we need to sleep a little
		[NSThread sleepForTimeInterval:1.5];
		[self checkNow:nil];
	}
}

#pragma mark -
#pragma mark IPMNetworkManagerDelegate methods

- (void)networkManagerDidReceiveJSONResponse:(id)jsonItem withParam:(id<NSObject>)param {
	NetParam * nParam = (NetParam *)param;
	[nParam invokeSuccessWithFirstParam:jsonItem];
}

- (void)networkManagerDidReceiveNSStringResponse:(NSString *)response withParam:(id<NSObject>)param {
	NetParam * nParam = (NetParam *)param;
	[nParam invokeSuccessWithFirstParam:response];
}

- (void)networkManagerDidReceiveNSDataResponse:(NSData *)response withParam:(id<NSObject>)param {
	NetParam * nParam = (NetParam *)param;
	[nParam invokeSuccessWithFirstParam:response];
}

- (void)networkManagerDidNotReceiveResponse:(NSError *)error withParam:(id<NSObject>)param {
	if ([error code] == 401)
		[self loginToGoogle];
	NetParam * nParam = (NetParam *)param;
	[nParam invokeFailWithError:error];
}

- (NSString *)usernameForAuthenticationChallengeWithParam:(id<NSObject>)param {
	return [[prefs valueForKey:@"Username"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)passwordForAuthenticationChallengeWithParam:(id<NSObject>)param {
	return [[self getUserPasswordFromKeychain] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark Processing

- (void)processLoginToGoogle:(NSString *)result {
	DLog(@"LOGIN RESULT: %@", result);
	NSString * storedToken = nil;
	NSArray * tmp = [result componentsSeparatedByString:@"Auth="];
	storedToken = [NSString stringWithFormat:@"GoogleLogin auth=%@", [tmp objectAtIndex:1]];
	storedToken = [storedToken substringToIndex:(storedToken.length - 1)];
	if (storedToken) {
		if (cookieHeader)
			[cookieHeader release];
		cookieHeader = [[NSDictionary alloc] initWithObjectsAndKeys:storedToken, @"Authorization", @"application/x-www-form-urlencoded", @"Content-type" , nil];
		if (isCheckingCredential) {
			[self displayAlertWithHeader:NSLocalizedString(@"Success",nil) andBody:NSLocalizedString(@"You are now connected to Google", nil)];
			isCheckingCredential = NO;
		}
		[self checkNow:nil];
		[self createLastCheckTimer];
		[lastCheckTimer fire];
	} else {
		if ([[self getUserPasswordFromKeychain] isEqualToString:@""]) {
			[self displayAlertWithHeader:NSLocalizedString(@"Error",nil) 
								 andBody:NSLocalizedString(@"It seems you do not have a password in the Keychain. "
														   @"Please go to the preferences now and supply your password",nil)];
			[self displayMessage:@"please enter login details"];
		} else if ([[prefs valueForKey:@"Username"] isEqualToString:@""] || ![prefs valueForKey:@"Username"]) {
			[self displayAlertWithHeader:NSLocalizedString(@"Error",nil) 
								 andBody:NSLocalizedString(@"It seems you do not have a username filled in. "
														   @"Please go to the preferences now and supply your username",nil)];
			[self displayMessage:@"please enter login details"];
		} else {
			[self displayAlertWithHeader:NSLocalizedString(@"Authentication error",nil) 
								 andBody:[NSString stringWithFormat:@"Reader Notifier could not handshake with Google. "
										  @"You probably have entered a wrong user or pass. The error supplied by Google servers was: %@", result]];
			[self displayMessage:@"wrong username or password"];				
		}
		[cookieHeader release];
		cookieHeader = nil;
		[self errorImageOn];
	}
}

- (void)processFailLoginToGoogle:(NSError *)error {
	[cookieHeader release];
	cookieHeader = nil;
	[feeds removeAllObjects];
	[oldFeeds removeAllObjects];
	[self displayMessage:@"no Internet connection"];
	[self errorImageOn];
	[self createLastCheckTimer];
}

- (void)processGoogleFeed:(id)jsonItem {
	//DLog(@"FEED RECEIVED: %@", [jsonItem description]);
	NSDictionary * dict = (NSDictionary *)jsonItem;
	NSMutableArray * items = [[NSMutableArray alloc] initWithArray:[dict objectForKey:@"items"]];
	moreUnreadExistInGRInterface = NO;
	if ([items count] > [[prefs valueForKey:@"maxItems"] integerValue]) {
		moreUnreadExistInGRInterface = YES;
		[items removeLastObject];
	}
	@synchronized(feeds) {
		for (NSDictionary * item in items) {
			Feed * f = [[Feed alloc] init];
			NSDictionary * origin = [item objectForKey:@"origin"];
			f.feedUrl = [origin objectForKey:@"streamId"];
			f.source = [origin objectForKey:@"title"];
			f.feedId = [item objectForKey:@"id"];
			f.link = [[[item objectForKey:@"alternate"] lastObject] objectForKey:@"href"];
			f.title = [item objectForKey:@"title"];
			NSString * summary = [[item objectForKey:@"summary"] objectForKey:@"content"];
			f.summary = [Utilities trimDownString:[Utilities flattenHTML:summary] withMaxLenght:maxLettersInSummary];
			f.torrentcastLink = @"";
			NSArray * enclosures = nil;
			if (enclosures = [item objectForKey:@"enclosure"]) {
				NSDictionary * enclosure = [enclosures lastObject];
				if ([[enclosure objectForKey:@"type"] isEqualToString:@"application/x-bittorrent"])
					f.torrentcastLink = [enclosure objectForKey:@"href"];
			}
			[feeds addObject:f];
			[f release];
		}
		[self updateMenu];
	}
	[items release];
	[self getUnreadCountWithDeferredCall:nil];
}

- (void)processFailGoogleFeed:(NSError *)error {
	[self errorImageOn];
	[self createLastCheckTimer];
	[lastCheckTimer fire];
}

- (void)processUnreadCount:(id)jsonItem withDeferred:(NetParam *)dc {
	NSDictionary * dict = (NSDictionary *)jsonItem;
	[self parseUnreadCount:dict];
	DLog(@"The total count of unread items is now %d", totalUnreadCount);
	[self updateShowCount];
	if (dc)
		[dc invokeSuccessWithFirstParam:nil];
}

- (void)processFailUnreadCount:(NSError *)error {
	totalUnreadCount = -1;
	[self errorImageOn];
	[self createLastCheckTimer];
	[lastCheckTimer fire];
}

- (void)processDownloadFile:(NSData *)result withName:(NSString *)filename {
	NSString * filePath = [NSString stringWithFormat:@"%@/%@", [prefs valueForKey:@"torrentCastFolderPath"], filename];
	DLog(@"FILE DOWNLOADED SAVING IT TO: %@", filename);
	[result writeToFile:filePath atomically:YES];
	if ([[prefs valueForKey:@"openTorrentAfterDownloading"] boolValue])
		[[NSWorkspace sharedWorkspace] openFile:filePath];
}

- (void)processTokenFromGoogle:(NSString *)result {
	DLog(@"TOKEN RESULT: %@", result);
	if (currentToken)
		[currentToken release];
	currentToken = [result retain];
}

- (void)processFailTokenFromGoogle:(NSError *)error {
	DLog(@"TOKEN ERROR: %@", [error description]);
	DLog(@"CURRENT TOKEN: %@", currentToken);
}

#pragma mark -
#pragma mark Parsing Methods

- (void)parseUnreadCount:(NSDictionary *)dict {
	NSInteger count = 0;
	NSArray * unreads = [dict objectForKey:@"unreadcounts"];
	for (NSDictionary * unread in unreads) {
		NSString * idValue = [unread objectForKey:@"id"];
		if (![idValue hasSuffix:@"/state/com.google/reading-list"])
			continue;
		NSString * stringCount = [unread objectForKey:@"count"];
		count = [stringCount integerValue];
	}
	totalUnreadCount = count;
}

#pragma mark -
#pragma mark Timers

- (void)createLastCheckTimer {
	lastCheckMinute = 0;
	if (lastCheckTimer) {
		[lastCheckTimer invalidate];
		[lastCheckTimer release];
	}
	lastCheckTimer = [[NSTimer scheduledTimerWithTimeInterval:secondsToSleep target:self selector:@selector(lastTimeCheckedTimer:) userInfo:nil repeats:YES] retain];
}

- (void)lastTimeCheckedTimer:(NSTimer *)timer {
	[self getTokenFromGoogle];
	if (lastCheckMinute >= [[prefs valueForKey:@"timeDelay"] integerValue]) {
		[self displayLastTimeMessage:NSLocalizedString(@"Checking...",nil)];
		[self checkNow:nil];
	} else {
		if (lastCheckMinute == 0)
			[self displayLastTimeMessage:NSLocalizedString(@"Checked less than 1 min ago",nil)];
		else if (lastCheckMinute == 1)
			[self displayLastTimeMessage:NSLocalizedString(@"Checked 1 min ago",nil)];
		else if (lastCheckMinute < 60)
			[self displayLastTimeMessage:[NSString stringWithFormat:NSLocalizedString(@"Checked %d min ago",nil), lastCheckMinute]];
		else {
			NSUInteger hours = lastCheckMinute / 60;
			[self displayLastTimeMessage:[NSString stringWithFormat:NSLocalizedString(@"Checked %d hour(s) ago",nil), hours]];
		}
		lastCheckMinute++;
	}
}

#pragma mark -
#pragma mark Menu Update Methods

- (void)updateMenu {
	@synchronized(self) {
		[self updateTorrentCasting];
		[self updateFeeds];
		[self updateNormalButtons];
		[self updateNotifications];
		[self updateShowCount];
	}
	[self printStatus];
}

- (void)downloadAndManageTorrentFileForFeed:(Feed *)f {
	[self downloadFile:[NSString stringWithFormat:@"%@.torrent", f.title] atUrl:f.torrentcastLink];
	NSString * feedstring = [f.feedUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString * format = @"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/"
						@"-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@";
	NSString * url = [NSString stringWithFormat:format, [self getURLPrefix], feedstring, f.feedId, currentToken];
	[networkManager sendPOSTNetworkRequest:url withBody:@"" headerFields:cookieHeader responseType:NORESPONSE_NRT delegate:nil andParam:nil];
}

- (void)updateTorrentCasting {
	// EXPERIMENTAL
	/// This is a feature in development!
	/// The automatical downloading of certain feeds
	// TORRENTCASTING
	if ([prefs boolForKey:@"EnableTorrentCastMode"]) {
		NSMutableArray * tmp = [[NSMutableArray alloc] init];
		for (Feed * f in feeds) {
			if ([f.torrentcastLink isEqualToString:@""])
				continue;
			NSFileManager * fm = [NSFileManager defaultManager];	
			if ([fm fileExistsAtPath:[prefs valueForKey:@"torrentCastFolderPath"]]) {
				[self downloadAndManageTorrentFileForFeed:f];
				[tmp addObject:f];
			} else {
				[self displayAlertWithHeader:NSLocalizedString(@"TorrentCast Error",nil) 
									 andBody:NSLocalizedString(@"Reader Notifier has found a new TorrentCast. "
															   @"However we are unable to download it because the folder you've specified does not exists. "
															   @"Please choose a new folder in the preferences. "
															   @"In addition, TorrentCasting has been disabled.", nil)];
				[prefs setBool:NO forKey:@"EnableTorrentCastMode"];
			}
		}
		for (Feed * f in tmp)
			[self removeFeed:f];
		[tmp release];
	}
}

- (void)setUpMarkAllAsRead {
	if (![[prefs valueForKey:@"alwaysEnableMarkAllAsRead"] boolValue]) {			
		[GRMenu insertItemWithTitle:NSLocalizedString(@"More unread items exist", nil) action:nil keyEquivalent:@"" atIndex:endOfFeedIndex + MARK_ALL_NBO]; 
		[[GRMenu itemAtIndex:endOfFeedIndex] setToolTip:NSLocalizedString(@"Mark all as read has been disabled", nil)];
	} else {
		[[GRMenu insertItemWithTitle:NSLocalizedString(@"Mark all as read", nil) 
							  action:@selector(markAllAsRead:) 
					   keyEquivalent:@"" 
							 atIndex:endOfFeedIndex + MARK_ALL_NBO] setTarget:self];
		NSAttributedString * as = [self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Mark all as read", nil) 
															   andSmallText:NSLocalizedString(@"Warning, items online will be marked read", nil)];
		[[GRMenu itemAtIndex:endOfFeedIndex] setAttributedTitle:as];
		[[GRMenu itemAtIndex:endOfFeedIndex] setToolTip:NSLocalizedString(@"There are more unread items online in the Google Reader interface. "
																		  @"This function will cause Google Reader Notifier to mark all as read "
																		  @"- whether or not they are visible in the menubar", nil)];
	}
}

- (void)updateNormalButtons {
	if (needToRemoveNormalButtons) {
		for (NSUInteger i = 0; i <= SEPARATOR2_NBO; i++)
			[GRMenu removeItemAtIndex:endOfFeedIndex];
		needToRemoveNormalButtons = NO;
	}
	if ([feeds count] && ![[prefs valueForKey:@"minimalFunction"] boolValue]) {
		// if we have any items in the list, we should put a nice little bar between the normal buttons and the feeditems
		[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:endOfFeedIndex + SEPARATOR1_NBO];
		if (moreUnreadExistInGRInterface)
			[self setUpMarkAllAsRead];
		else
			[[GRMenu insertItemWithTitle:NSLocalizedString(@"Mark all as read",nil) 
								  action:@selector(markAllAsRead:) 
						   keyEquivalent:@"" 
								 atIndex:endOfFeedIndex + MARK_ALL_NBO] setTarget:self];
		[[GRMenu insertItemWithTitle:NSLocalizedString(@"Open all items",nil) 
							  action:@selector(openAllItems:) 
					   keyEquivalent:@"" 
							 atIndex:endOfFeedIndex + OPEN_ALL_NBO] setTarget:self];
		[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:endOfFeedIndex + SEPARATOR2_NBO];
		needToRemoveNormalButtons = YES;
	}
}

- (void)setUpMainFeedItem:(NSMenuItem *)item withTitleTag:(NSString *)trimmedTitleTag sourceTag:(NSString *)trimmedSourceTag forFeed:(Feed *)f {
	[item setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag andSmallText:trimmedTitleTag]];
	if (![[prefs valueForKey:@"dontShowTooltips"] boolValue])
		[item setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Title: %@\nFeed: %@\n\n%@", nil), f.title, f.source, f.summary]];
	[item setTitle:f.feedId];
	[item setTarget:self];
	[item setKeyEquivalentModifierMask:0];
}

- (void)setUpCommandFeedItem:(NSMenuItem *)item withSourceTag:(NSString *)trimmedSourceTag forFeed:(Feed *)f {
	if ([[prefs valueForKey:@"onOptionalActAlsoStarItem"] boolValue])
		[item setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag 
															  andSmallText:NSLocalizedString(@"Star item and mark as read", nil)]];
	else
		[item setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag 
															  andSmallText:NSLocalizedString(@"Mark item as read", nil)]];
	[item setKeyEquivalentModifierMask:NSCommandKeyMask];
	[item setAlternate:YES];
	// even though setting the title twice seems like doing double work, we have to, because [sender title] will always be the last set title!
	[item setTitle:f.feedId];
	[item setTarget:self];
}

- (void)setUpShiftFeedItem:(NSMenuItem *)item withSourceTag:(NSString *)trimmedSourceTag forFeed:(Feed *)f {
	if ([[prefs valueForKey:@"shareOnShift"] boolValue])
		[item setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag 
															  andSmallText:NSLocalizedString(@"Share item and mark as read", nil)]];
	else
		[item setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag 
															  andSmallText:NSLocalizedString(@"Mark item as read", nil)]];
	[item setKeyEquivalentModifierMask:NSShiftKeyMask];
	[item setAlternate:YES];
	// even though setting the title twice seems like doing double work, we have to, because [sender title] will always be the last set title!
	[item setTitle:f.feedId];
	[item setTarget:self];
}

- (void)updateFeeds {
	while (endOfFeedIndex != indexOfPreviewFields)
		[GRMenu removeItemAtIndex:--endOfFeedIndex];
	for (Feed * f in feeds) {
		if (![oldFeeds containsObject:f]) // Growl help
			[newFeeds addObject:f];
		if ([[prefs valueForKey:@"minimalFunction"] boolValue])
			continue;
            NSString * trimmedTitleTag = [Utilities trimDownString:[Utilities flattenHTML:f.title] withMaxLenght:maxLettersInTitle];
		NSString * trimmedSourceTag = [Utilities trimDownString:[Utilities flattenHTML:f.source] withMaxLenght:maxLettersInSource];
		NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchLink:) keyEquivalent:@""];
		NSURL * iconURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://s2.googleusercontent.com/s2/favicons?alt=feed&domain=%@", [[NSURL URLWithString:f.link] host]]];
		f.icon = [[[NSImage alloc] initWithContentsOfURL:iconURL] autorelease];
		[item setImage:f.icon];
		[self setUpMainFeedItem:item withTitleTag:trimmedTitleTag sourceTag:trimmedSourceTag forFeed:f];
		[GRMenu insertItem:item atIndex:endOfFeedIndex++];
		NSMenuItem * itemCommand = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(doCommandActionFromMenu:) keyEquivalent:@""];
		[self setUpCommandFeedItem:itemCommand withSourceTag:trimmedSourceTag forFeed:f];
		[GRMenu insertItem:itemCommand atIndex:endOfFeedIndex++];
		NSMenuItem * itemShift = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(doShiftActionFromMenu:) keyEquivalent:@""];
		[self setUpShiftFeedItem:itemShift withSourceTag:trimmedSourceTag forFeed:f];
		[GRMenu insertItem:itemShift atIndex:endOfFeedIndex++];
		[item release];
		[itemCommand release];
		[itemShift release];
	}
}

- (void)updateNotifications {
	if (![feeds count]) {
		[statusItem setImage:nounreadItemsImage];
		[self displayMessage:NSLocalizedString(@"No unread items",nil)];
	} else {
		[statusItem setImage:unreadItemsImage];
		if ([newFeeds count]) { 
			[self announce]; // Growl
			if (![[prefs valueForKey:@"dontPlaySound"] boolValue]) // Sound notification
				[[NSSound soundNamed:@"beep.aiff"] play];
		}
		if ([[prefs valueForKey:@"minimalFunction"] boolValue] && moreUnreadExistInGRInterface)
			[self displayMessage:[NSString stringWithFormat:NSLocalizedString(@"More than %d unread items", nil), [feeds count]]];
	}
}

- (void)updateShowCount {
	if ([[prefs valueForKey:@"showCount"] boolValue] && totalUnreadCount) {
		[statusItem setLength:NSVariableStatusItemLength];
		[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d", totalUnreadCount]]];
	} else {
		[statusItem setAttributedTitle:[self makeAttributedStatusItemString:@""]];
		[statusItem setLength:ourStatusItemWithLength];
	}
	[self updateReadLabel];
}

- (void)updateReadLabel {
	if (totalUnreadCount) {
		[statusItem setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Unread Items: %d", nil), totalUnreadCount]];
		[self displayTopMessage:[NSString stringWithFormat:NSLocalizedString(@"%d Unread", nil), totalUnreadCount]];
	} else {
		[statusItem setToolTip:NSLocalizedString(@"No Unread Items", nil)];
		[self displayTopMessage:@""];
	}
}

#pragma mark -
#pragma mark Feeds accessing methods

- (Feed *)feedForIndex:(NSUInteger)index {
	Feed * result = nil;
	@synchronized(feeds) {
		result = [feeds objectAtIndex:index];
	}
	return result;
}

- (void)removeFeed:(Feed *)f {
	@synchronized(feeds) {
		[feeds removeObject:f];
	}
}

- (Feed *)findFeedWithId:(NSString *)feedId {
	Feed * result = nil;
	@synchronized(feeds) {
		for (Feed * f in feeds) {
			if ([f.feedId isEqualToString:feedId]) {
				result = f;
				break;
			}
		}
	}
	return result;
}

#pragma mark -
#pragma mark Display Message Methods

- (void)displayMessage:(NSString *)message {
	while (endOfFeedIndex != indexOfPreviewFields)
		[GRMenu removeItemAtIndex:--endOfFeedIndex];
	if (needToRemoveNormalButtons) {
		for (NSUInteger i = 0; i <= SEPARATOR2_NBO; i++)
			[GRMenu removeItemAtIndex:endOfFeedIndex];
		needToRemoveNormalButtons = NO;
	}
	[[GRMenu itemAtIndex:CHECKNOW_FF] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) andSmallText:message]];
}

- (void)displayLastTimeMessage:(NSString *)message {
	[[GRMenu itemAtIndex:CHECKNOW_FF] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) andSmallText:message]];
}

- (void)displayTopMessage:(NSString *)message {
	[[GRMenu itemAtIndex:READER_FF] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Go to Google Reader",nil) 
																					andSmallText:message]];
}

- (void)announce {
	if ([newFeeds count] > [[prefs stringForKey:@"maxNotifications"] integerValue]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"New Unread Items", nil)
									description:NSLocalizedString(@"Google Reader Notifier has found a number of new items.", nil)
							   notificationName:NSLocalizedString(@"New Unread Items", nil)
									   iconData:nil
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	} else {
		for (Feed * f in newFeeds) {
			[GrowlApplicationBridge notifyWithTitle:[Utilities flattenHTML:f.source] 
										description:[Utilities flattenHTML:f.title]
								   notificationName:NSLocalizedString(@"New Unread Items", nil)
										   iconData:[f.icon TIFFRepresentation]
										   priority:0
										   isSticky:NO
									   clickContext:[NSString stringWithString:f.feedId]];
		}
	}
	[newFeeds removeAllObjects];
}

#pragma mark -
#pragma mark Others

- (void)awakenFromSleep {
	[cookieHeader release];
	cookieHeader = nil;
	[NSThread sleepForTimeInterval:3.0];
	[self loginToGoogle];
}

- (void)displayAlertWithHeader:(NSString *)headerText andBody:(NSString *)bodyText {
	[NSApp activateIgnoringOtherApps:YES];		
	NSAlert * theAlert = [NSAlert alertWithMessageText:headerText
										 defaultButton:NSLocalizedString(@"Thanks",nil)
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:bodyText];
	
	[theAlert runModal];
}

- (void)errorImageOn {
	if ([[prefs valueForKey:@"showCount"] boolValue])
		[statusItem setAttributedTitle:[self makeAttributedStatusItemString:@""]];
	[statusItem setToolTip:NSLocalizedString(@"Failed to connect to Google Reader. Please try again.",nil)];
	[statusItem setAlternateImage:errorImage];
	[statusItem setImage:errorImage];
	//[cookieHeader release];
	//cookieHeader = nil;
}

- (NSString *)getLabel {
	if ([[prefs valueForKey:@"Label"] isEqualToString:@""])
		return @"state/com.google/reading-list";
	else
		return [NSString stringWithFormat:@"label/%@", [prefs valueForKey:@"Label"]];
}

- (NSString *)getURLPrefix {
	NSString * returnString = @"http";
	if ([[prefs valueForKey:@"alwaysUseHttps"] boolValue])
		returnString = @"https";
	return returnString;
}

- (NSString *)getUserPasswordFromKeychain {
	NSString * password = @"";
	if ([Keychain checkForExistanceOfKeychain] >= 1)
		password = [Keychain getPassword];
	return password;
}

- (NSAttributedString *)makeAttributedStatusItemString:(NSString *)text {
	CGFloat fontSize;
	if ([[prefs valueForKey:@"smallStatusItemFont"] boolValue])
		fontSize = 12.0;
	else
		fontSize = 14.0;
	NSArray * o = [NSArray arrayWithObjects:[NSFont fontWithName:@"Lucida Grande" size:fontSize], [NSNumber numberWithFloat:-0.0], nil];
	NSArray * k = [NSArray arrayWithObjects: NSFontAttributeName, NSBaselineOffsetAttributeName, nil];
	NSDictionary * statusAttrsDictionary = [NSDictionary dictionaryWithObjects:o forKeys:k];
	NSMutableAttributedString * newString = [[[NSMutableAttributedString alloc] initWithString:text attributes:statusAttrsDictionary] autorelease];
	return newString;
}

- (NSAttributedString *)makeAttributedMenuStringWithBigText:(NSString *)bigtext andSmallText:(NSString *)smalltext {
	bigtext = [Utilities flattenHTML:bigtext];
	NSMutableAttributedString * newString = [[[NSMutableAttributedString alloc] initWithString:bigtext attributes:normalAttrsDictionary] autorelease];
	if ([smalltext length] > 0) {
		smalltext = [Utilities flattenHTML:smalltext];
		NSAttributedString * smallString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" - %@", smalltext] 
																		   attributes:smallAttrsDictionary];
		[newString appendAttributedString:smallString];
		[smallString release];
	}
	return newString;
}

- (void)setupEventHandlers {
    // Register to receive the 'GURL''GURL' event
    NSAppleEventManager * manager = [NSAppleEventManager sharedAppleEventManager];
	if (manager)
		[manager setEventHandler:self andSelector:@selector(handleOpenLocationAppleEvent:withReplyEvent:) forEventClass:'GURL' andEventID:'GURL'];
}

- (void)handleOpenLocationAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply {
    // get the descriptor
    NSAppleEventDescriptor * directObjectDescriptor = [event paramDescriptorForKeyword:keyDirectObject];
    if (directObjectDescriptor) {
		// get the complete string
		NSString * urlString = [directObjectDescriptor stringValue];
		if (urlString) {
			NSScanner * scanner = [NSScanner scannerWithString:urlString];
			NSString * urlPrefix;
			[scanner scanUpToString:@":" intoString:&urlPrefix];
			[scanner scanString:@":" intoString:nil];
			if ([urlPrefix isEqualToString:@"feed"]) {
				NSString * feedScheme = nil;
				[scanner scanString:@"//" intoString:nil];
				[scanner scanString:@"http:" intoString:&feedScheme];
				[scanner scanString:@"https:" intoString:&feedScheme];
				[scanner scanString:@"//" intoString:nil];
				NSString * linkPath;
				[scanner scanUpToString:@"" intoString:&linkPath];
				if (!feedScheme)
					feedScheme = @"http:";
				linkPath = [NSString stringWithFormat:@"%@//%@", feedScheme, linkPath];
				if (linkPath)
					[self addFeed:linkPath];
				else
					[self displayAlertWithHeader:@"Error" andBody:@"The feed address seems to be malformed"];
			}
		}
	}
}

- (void)selectTorrentCastFolderEnded:(NSOpenPanel*)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSOKButton) {
		NSArray * paths = [panel filenames];
		NSEnumerator * iter = [paths objectEnumerator];
		NSString * path;
		while (path = [iter nextObject])
			torrentCastFolderPathString = path;
		[prefs setValue:torrentCastFolderPathString forKey:@"torrentCastFolderPath"];
		[torrentCastFolderPath setStringValue:[prefs valueForKey:@"torrentCastFolderPath"]];
	}
}

- (void)printStatus {
	DLog(@"FEEDS COUNT: %d", [feeds count]);
}

- (void)printFeeds {
	DLog(@"FEEDS: %@\n", [feeds description]);
}

@end
