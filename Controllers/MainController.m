//
//  MainController.m
//  Reader Notifier
//
//

#import "MainController.h"
#import "Keychain.h"
#import "IPMNetworkManager.h"
#import "NetParam.h"
#import "Utilities.h"

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
#define itemsExclPreviewFields 7
#define maxLettersInSummary 500
#define maxLettersInSource 20

@interface MainController (PrivateMethods)
- (void)processLoginToGoogle:(NSString *)result;
- (void)processFailLoginToGoogle:(NSError *)error;
- (void)processGoogleFeed:(NSData *)result;
- (void)processFailGoogleFeed:(NSError *)error;
- (void)processUnreadCount:(NSData *)result withDeferred:(NetParam *)dc;
- (void)processFailUnreadCount:(NSError *)error;
- (void)processDownloadFile:(NSString *)filename withData:(NSData *)result;
- (void)processTokenFromGoogle:(NSString *)result;
- (void)printStatus;
- (void)setUpMarkAllAsRead;
- (void)downloadAndManageTorrentFileForIndex:(NSUInteger)i;
- (void)updateTorrentCasting;
- (void)updateNormalButtons;
- (void)updateFeeds;
- (void)updateNotifications;
- (void)updateShowCount;
- (void)updateReadLabel;
- (void)fillResultsIfNeeded;
- (void)parseFeeds:(NSXMLDocument *)atomdoc;
- (void)parseIds:(NSXMLDocument *)atomdoc;
- (void)parseLinks:(NSXMLDocument *)atomdoc;
- (void)parseSummaries:(NSXMLDocument *)atomdoc;
- (void)parseTorrentCastLinks:(NSXMLDocument *)atomdoc;
- (void)parseUnreadCount:(NSXMLDocument *)atomdoc;
- (void)setUpMainFeedItem:(NSMenuItem *)item withTitleTag:(NSString *)trimmedTitleTag sourceTag:(NSString *)trimmedSourceTag andIndex:(NSUInteger)i;
- (void)setUpAlternateFeedItem:(NSMenuItem *)item withSourceTag:(NSString *)trimmedSourceTag andIndex:(NSUInteger)i;
@end

@implementation MainController

#pragma mark MemoryManagement

- (id)init {
	if (self = [super init]) {
		[self setupEventHandlers];
		NSMutableDictionary * defaultPrefs = [NSMutableDictionary dictionary];
		[defaultPrefs setObject:@"20" forKey:@"maxItems"];
		[defaultPrefs setObject:@"10" forKey:@"timeDelay"];
		[defaultPrefs setObject:@"" forKey:@"Label"];
		[defaultPrefs setObject:@"5" forKey:@"maxNotifications"];
		[defaultPrefs setObject:@"NO" forKey:@"EnableTorrentCastMode"];
		prefs = [[NSUserDefaults standardUserDefaults] retain];
		[prefs registerDefaults:defaultPrefs];	
		networkManager = [[IPMNetworkManager alloc] init];
		currentToken = nil;
		endOfFeedIndex = indexOfPreviewFields;
		needToRemoveNormalButtons = NO;
		// in earlier versions this was set to the actual user password, which we would want to override
		[prefs setObject:@"NotForYourEyes" forKey:@"Password"];
		NSArray * o = [NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:14.0], nil];
		NSArray * k = [NSArray arrayWithObjects: NSFontAttributeName, nil];
		normalAttrsDictionary = [[NSDictionary alloc] initWithObjects:o 
															  forKeys:k];
		o = [NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:12.0], [NSColor grayColor], nil];
		k = [NSArray arrayWithObjects: NSFontAttributeName, NSForegroundColorAttributeName, nil];
		smallAttrsDictionary = [[NSDictionary alloc] initWithObjects:o 
															 forKeys:k];
		// we need this to know when the computer wakes from sleep
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(awakenFromSleep) name:NSWorkspaceDidWakeNotification object:nil];
	}
	return self;
}

- (void)dealloc {
    [statusItem release];
    [mainTimer invalidate];
    [mainTimer release];
	[lastCheckTimer invalidate];
	[lastCheckTimer release];
	[prefs release];
	[networkManager release];
	[currentToken release];
	[nounreadItemsImage release];
	[unreadItemsImage release];
	[errorImage release];
	[highlightedImage release];
	[user release];
	[titles release];
	[links release];
	[results release];
	[lastIds release];
	[feeds release];
	[ids release];
	[sources release];
	[newItems release];
	[summaries release];
	[torrentcastlinks release];
    [super dealloc];
}

- (void)awakeFromNib {
	[NSApp activateIgnoringOtherApps:YES];
	// Get system version
	NSDictionary * dict = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	NSString * versionString = [dict objectForKey:@"ProductVersion"];
	NSArray * array = [versionString componentsSeparatedByString:@"."];
	NSUInteger count = [array count];
	NSInteger major = (count >= 1) ? [[array objectAtIndex:0] integerValue] : 0;
	NSInteger minor = (count >= 2) ? [[array objectAtIndex:1] integerValue] : 0;
	if (major > 10 || major == 10 && minor >= 5)
		isLeopard = YES;
	else
		isLeopard = NO;
	// Growl
	[GrowlApplicationBridge setGrowlDelegate:self];
	[prefs setObject:@"" forKey:@"storedSID"];
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
	
	user = [[NSMutableArray alloc] init];
	titles = [[NSMutableArray alloc] init];
	links = [[NSMutableArray alloc] init];
	results = [[NSMutableArray alloc] init];
	lastIds = [[NSMutableArray alloc] init];
	feeds = [[NSMutableArray alloc] init];
	ids = [[NSMutableArray alloc] init];
	sources = [[NSMutableArray alloc] init];
	newItems = [[NSMutableArray alloc] init];
	summaries = [[NSMutableArray alloc] init];
	torrentcastlinks = [[NSMutableArray alloc] init];
	lastCheckMinute = 0;
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Go to Reader",nil) 
						  action:@selector(launchSite:) 
				   keyEquivalent:@"" atIndex:READER_FF] setTarget:self];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Subscribe to Feed",nil) 
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
	storedSID = @"";
	[self loginToGoogle];
	// Get the info dictionary (Info.plist)
    NSDictionary * infoDictionary = [[NSBundle mainBundle] infoDictionary];
	DLog(@"Hello. %@ Build %@", [infoDictionary objectForKey:@"CFBundleName"], [infoDictionary objectForKey:@"CFBundleVersion"]);
	if ([prefs valueForKey:@"torrentCastFolderPath"])
		[torrentCastFolderPath setStringValue:[prefs valueForKey:@"torrentCastFolderPath"]];
	DLog(@"We're on %@", [[NSProcessInfo processInfo] operatingSystemVersionString]);
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)checkNow:(id)sender {	
	// first we check if the user has put in a password and username beforehand
	if ([[self getUserPasswordFromKeychain] isEqualToString:@""]) {
		[self displayAlertWithHeader:NSLocalizedString(@"Error", nil) 
							 andBody:NSLocalizedString(@"It seems you do not have a password in the Keychain. "
													   @"Please go to the preferences now and supply your password", nil)];
		[self errorImageOn];
		storedSID = @"";
	} else if ([[prefs valueForKey:@"Username"] isEqualToString:@""] || ![prefs valueForKey:@"Username"]) {
		[self displayAlertWithHeader:NSLocalizedString(@"Error",nil) 
							 andBody:NSLocalizedString(@"It seems you do not have a username filled in. "
													   @"Please go to the preferences now and supply your username", nil)];
		[self errorImageOn];
		storedSID = @"";
	} else {
		// then we make sure it has validated and provided us with a login
		if (![[self loginToGoogle] isEqualToString:@""]) {
			// then we make sure that it's not already running
			if (!currentlyFetchingAndUpdating) {
				// threading
				[self setTimeDelay:[[prefs valueForKey:@"timeDelay"] integerValue]];
				[self createLastCheckTimer];
				[lastCheckTimer fire];
				[self retrieveGoogleFeed];
			}
		}
	}
}

- (IBAction)launchSite:(id)sender {
	NSString * format = @"https://www.google.com/accounts/SetSID?ssdc=1&sidt=%@&continue=http%%3A%%2F%%2Fgoogle.com%%2Freader%%2Fview%%2F";
	NSString * url = [NSString stringWithFormat:format, storedSID];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

- (IBAction)openAllItems:(id)sender {
	currentlyFetchingAndUpdating = YES;
	NSUInteger j = 0;
	for (j = 0; j < [results count]; j++)
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[links objectAtIndex:[[results objectAtIndex:j] integerValue]]]];	
	[self markResultsAsReadDetached];
}

- (IBAction)markAllAsRead:(id)sender {
	DLog(@"markAllAsRead begin");
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(markAllAsReadDetached) andFail:0 onTarget:self];
	[self getUnreadCountWithDeferredCall:np];
	[np release];
	DLog(@"markAllAsRead end");
}

- (IBAction)launchLink:(id)sender {
	DLog(@"launchLink begin");
	// Because we cannot be absolutely sure that the user has not clicked the GRMenu before a new update has occored 
	// (we make use of the id - and hopefully it will be an absolute). 
	if ([ids containsObject:[sender title]]) {
		currentlyFetchingAndUpdating = YES;
		if ([[prefs valueForKey:@"showCount"] boolValue])
			[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d",[results count]-1]]];
		NSUInteger index = [ids indexOfObjectIdenticalTo:[sender title]];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[links objectAtIndex:index]]];
		[self markOneAsReadDetached:[NSNumber numberWithInt:index]];
	} else
		DLog(@"Item has already gone away, so we cannot refetch it");
	DLog(@"launchLink end");	
}

- (IBAction)doOptionalActionFromMenu:(id)sender {
	currentlyFetchingAndUpdating = YES;
	// Because we cannot be absolutely sure that the user has not clicked the GRMenu before a new update has occored 
	// (we make use of the id - and hopefully it will be an absolute). 
	if ([ids containsObject:[sender title]]) {
		NSUInteger index = [ids indexOfObjectIdenticalTo:[sender title]];
		NSNumber * indexNumber = [NSNumber numberWithUnsignedInteger:index];
		if ([[prefs valueForKey:@"onOptionalActAlsoStarItem"] boolValue])
			[self markOneAsStarredDetached:indexNumber];
		else
			[self markOneAsReadDetached:indexNumber];
	} else {
		currentlyFetchingAndUpdating = NO;
		DLog(@"Item has already gone away, so we cannot refetch it");
	}
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
	storedSID = @"";
	[prefs setObject:[NSString stringWithString:[usernameField stringValue]] forKey:@"Username"];
	NSString * password = [passwordField stringValue];
	if ([Keychain checkForExistanceOfKeychain])
		[Keychain modifyKeychainItem:password];
	else
		[Keychain addKeychainItem:password];
	if (![[self loginToGoogle] isEqualToString:@""]) {
		[self displayAlertWithHeader:NSLocalizedString(@"Success",nil) andBody:NSLocalizedString(@"You are now connected to Google",nil)];
		[mainTimer invalidate];
		[self setTimeDelay:[[prefs valueForKey:@"timeDelay"] integerValue]];
		[mainTimer fire];
	} else
		[self displayAlertWithHeader:NSLocalizedString(@"Error",nil) andBody:NSLocalizedString(@"Unable to connect to Google with user details",nil)];
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
	if ([ids containsObject:clickContext])
		[self launchLink:[GRMenu itemWithTitle:clickContext]];
	else
		DLog(@"User clicked on growl, item already went away");
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
	DLog(@"Unread count method initiated with dc:%@", [dc description]);
	// since .99 this has provided a memory error (case of Moore).
	// we've tried to fix it with releasing atomdoc2 and temparray5 (and not releasing dstring)
	// http://www.google.com/reader/api/0/unread-count?all=true&autorefresh=true&output=json&ck=1165697710220&client=scroll
	NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/unread-count?all=true&autorefresh=true&output=xml&client=scroll", 
					  [self getURLPrefix]];
	NetParam * np;
	if (dc)
		np = [[NetParam alloc] initWithSuccess:@selector(processUnreadCount:withDeferred:) fail:@selector(processFailUnreadCount:) andSecondParam:dc onTarget:self];
	else
		np = [[NetParam alloc] initWithSuccess:@selector(processUnreadCount:withDeferred:) andFail:@selector(processFailUnreadCount:) onTarget:self];
	[networkManager retrieveDataAtUrl:url withDelegate:self andParam:np];
	[np release];
}

- (void)retrieveGoogleFeed {
	DLog(@"retrieveGoogleFeed begin");
	currentlyFetchingAndUpdating = YES;
	// in case we had an error before, clear the highlightedimage and displaymessage
	[statusItem setAlternateImage:highlightedImage];
	[lastIds setArray:ids];
	[results removeAllObjects];
	[titles removeAllObjects];
	[sources removeAllObjects];
	[links removeAllObjects];
	[feeds removeAllObjects];
	[ids removeAllObjects];
	[newItems removeAllObjects];
	[summaries removeAllObjects];
	[torrentcastlinks removeAllObjects];
	[user removeAllObjects]; // if this is not done, we cannot be sure that a user will get a new userNo on re-entering login details
	/* new */
	NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/atom/user/-/%@?r=d&xt=user/-/state/com.google/read&n=%d&output=json",
					  [self getURLPrefix], [self getLabel], [[prefs valueForKey:@"maxItems"] intValue] + 1];
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(processGoogleFeed:) andFail:@selector(processFailGoogleFeed:) onTarget:self];
	[networkManager retrieveDataAtUrl:url withDelegate:self andParam:np];
	[np release];
}

- (void)downloadFile:(NSString *)filename atUrl:(NSString *)url {
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(processDownloadFile:withData:) fail:0 andSecondParam:filename onTarget:self];
	[networkManager retrieveDataAtUrl:url withDelegate:self andParam:np];
	[np release];
}

- (NSString *)loginToGoogle {
	NSString * result = [prefs valueForKey:@"storedSID"];
	if ([result isEqualToString:@""]) {
		NSString * p1 = [self usernameForAuthenticationChallengeWithParam:nil];
		NSString * p2 = [self passwordForAuthenticationChallengeWithParam:nil];
		NSString * params = [NSString stringWithFormat:@"Email=%@&Passwd=%@&service=cl&source=TroelsBay-ReaderNotifier-build%d", p1, p2, versionBuildNumber];
		NetParam * np = [[NetParam alloc] initWithSuccess:@selector(processLoginToGoogle:) andFail:@selector(processFailLoginToGoogle:) onTarget:self];
		[networkManager sendPOSTNetworkRequest:@"https://www.google.com/accounts/ClientLogin" 
									  withBody:params 
							  withResponseType:NSSTRING_NRT 
									  delegate:self 
									  andParam:np];
		[np release];
	}
	return result;
}

- (void)getTokenFromGoogle {
	NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/token", [self getURLPrefix]];
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(processTokenFromGoogle:) andFail:0 onTarget:self];
	[networkManager retrieveStringAtUrl:url withDelegate:self andParam:np];
}

- (void)markOneAsStarredDetached:(NSNumber *)aNumber {
	NSInteger index = [aNumber integerValue];
	NSString * feedstring = [[feeds objectAtIndex:index] stringByReplacingOccurrencesOfString:@":" withString:@"%3A"];
	feedstring = [feedstring stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
	feedstring = [feedstring stringByReplacingOccurrencesOfString:@"=" withString:@"-"];
	NSString * idsstring = [[ids objectAtIndex:index] stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
	idsstring = [idsstring stringByReplacingOccurrencesOfString:@"," withString:@"%2C"];
	idsstring = [idsstring stringByReplacingOccurrencesOfString:@":" withString:@"%2A"];
	NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?client=scroll", [self getURLPrefix]];
	NSString * body = [NSString stringWithFormat:@"s=%@&i=%@&ac=edit-tags&a=user%%2F%@%%2Fstate%%2Fcom.google%%2Fstarred&T=%@", 
					   feedstring, idsstring, [self grabUserNo], currentToken];
	[networkManager sendPOSTNetworkRequest:url withBody:body withResponseType:NORESPONSE_NRT delegate:nil andParam:nil];
	[self markOneAsReadDetached:[NSNumber numberWithInt:index]];
}

- (void)markOneAsReadDetached:(NSNumber *)aNumber {
	DLog(@"markOneAsReadDetatched begin");
	NSInteger index = [aNumber integerValue];
	if ([feeds count] > index) {
		// we replace all instances of = to %3D for google
		NSMutableString * feedstring = [[NSMutableString alloc] initWithString:[feeds objectAtIndex:index]];
		[feedstring replaceOccurrencesOfString:@"=" withString:@"-" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [feedstring length])];
		NSString * format = @"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/"
							@"-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@";
		NSString * url = [NSString stringWithFormat:format, [self getURLPrefix], feedstring, [ids objectAtIndex:index], currentToken];
		[networkManager sendPOSTNetworkRequest:url withBody:@"" withResponseType:NORESPONSE_NRT delegate:nil andParam:nil];
		[feedstring release];
		totalUnreadCount--;
		[self removeOneFeedFromMenu:index];
	} else
		DLog(@"markOneAsReadDetatched - there was not enough items in feeds or ids array");
	currentlyFetchingAndUpdating = NO;
	DLog(@"markOneAsReadDetatched end");
}

- (void)markResultsAsReadDetached {
	NSUInteger j = 0;
	for (j = 0; j < [results count]; j++) {
		NSMutableString * feedstring = [[NSMutableString alloc] initWithString:[feeds objectAtIndex:j]];
		[feedstring replaceOccurrencesOfString:@"=" withString:@"-" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [feedstring length])];
		NSString * format = @"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/"
							@"-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@";
		NSString * url = [NSString stringWithFormat:format, [self getURLPrefix],feedstring,[ids objectAtIndex:j],currentToken];
		[networkManager sendPOSTNetworkRequest:url withBody:@"" withResponseType:NORESPONSE_NRT delegate:nil andParam:nil];
		[feedstring release];
	}
	currentlyFetchingAndUpdating = NO;
	[self checkNow:nil];
}

- (void)markAllAsReadDetached {
	currentlyFetchingAndUpdating = YES;
	if (totalUnreadCount == [results count] || [[prefs valueForKey:@"alwaysEnableMarkAllAsRead"] boolValue]) {
		NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/mark-all-as-read?client=scroll", [self getURLPrefix]];
		NSString * replacedLabel = [[self getLabel] stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
		NSString * body = [NSString stringWithFormat:@"s=user%%2F%@%%2F%@&T=%@", 
						   [self grabUserNo], replacedLabel, currentToken];
		[networkManager sendPOSTNetworkRequest:url withBody:body withResponseType:NORESPONSE_NRT delegate:nil andParam:nil];
		[lastIds setArray:ids];
		[results removeAllObjects];
		[feeds removeAllObjects];
		[ids removeAllObjects];
		[links removeAllObjects];
		[titles removeAllObjects];
		[sources removeAllObjects];
		totalUnreadCount = 0;
		[self updateMenu];
	} else {
		if (totalUnreadCount != -1) {
			[self displayAlertWithHeader:NSLocalizedString(@"Warning",nil) 
								 andBody:NSLocalizedString(@"There are new unread items available online. Mark all as read has been canceled.",nil)];
			[self retrieveGoogleFeed];
			DLog(@"Error marking all as read");
		}
	}
}

- (void)addFeed:(NSString *)url {
	NSString * sanitizedUrl = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	if (![[prefs valueForKey:@"dontVerifySubscription"] boolValue]) {
		NSString * completeUrl = [NSString stringWithFormat:@"%@://www.google.com/reader/preview/*/feed/%@", [self getURLPrefix], sanitizedUrl];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:completeUrl]];
	} else {
		// Here we should implement a check if there actually is no feed there :(
		NSURL * posturl = [NSURL URLWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/quickadd", [self getURLPrefix]]];
		NSMutableURLRequest * postread = [NSMutableURLRequest requestWithURL:posturl];
		[postread setTimeoutInterval:5.0];
		NSString * sendString = [NSString stringWithFormat:@"quickadd=%@&T=%@", sanitizedUrl, currentToken];
		[networkManager sendPOSTNetworkRequest:sendString withBody:@"" withResponseType:NORESPONSE_NRT delegate:nil andParam:nil];
		// we need to sleep a little
		[NSThread sleepForTimeInterval:1.5];
		[self checkNow:nil];
	}
}

#pragma mark -
#pragma mark IPMNetworkManagerDelegate methods

- (void)networkManagerDidReceiveNSStringResponse:(NSString *)response withParam:(id<NSObject>)param {
	DLog(@"RECEIVED NSSTRING");
	NetParam * nParam = (NetParam *)param;
	[nParam invokeSuccessWithFirstParam:response];
}

- (void)networkManagerDidReceiveNSDataResponse:(NSData *)response withParam:(id<NSObject>)param {
	DLog(@"RECEIVED NSDATA");
	NetParam * nParam = (NetParam *)param;
	[nParam invokeSuccessWithFirstParam:response];
}

- (void)networkManagerDidNotReceiveResponse:(NSError *)error withParam:(id<NSObject>)param {
	DLog(@"NETWORK ERROR");
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
	NSScanner * theScanner;
	theScanner = [NSScanner scannerWithString:[NSString stringWithString:result]];
	if ([theScanner scanString:@"SID=" intoString:NULL] 
		&& [theScanner scanUpToString:@"\nLSID=" intoString:&storedSID]) {
		storedSID = [NSString stringWithFormat:@"SID=%@;",storedSID];
		networkManager.sid = storedSID;
		[self setTimeDelay:[[prefs valueForKey:@"timeDelay"] integerValue]];
		[mainTimer fire];
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
		storedSID = @"";
		[self errorImageOn];
	}
	[prefs setObject:storedSID forKey:@"storedSID"];
}

- (void)processFailLoginToGoogle:(NSError *)error {
	storedSID = @"";
	[prefs setObject:@"" forKey:@"storedSID"];
	[self displayMessage:@"no Internet connection"];
	[self errorImageOn];
	[self createLastCheckTimer];
	[lastCheckTimer fire];
}

- (void)processGoogleFeed:(NSData *)result {
	DLog(@"retrieveGoogleFeed begin");
	NSError * xmlError = nil;
	NSXMLDocument * atomdoc = [[NSXMLDocument alloc] initWithData:result options:0 error:&xmlError];
	if (!xmlError) {
		[titles addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/title/text()" error:NULL]];
		[sources addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/source/title/text()" error:NULL]];
		[self parseIds:atomdoc];
		[self parseFeeds:atomdoc];
		[user addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/id/text()" error:NULL]];
		[self parseLinks:atomdoc];
		[self parseSummaries:atomdoc];
		[self parseTorrentCastLinks:atomdoc];
		if ([titles count] > [[prefs valueForKey:@"maxItems"] intValue]) {
			moreUnreadExistInGRInterface = YES;
			if ([ids count] > 0) {
				[titles removeLastObject];
				[sources removeLastObject];
				[ids removeLastObject];
				[feeds removeLastObject];
				[links removeLastObject];
				[summaries removeLastObject];
				[torrentcastlinks removeLastObject];
			}
		} else
			moreUnreadExistInGRInterface = NO;
		[self updateMenu];
		[self getUnreadCountWithDeferredCall:nil];
	}
	[atomdoc release];
	DLog(@"retrieveGoogleFeed end");
}

- (void)processFailGoogleFeed:(NSError *)error {
	[self errorImageOn]; 
	currentlyFetchingAndUpdating = NO;
	[lastCheckTimer invalidate];
	[self createLastCheckTimer];
	[lastCheckTimer fire];
}

- (void)processUnreadCount:(NSData *)result withDeferred:(NetParam *)dc {
	NSXMLDocument * atomdoc = [[NSXMLDocument alloc] initWithData:result options:0 error:NULL];
	[self parseUnreadCount:atomdoc];
	[atomdoc release];
	DLog(@"The total count of unread items is now %d", totalUnreadCount);
	[self updateShowCount];
	if (dc)
		[dc invokeSuccessWithFirstParam:nil];
}

- (void)processFailUnreadCount:(NSError *)error {
	totalUnreadCount = -1;
	[self errorImageOn]; 
	currentlyFetchingAndUpdating = NO;
	[lastCheckTimer invalidate];
	[self createLastCheckTimer];
	[lastCheckTimer fire];
}

- (void)processDownloadFile:(NSString *)filename withData:(NSData *)result {
	[result writeToFile:[NSString stringWithFormat:@"%@/%@", [prefs valueForKey:@"torrentCastFolderPath"], filename] atomically:YES];
}

- (void)processTokenFromGoogle:(NSString *)result {
	if (currentToken)
		[currentToken release];
	currentToken = [result retain];
}

#pragma mark -
#pragma mark Parsing Methods

- (void)parseFeeds:(NSXMLDocument *)atomdoc {
	[feeds addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/source/@gr:stream-id" error:NULL]];
	NSUInteger i;
	for(i = 0; i < [feeds count]; i++)
		[feeds replaceObjectAtIndex:i withObject:[[feeds objectAtIndex:i] stringValue]];
}

- (void)parseIds:(NSXMLDocument *)atomdoc {
	[ids addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/id/text()" error:NULL]];
	NSUInteger i;
	for(i = 0; i < [ids count]; i++)
		[ids replaceObjectAtIndex:i withObject:[[ids objectAtIndex:i] stringValue]];
}

- (void)parseLinks:(NSXMLDocument *)atomdoc {
	NSUInteger i;
	for(i = 0; i < [titles count]; i++) {
		NSArray * tmp = [atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/link[@rel='alternate']/@href", i + 1] error:NULL];
		if([tmp count] > 0)
			[links insertObject:[[tmp objectAtIndex:0] stringValue] atIndex:i];
		else
			[links insertObject:@"" atIndex:i];
	}
}

- (void)parseSummaries:(NSXMLDocument *)atomdoc {
	NSUInteger i = 0;
	for (i = 0; i < [titles count]; i++) {
		NSArray * tmp = [atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/summary/text()", i + 1] error:NULL];
		if ([tmp count] > 0) {
			NSString * flattenString = [Utilities flattenHTML:[Utilities trimDownString:[[tmp objectAtIndex:0] stringValue] 
																		  withMaxLenght:maxLettersInSummary]];
			[summaries insertObject:[NSString stringWithFormat:@"\n\n%@", flattenString] atIndex:i];
		} else {
			tmp = [atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/content/text()", i + 1] error:NULL];
			if([tmp count] > 0) {
				NSString * flattenString = [Utilities flattenHTML:[Utilities trimDownString:[[tmp objectAtIndex:0] stringValue] 
																			  withMaxLenght:maxLettersInSummary]];
				[summaries insertObject:[NSString stringWithFormat:@"\n\n%@", flattenString] atIndex:i];	
			} else
				[summaries insertObject:@"" atIndex:i];
		}
	}
}

- (void)parseTorrentCastLinks:(NSXMLDocument *)atomdoc {
	// torrentcasting
	NSUInteger i;
	for (i = 0; i < [titles count]; i++) {
		NSString * xQuery = [NSString stringWithFormat:@"/feed/entry[%d]/link[@type='application/x-bittorrent']/@href", i + 1];
		NSArray * tmp = [atomdoc objectsForXQuery:xQuery error:NULL];
		if ([tmp count])
			[torrentcastlinks insertObject:[[tmp objectAtIndex:0] stringValue] atIndex:i];
		else
			[torrentcastlinks insertObject:@"" atIndex:i];
	}
}

- (void)parseUnreadCount:(NSXMLDocument *)atomdoc {
	NSString * xQuery = @"for $x in /object/list/object where $x/string[contains(., 'reading-list')] return $x/number[@name=\"count\"]/text()";;
	if (![[prefs valueForKey:@"Label"] isEqualToString:@""]) {
		NSString * format = @"for $x in /object/list/object where $x/string[contains(., '/label/%@')] return $x/number[@name=\"count\"]/text()";
		xQuery = [NSString stringWithFormat:format, [prefs valueForKey:@"Label"]];
	}
	NSArray * tmp = [atomdoc objectsForXQuery:xQuery error:NULL];
	NSInteger i, t = 0;
	for (i = 0; i < [tmp count]; i++)
		t += [[[tmp objectAtIndex:i] stringValue] integerValue];
	totalUnreadCount = t;
}

#pragma mark -
#pragma mark Timers

- (void)createLastCheckTimer {
	lastCheckMinute = 0;
	if (lastCheckTimer) {
		[lastCheckTimer invalidate];
		[lastCheckTimer release];
	}
	lastCheckTimer = [[NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(lastTimeCheckedTimer:) userInfo:nil repeats:YES] retain];
}

//creates a timer with a user-specified delay, fires the timer
- (void)setTimeDelay:(NSInteger)x {
	if (mainTimer) {
		[mainTimer invalidate];
		[mainTimer release];
	}
    mainTimer = [[NSTimer scheduledTimerWithTimeInterval:(60 * x) target:self selector:@selector(timer:) userInfo:nil repeats:YES] retain];
}

- (void)timer:(NSTimer *)timer {	
	if (!currentlyFetchingAndUpdating && ![[self loginToGoogle] isEqualToString:@""])
		[self retrieveGoogleFeed];
}

- (void)lastTimeCheckedTimer:(NSTimer *)timer {
	[self getTokenFromGoogle];
	if (lastCheckMinute > [[prefs valueForKey:@"timeDelay"] integerValue] && !currentlyFetchingAndUpdating) {
		[self checkNow:nil];
	} else {
		DLog(@"lastTimeCheckedTimer run %d", lastCheckMinute);
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
	DLog(@"updateMenu begin");
	currentlyFetchingAndUpdating = YES;
	[self updateTorrentCasting];
	[self updateNormalButtons];
	[self updateFeeds];
	[self updateNotifications];
	[self updateShowCount];
	[self updateReadLabel];
	currentlyFetchingAndUpdating = NO;
	DLog(@"updateMenu end");
	[self printStatus];
}

- (void)fillResultsIfNeeded {
	if ([results count])
		return;
	NSUInteger c;
	for(c = 0; c < [titles count]; c++)
		[results addObject:[NSString stringWithFormat:@"%d", c]];
}

- (void)downloadAndManageTorrentFileForIndex:(NSUInteger)i {
	[self downloadFile:[NSString stringWithFormat:@"%@.torrent", [titles objectAtIndex:i]] atUrl:[torrentcastlinks objectAtIndex:i]];
	NSMutableString * feedstring = [[NSMutableString alloc] initWithString:[feeds objectAtIndex:i]];
	[feedstring replaceOccurrencesOfString:@"=" withString:@"-" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [feedstring length])];
	NSString * format = @"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/"
						@"-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@";
	NSString * url = [NSString stringWithFormat:format, [self getURLPrefix], feedstring, [ids objectAtIndex:i], currentToken];
	[networkManager sendPOSTNetworkRequest:url withBody:@"" withResponseType:NORESPONSE_NRT delegate:nil andParam:nil];
	[feedstring release];
	if ([[prefs valueForKey:@"openTorrentAfterDownloading"] boolValue]) {
		NSString * filePath = [NSString stringWithFormat:@"%@/%@", 
							   [prefs valueForKey:@"torrentCastFolderPath"], [NSString stringWithFormat:@"%@.torrent", [titles objectAtIndex:i]]];
		[[NSWorkspace sharedWorkspace] openFile:filePath];
	}
	[feeds removeObjectAtIndex:i];
	[ids removeObjectAtIndex:i];
	[links removeObjectAtIndex:i];
	[titles removeObjectAtIndex:i];
	[sources removeObjectAtIndex:i];
	[summaries removeObjectAtIndex:i];
	[torrentcastlinks removeObjectAtIndex:i];
}

- (void)updateTorrentCasting {
	// EXPERIMENTAL
	/// This is a feature in development!
	/// The automatical downloading of certain feeds
	// TORRENTCASTING
	if ([prefs boolForKey:@"EnableTorrentCastMode"]) {
		NSUInteger i = 0;		
		for (i = 0; i < [titles count]; i++) {
			if ([[torrentcastlinks objectAtIndex:i] isEqualToString:@""])
				continue;
			NSFileManager * fm = [NSFileManager defaultManager];	
			if ([fm fileExistsAtPath:[prefs valueForKey:@"torrentCastFolderPath"]])
				[self downloadAndManageTorrentFileForIndex:i];
			else {
				[self displayAlertWithHeader:NSLocalizedString(@"TorrentCast Error",nil) 
									 andBody:NSLocalizedString(@"Reader Notifier has found a new TorrentCast. "
															   @"However we are unable to download it because the folder you've specified does not exists. "
															   @"Please choose a new folder in the preferences. "
															   @"In addition, TorrentCasting has been disabled.", nil)];
				[prefs setValue:NO forKey:@"EnableTorrentCastMode"];
			}
		}
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
	[self fillResultsIfNeeded];
	if ([results count] && ![[prefs valueForKey:@"minimalFunction"] boolValue]) {
		if (needToRemoveNormalButtons) {
			NSUInteger i;
			for (i = 0; i <= SEPARATOR2_NBO; i++)
				[GRMenu removeItemAtIndex:endOfFeedIndex];
		}
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

- (void)setUpMainFeedItem:(NSMenuItem *)item withTitleTag:(NSString *)trimmedTitleTag sourceTag:(NSString *)trimmedSourceTag andIndex:(NSUInteger)i {
	[item setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag andSmallText:trimmedTitleTag]];
	if (![[prefs valueForKey:@"dontShowTooltips"] boolValue])
		[item setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Title: %@\nFeed: %@\nGoes to: %@%@", nil), 
						  [titles objectAtIndex:i], [[sources objectAtIndex:i] stringValue], [links objectAtIndex:i], [summaries objectAtIndex:i]]];
	[item setTitle:[ids objectAtIndex:i]];
	if ([[links objectAtIndex:i] length])
		[item setTarget:self];
	[item setKeyEquivalentModifierMask:0];
}

- (void)setUpAlternateFeedItem:(NSMenuItem *)item withSourceTag:(NSString *)trimmedSourceTag andIndex:(NSUInteger)i {
	if ([[prefs valueForKey:@"onOptionalActAlsoStarItem"] boolValue])
		[item setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag 
																	   andSmallText:NSLocalizedString(@"Star item and mark as read", nil)]];
	else
		[item setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag 
																	   andSmallText:NSLocalizedString(@"Mark item as read", nil)]];
	[item setKeyEquivalentModifierMask:NSCommandKeyMask];
	[item setAlternate:YES];
	// even though setting the title twice seems like doing double work, we have to, because [sender title] will always be the last set title!
	[item setTitle:[ids objectAtIndex:i]];
	if ([[links objectAtIndex:i] length])
		[item setTarget:self];
}

- (void)updateFeeds {
	NSUInteger i;
	[self fillResultsIfNeeded];
	while (endOfFeedIndex != indexOfPreviewFields)
		[GRMenu removeItemAtIndex:--endOfFeedIndex];
	// we loop through the results count, but we cannot go above the maxItems, even though we always fetch one row more than max
	for (i = 0; i < [results count] && i < [[prefs valueForKey:@"maxItems"] intValue]; i++) {
		if (![lastIds containsObject:[ids objectAtIndex:i]]) // Growl help
			[newItems addObject:[results objectAtIndex:i]];
		if ([[prefs valueForKey:@"minimalFunction"] boolValue])
			continue;
		NSString * trimmedTitleTag = [Utilities trimDownString:[Utilities flattenHTML:[[titles objectAtIndex:i] stringValue]] withMaxLenght:60];
		NSString * trimmedSourceTag = [Utilities trimDownString:[Utilities flattenHTML:[[sources objectAtIndex:i] stringValue]] 
												  withMaxLenght:maxLettersInSource];
		NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchLink:) keyEquivalent:@""];
		[self setUpMainFeedItem:item withTitleTag:trimmedTitleTag sourceTag:trimmedSourceTag andIndex:i];
		[GRMenu insertItem:item atIndex:endOfFeedIndex++];
		NSMenuItem * itemAlternate = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(doOptionalActionFromMenu:) keyEquivalent:@""];
		[self setUpAlternateFeedItem:itemAlternate withSourceTag:trimmedSourceTag andIndex:i];
		[GRMenu insertItem:itemAlternate atIndex:endOfFeedIndex++];
		[item release];
		[itemAlternate release];
	}
}

- (void)updateNotifications {
	[self fillResultsIfNeeded];
	if (![results count]) {
		[statusItem setImage:nounreadItemsImage];
		[self displayMessage:NSLocalizedString(@"No unread items",nil)];
	} else {
		[statusItem setImage:unreadItemsImage];
		if ([newItems count]) { 
			[self announce]; // Growl
			if (![[prefs valueForKey:@"dontPlaySound"] boolValue]) {
				// Sound notification
				theSound = [NSSound soundNamed:@"beep.aiff"];
				[theSound play];
				[theSound release];
			}
		}
		if ([[prefs valueForKey:@"minimalFunction"] boolValue] && moreUnreadExistInGRInterface)
			[self displayMessage:[NSString stringWithFormat:NSLocalizedString(@"More than %d unread items", nil), [results count]]];
	}
}

- (void)updateShowCount {
	DLog(@"SHOW COUNT: %d", totalUnreadCount);
	if ([[prefs valueForKey:@"showCount"] boolValue]) {
		[statusItem setLength:NSVariableStatusItemLength];
		[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d", totalUnreadCount]]];
	} else
		[statusItem setLength:ourStatusItemWithLength];
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
#pragma mark Others

- (void)awakenFromSleep {
	DLog(@"AWAKEN FROM SLEEP");
	[prefs setValue:@"" forKey:@"storedSID"];
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

- (void)displayMessage:(NSString *)message {
	// clear out the previewField so that we can put a "No connection" error
	NSInteger n = [GRMenu numberOfItems];
	NSInteger v;
	for(v = itemsExclPreviewFields; v < n; v++) {
		[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	}
	[[GRMenu itemAtIndex:CHECKNOW_FF] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) andSmallText:message]];
}

- (void)displayLastTimeMessage:(NSString *)message {
	[[GRMenu itemAtIndex:CHECKNOW_FF] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) andSmallText:message]];
}

- (void)displayTopMessage:(NSString *)message {
	[[GRMenu itemAtIndex:READER_FF] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Go to Reader",nil) andSmallText:message]];
}

- (NSString *)grabUserNo {
	NSString * storedUserNo;
	NSScanner * theScanner = [NSScanner scannerWithString:[[user objectAtIndex:0] stringValue]];
	if (![theScanner scanString:@"tag:google.com,2005:reader/user/" intoString:NULL] 
		|| ![theScanner scanUpToString:@"/" intoString:&storedUserNo]) {
		storedUserNo = @"";
		DLog(@"Something wrong with the userNo retrieval");
		[self displayMessage:@"no user on server"];
		[self displayAlertWithHeader:NSLocalizedString(@"No user", nil) 
							 andBody:NSLocalizedString(@"We cannot find your user, which is pretty strange. "
													   @"Report this if you are sure to be connected to the internet.", nil)];
	}
	return storedUserNo;
}

- (void)checkNowWithDelayDetached:(NSNumber *)delay {
	[NSThread sleepForTimeInterval:[delay floatValue]];
	[self checkNow:nil];
}

- (void)removeOneFeedFromMenu:(NSInteger)index {
	DLog(@"removeOneFeedFromMenu begin");
	[self printStatus];
	[lastIds setArray:ids];
	[results removeAllObjects];
	if (index < [ids count]
		&& index < [feeds count]
		&& index < [links count]
		&& index < [titles count]
		&& index < [sources count]
		&& index < [summaries count]
		&& index < [torrentcastlinks count]) {
		[feeds removeObjectAtIndex:index];
		[ids removeObjectAtIndex:index];
		[links removeObjectAtIndex:index];
		[titles removeObjectAtIndex:index];
		[sources removeObjectAtIndex:index];
		[summaries removeObjectAtIndex:index];
		[torrentcastlinks removeObjectAtIndex:index];
		[self printStatus];
		[self updateMenu];
	} else
		DLog(@"Err. this and that did not match, we don't remove anything");
	DLog(@"removeOneFeedFromMenu end");	
}

- (void)errorImageOn {
	if ([[prefs valueForKey:@"showCount"] boolValue])
		[statusItem setAttributedTitle:[self makeAttributedStatusItemString:@""]];
	[statusItem setToolTip:NSLocalizedString(@"Failed to connect to Google Reader. Please try again.",nil)];
	[statusItem setAlternateImage:errorImage];
	[statusItem setImage:errorImage];
	storedSID = @"";
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

- (void)announce {
	if ([newItems count] > [[prefs stringForKey:@"maxNotifications"] integerValue]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"New Unread Items", nil)
									description:NSLocalizedString(@"Google Reader Notifier has found a number of new items.", nil)
							   notificationName:NSLocalizedString(@"New Unread Items", nil)
									   iconData:nil
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	} else {
		NSUInteger i;
		// we don't display the possible extra feed that we grab
		for (i = 0; i < [newItems count] && i < [[prefs valueForKey:@"maxItems"] intValue]; i++) {
			NSUInteger notifyindex = [results indexOfObjectIdenticalTo:[newItems objectAtIndex:i]];
			[GrowlApplicationBridge notifyWithTitle:[Utilities flattenHTML:[[sources objectAtIndex:notifyindex] stringValue]] 
										description:[Utilities flattenHTML:[[titles objectAtIndex:notifyindex] stringValue]]
								   notificationName:NSLocalizedString(@"New Unread Items", nil)
										   iconData:nil
										   priority:0
										   isSticky:NO
									   clickContext:[NSString stringWithString:[ids objectAtIndex:notifyindex]]];
		}
	}
	[newItems removeAllObjects];
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
		DLog(@"TorrentCast folder selected: %@", torrentCastFolderPathString);		
		[prefs setValue:torrentCastFolderPathString forKey:@"torrentCastFolderPath"];
		[torrentCastFolderPath setStringValue:[prefs valueForKey:@"torrentCastFolderPath"]];
	}
}

- (void)printStatus {
	DLog(@"feeds count: %d", [feeds count]);
	DLog(@"ids count: %d", [ids count]);
	DLog(@"links count: %d", [links count]);
	DLog(@"titles count: %d", [titles count]);
	DLog(@"sources count: %d", [sources count]);
	DLog(@"summaries count: %d", [summaries count]);
	DLog(@"torrentcastlinks count: %d", [torrentcastlinks count]);
}

@end
