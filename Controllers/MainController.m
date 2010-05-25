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

// 27 with special icons, 29 else
#define ourStatusItemWithLength 29
#define versionBuildNumber 110
#define indexOfPreviewFields 4
#define itemsExclPreviewFields 6
#define maxLettersInSummary 500
#define maxLettersInSource 20

@interface Delegate : NSObject {}
@end

@implementation Delegate
- (void) sound:(NSSound *)sound didFinishPlaying:(BOOL)aBool {}
@end

@interface MainController (PrivateMethods)
- (void)processLoginToGoogle:(NSString *)result;
- (void)processGoogleFeed:(NSData *)result;
- (void)processFailGoogleFeed:(NSError *)error;
- (void)processUnreadCount:(NSData *)result withDeferred:(NetParam *)dc;
- (void)processFailUnreadCount:(NSError *)error;
- (void)processDownloadFile:(NSString *)filename withData:(NSData *)result;
- (void)processTokenFromGoogle:(NSString *)result;
- (void)printStatus;
@end


@implementation MainController

#pragma mark MemoryManagement

- (id)init {
	[super init];
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
	
	// in earlier versions this was set to the actual user password, which we would want to override
	[prefs setObject:@"NotForYourEyes" forKey:@"Password"];
	
	normalAttrsDictionary = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:14.0], nil] forKeys:[NSArray arrayWithObjects: NSFontAttributeName, nil ]];
	smallAttrsDictionary = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:12.0], [NSColor grayColor], nil] forKeys:[NSArray arrayWithObjects: NSFontAttributeName, NSForegroundColorAttributeName, nil ]];

	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self 
		   selector:@selector(updateMenu)
			   name:@"PleaseUpdateMenu"
			 object:GRMenu];

	// we need this to know when the computer wakes from sleep
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(awakenFromSleep) name:NSWorkspaceDidWakeNotification object:nil];

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
	
	[[tempMenuSec insertItemWithTitle:NSLocalizedString(@"Go to Reader",nil) action:@selector(launchSite:) keyEquivalent:@"" atIndex:0] setTarget:self];
	[[tempMenuSec insertItemWithTitle:NSLocalizedString(@"Subscribe to Feed",nil) action:@selector(openAddFeedWindow:) keyEquivalent:@"" atIndex:1] setTarget:self];
	[[tempMenuSec insertItemWithTitle:NSLocalizedString(@"Check Now",nil) action:@selector(checkNow:) keyEquivalent:@"" atIndex:2] setTarget:self];	
	[[tempMenuSec itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) andSmallText:@""]];
	[tempMenuSec insertItem:[NSMenuItem separatorItem] atIndex:3];	
	[[tempMenuSec insertItemWithTitle:NSLocalizedString(@"Preferences...",nil) action:@selector(openPrefs:) keyEquivalent:@"" atIndex:4] setTarget:self];
	[[tempMenuSec itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) 
																				 andSmallText:NSLocalizedString(@"Updating...",nil)]];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Go to Reader",nil) action:@selector(launchSite:) keyEquivalent:@"" atIndex:0] setTarget:self];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Subscribe to Feed",nil) action:@selector(openAddFeedWindow:) keyEquivalent:@"" atIndex:1] setTarget:self];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Check Now",nil) action:@selector(checkNow:) keyEquivalent:@"" atIndex:2] setTarget:self];	
	[[GRMenu itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) andSmallText:@""]];
	[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:3];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Preferences...",nil) action:@selector(openPrefs:) keyEquivalent:@"" atIndex:4] setTarget:self];
	
	storedSID = @"";
	[self loginToGoogle];
	
	// Get the info dictionary (Info.plist)
    NSDictionary * infoDictionary;
	infoDictionary = [[NSBundle mainBundle] infoDictionary];
	
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
		[self displayAlertWithHeader:NSLocalizedString(@"Error",nil) 
							 andBody:NSLocalizedString(@"It seems you do not have a password in the Keychain. Please go to the preferences now and supply your password",nil)];
		[self errorImageOn];
		storedSID = @"";
	} else if ([[prefs valueForKey:@"Username"] isEqualToString:@""] || ![prefs valueForKey:@"Username"]) {
		[self displayAlertWithHeader:NSLocalizedString(@"Error",nil) 
							 andBody:NSLocalizedString(@"It seems you do not have a username filled in. Please go to the preferences now and supply your username",nil)];
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
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/accounts/SetSID?ssdc=1&sidt=%@&continue=http%%3A%%2F%%2Fgoogle.com%%2Freader%%2Fview%%2F", storedSID]]];
}

- (IBAction)openAllItems:(id)sender {
	currentlyFetchingAndUpdating = YES;
	[statusItem setMenu:tempMenuSec];
	NSUInteger j = 0;
	for (j = 0; j < [results count]; j++)
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[links objectAtIndex:[[results objectAtIndex:j] intValue]]]];	
	[self markResultsAsReadDetached];
}

- (IBAction)markAllAsRead:(id)sender {
	DLog(@"markAllAsRead begin");
	NetParam * np = [[NetParam alloc] initWithSuccess:@selector(markAllAsReadDetached) andFail:0 onTarget:self];
	[self getUnreadCountWithDeferredCall:np];
	[np release];
	//currentlyFetchingAndUpdating = YES;
	//[statusItem setMenu:tempMenuSec];
	//[self markAllAsReadDetached];
	DLog(@"markAllAsRead end");
}

- (IBAction)launchLink:(id)sender {
	DLog(@"launchLink begin");
	// Because we cannot be absolutely sure that the user has not clicked the GRMenu before a new update has occored 
	// (we make use of the id - and hopefully it will be an absolute). 
	if ([ids containsObject:[sender title]]) {
		currentlyFetchingAndUpdating = YES;
		[statusItem setMenu:tempMenuSec];
		if ([[prefs valueForKey:@"showCount"] boolValue])
			[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d",[results count]-1]]];
		NSUInteger index = [ids indexOfObjectIdenticalTo:[sender title]];
		DLog(@"Index is %d", index);
		DLog(@"NUMBER OF ITEMS IS, %d", [GRMenu numberOfItems]);
		if ([GRMenu numberOfItems] == 9) {
			[GRMenu removeItemAtIndex:index + indexOfPreviewFields];
			[GRMenu removeItemAtIndex:index + indexOfPreviewFields]; // the shaddow (optional-click
			[GRMenu removeItemAtIndex:index + indexOfPreviewFields]; // the space-line
		} else
			[GRMenu removeItemAtIndex:index + indexOfPreviewFields];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[links objectAtIndex:index]]];
		[self markOneAsReadDetached:[NSNumber numberWithInt:index]];
	} else
		DLog(@"Item has already gone away, so we cannot refetch it");
	DLog(@"launchLink end");	
}

- (IBAction)doOptionalActionFromMenu:(id)sender {
	currentlyFetchingAndUpdating = YES;
	[statusItem setMenu:tempMenuSec];
	// Because we cannot be absolutely sure that the user has not clicked the GRMenu before a new update has occored 
	// (we make use of the id - and hopefully it will be an absolute). 
	if ([ids containsObject:[sender title]]) {
		int index = [ids indexOfObjectIdenticalTo:[sender title]];
		if ([[prefs valueForKey:@"onOptionalActAlsoStarItem"] boolValue])
			[self markOneAsStarredDetached:[NSNumber numberWithInt:index]];
		else
			[self markOneAsReadDetached:[NSNumber numberWithInt:index]];
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
	if ([Keychain checkForExistanceOfKeychain] > 0)
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
	// This doesn't seem to work correctly
	while (currentlyFetchingAndUpdating) // TODO: get rid of this busy waiting...
		DLog(@"Growl click: We are currently updating and fetching... waiting");
	DLog(@"Growl click: Running...not waiting");
	currentlyFetchingAndUpdating == YES; // TODO: WTF is this? need to investigate more this method, as it is now seems like a big mess
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
	[statusItem setMenu:tempMenuSec];
	// in case we had an error before, clear the highlightedimage and displaymessage
	[statusItem setAlternateImage:highlightedImage];
	xmlError = [[[NSError alloc] init] autorelease];
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
		NetParam * np = [[NetParam alloc] initWithSuccess:@selector(processLoginToGoogle:) andFail:0 onTarget:self];
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
		NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@", 
						  [self getURLPrefix], feedstring, [ids objectAtIndex:index], currentToken];
		[networkManager sendPOSTNetworkRequest:url withBody:@"" withResponseType:NORESPONSE_NRT delegate:nil andParam:nil];
		[feedstring release];
		totalUnreadCount--;
		// at the end of this we will also remove the tempMenuSec and insert GRMenu
		[self removeOneItemFromMenu:index];
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
		NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@",
						  [self getURLPrefix],feedstring,[ids objectAtIndex:j],currentToken];
		[networkManager sendPOSTNetworkRequest:url withBody:@"" withResponseType:NORESPONSE_NRT delegate:nil andParam:nil];
		[feedstring release];
	}
	currentlyFetchingAndUpdating = NO;
	// the statusItem is actually still tempMenuSec, but it doesn't matter because It'll go back to GRMenu after the end of CheckNow
	[self checkNow:nil];
}

- (void)markAllAsReadDetached {
	currentlyFetchingAndUpdating = YES;
	[statusItem setMenu:tempMenuSec];
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
		[[NSNotificationCenter defaultCenter] postNotificationName:@"PleaseUpdateMenu" object:nil];
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

//updates the icon if necessary, updates the unread item
- (void)updateMenu {
	//[lastCheckTimer invalidate]; // TODO: not sure if this 3 lines are really needed, need to check in to it
	//[self createLastCheckTimer];
	//[lastCheckTimer fire];
	DLog(@"updateMenu begin");
	currentlyFetchingAndUpdating = YES;
	NSInteger n = [GRMenu numberOfItems];
	NSInteger v;
	for(v = itemsExclPreviewFields; v < n; v++)
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	// EXPERIMENTAL
	/// This is a feature in development!
	/// The automatical downloading of certain feeds
	// TORRENTCASTING
	if ([prefs boolForKey:@"EnableTorrentCastMode"]) {
		NSUInteger i = 0;		
		for(i = 0; i < [titles count]; i++) {
			if (![[torrentcastlinks objectAtIndex:i] isEqualToString:@""]) {
				NSFileManager * fm = [NSFileManager defaultManager];	
				if ([fm fileExistsAtPath:[prefs valueForKey:@"torrentCastFolderPath"]]) { 
					[self downloadFile:[NSString stringWithFormat:@"%@.torrent", [titles objectAtIndex:i]] atUrl:[torrentcastlinks objectAtIndex:i]];
					NSMutableString * feedstring = [[NSMutableString alloc] initWithString:[feeds objectAtIndex:i]];
					[feedstring replaceOccurrencesOfString:@"=" withString:@"-" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [feedstring length])];
					NSString * url = [NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@",
									  [self getURLPrefix], feedstring, [ids objectAtIndex:i], currentToken];
					[networkManager sendPOSTNetworkRequest:url withBody:@"" withResponseType:NORESPONSE_NRT delegate:nil andParam:nil];
					[feedstring release];
					if ([[prefs valueForKey:@"openTorrentAfterDownloading"] boolValue]) {
						DLog(@"%@", [NSString stringWithFormat:@"%@/%@", 
									 [prefs valueForKey:@"torrentCastFolderPath"], 
									 [NSString stringWithFormat:@"%@.torrent", [titles objectAtIndex:i]]]);
						[[NSWorkspace sharedWorkspace] openFile:[NSString stringWithFormat:@"%@/%@", [prefs valueForKey:@"torrentCastFolderPath"], [NSString stringWithFormat:@"%@.torrent", [titles objectAtIndex:i]]]];
					}
					[feeds removeObjectAtIndex:i];
					[ids removeObjectAtIndex:i];
					[links removeObjectAtIndex:i];
					[titles removeObjectAtIndex:i];
					[sources removeObjectAtIndex:i];
					[summaries removeObjectAtIndex:i];
					[torrentcastlinks removeObjectAtIndex:i];				
				} else {
					[self displayAlertWithHeader:NSLocalizedString(@"TorrentCast Error",nil) 
										 andBody:NSLocalizedString(@"Reader Notifier has found a new TorrentCast. However we are unable to download it because the folder you've specified does not exists. Please choose a new folder in the preferences. In addition, TorrentCasting has been disabled.",nil)];
					[prefs setValue:NO forKey:@"EnableTorrentCastMode"];
				}
			}
		}
	}
	NSUInteger c = 0;
	for(c = 0; c < [titles count]; c++)
		[results addObject:[NSString stringWithFormat:@"%d", c]];
	// if we have any items in the list, we should put a nice little bar between the normal buttons and the feeditems
	if ([results count] > 0 && ![[prefs valueForKey:@"minimalFunction"] boolValue])
		[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:3];
	if ([results count] > 0 && ![[prefs valueForKey:@"minimalFunction"] boolValue] && moreUnreadExistInGRInterface) {
		// we don't want to display the Mark all as read if there are more items in the Google Reader Interface
		// though we check if the users wants to override this
		if (![[prefs valueForKey:@"alwaysEnableMarkAllAsRead"] boolValue]) {			
			[GRMenu insertItemWithTitle:[NSString stringWithString:NSLocalizedString(@"More unread items exist",nil)] action:nil keyEquivalent:@"" atIndex:indexOfPreviewFields]; 
			[[GRMenu itemAtIndex:indexOfPreviewFields] setToolTip:NSLocalizedString(@"Mark all as read has been disabled",nil)];
		} else {
			[[GRMenu insertItemWithTitle:NSLocalizedString(@"Mark all as read",nil) action:@selector(markAllAsRead:) keyEquivalent:@"" atIndex:indexOfPreviewFields] setTarget:self];
			[[GRMenu itemAtIndex:indexOfPreviewFields] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Mark all as read",nil) 
																									   andSmallText:NSLocalizedString(@"Warning, items online will be marked read",nil)]];
			[[GRMenu itemAtIndex:indexOfPreviewFields] setToolTip:NSLocalizedString(@"There are more unread items online in the Google Reader interface. This function will cause Google Reader Notifier to mark all as read - whether or not they are visible in the menubar",nil)];
		}
		[[GRMenu insertItemWithTitle:NSLocalizedString(@"Open all items",nil) action:@selector(openAllItems:) keyEquivalent:@"" atIndex:indexOfPreviewFields] setTarget:self];
		[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:indexOfPreviewFields];
	} else if ([results count] > 0 && ![[prefs valueForKey:@"minimalFunction"] boolValue]) {
		[[GRMenu insertItemWithTitle:NSLocalizedString(@"Mark all as read",nil) action:@selector(markAllAsRead:) keyEquivalent:@"" atIndex:indexOfPreviewFields] setTarget:self]; 
		[[GRMenu insertItemWithTitle:NSLocalizedString(@"Open all items",nil) action:@selector(openAllItems:) keyEquivalent:@"" atIndex:indexOfPreviewFields] setTarget:self];
		[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:indexOfPreviewFields];
	}
	NSUInteger newCount = 0;
	NSUInteger currentIndexCount = indexOfPreviewFields;
	// we loop through the results count, but we cannot go above the maxItems, even though we always fetch one row more than max
	NSUInteger j;
	for (j = 0; j < [results count] && j < [[prefs valueForKey:@"maxItems"] intValue]; j++) {
		if (![[prefs valueForKey:@"minimalFunction"] boolValue]) {
			NSString * trimmedTitleTag = [[NSString alloc] initWithString:[Utilities trimDownString:[Utilities flattenHTML:[[titles objectAtIndex:j] stringValue]] withMaxLenght:60]];
			NSString * trimmedSourceTag = [[NSString alloc] initWithString:[Utilities trimDownString:[Utilities flattenHTML:[[sources objectAtIndex:j] stringValue]] withMaxLenght:maxLettersInSource]];
			NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchLink:) keyEquivalent:@""];
			[item setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag andSmallText:trimmedTitleTag]];
			if (![[prefs valueForKey:@"dontShowTooltips"] boolValue])
				[item setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Title: %@\nFeed: %@\nGoes to: %@%@",nil), [titles objectAtIndex:j], [[sources objectAtIndex:j] stringValue], [links objectAtIndex:j], [summaries objectAtIndex:j]]];
			[item setTitle:[ids objectAtIndex:j]];
			if ([[links objectAtIndex:j] length] > 0)
				[item setTarget:self];
			[item setKeyEquivalentModifierMask:0];			
			[GRMenu insertItem:item atIndex:currentIndexCount];
			// and then set the alternate 
			NSMenuItem * itemSecondary = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(doOptionalActionFromMenu:) keyEquivalent:@""];
			if ([[prefs valueForKey:@"onOptionalActAlsoStarItem"] boolValue])
				[itemSecondary setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag andSmallText:NSLocalizedString(@"Star item and mark as read",nil)]];
			else
				[itemSecondary setAttributedTitle:[self makeAttributedMenuStringWithBigText:trimmedSourceTag andSmallText:NSLocalizedString(@"Mark item as read",nil)]];
			[itemSecondary setKeyEquivalentModifierMask:NSCommandKeyMask];
			[itemSecondary setAlternate:YES];
			// even though setting the title twice seems like doing double work, we have to, because [sender title] will always be the last set title!
			[itemSecondary setTitle:[ids objectAtIndex:j]];
			if ([[links objectAtIndex:j] length] > 0)
				[itemSecondary setTarget:self];
			[GRMenu insertItem:itemSecondary atIndex:currentIndexCount + 1];
			[trimmedTitleTag release];
			[trimmedSourceTag release];
			[item release];
			[itemSecondary release];
		}
		if (![lastIds containsObject:[ids objectAtIndex:j]]){			
			// Growl help
			[newItems addObject:[results objectAtIndex:j]];
			newCount++;
		}
		currentIndexCount++;
		currentIndexCount++; // the extra one is because we add two menuitems now, one for command-tabbing
	}
	if (![results count])
		[statusItem setImage:nounreadItemsImage];
	else {
		[statusItem setImage:unreadItemsImage];
		if (newCount) // Growl
			[self announce];
		if (newCount && ![[prefs valueForKey:@"dontPlaySound"] boolValue]) {
			// Sound notification
			theSound = [NSSound soundNamed:@"beep.aiff"];
			[theSound play];
			[theSound release];
		}
		if (![results count])
			[self displayMessage:[NSString stringWithFormat:NSLocalizedString(@"No unread items",nil),[results count]]];
		else if ([results count] > 0 && [[prefs valueForKey:@"minimalFunction"] boolValue] && moreUnreadExistInGRInterface)
			[self displayMessage:[NSString stringWithFormat:NSLocalizedString(@"More than %d unread items",nil),[results count]]];
	}
	if ([[prefs valueForKey:@"showCount"] boolValue]) {
		if (moreUnreadExistInGRInterface) {
			[statusItem setLength:NSVariableStatusItemLength];
			[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d", totalUnreadCount]]];
		} else if ([results count] > 0) {
			[statusItem setLength:NSVariableStatusItemLength];			
			[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d", [results count]]]];
		} else {
			[statusItem setAttributedTitle:[self makeAttributedStatusItemString:@""]];
			[statusItem setLength:ourStatusItemWithLength];
		}
	} else
		[statusItem setLength:ourStatusItemWithLength];
	if (moreUnreadExistInGRInterface) {
		[statusItem setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Unread Items: %d",nil), totalUnreadCount]];
		[self displayTopMessage:[NSString stringWithFormat:NSLocalizedString(@"%d Unread",nil), totalUnreadCount]];
	} else if ([results count] > 0) {
		[statusItem setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Unread Items: %d",nil), [results count]]];
		[self displayTopMessage:[NSString stringWithFormat:NSLocalizedString(@"%d Unread",nil), [results count]]];
	} else {
		[statusItem setToolTip:NSLocalizedString(@"No Unread Items",nil)];
		[self displayTopMessage:@""];
	}
	NSUInteger v1 = 0;
	for(v1 = 0; v1 < [GRMenu numberOfItems]; v1++)
		[GRMenu itemChanged:[GRMenu itemAtIndex:v1]];
	[statusItem setMenu:GRMenu];
	currentlyFetchingAndUpdating = NO;
	DLog(@"updateMenu end");
	[self printStatus];
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
	if ([result isEqualToString:@""]) {
		storedSID = @""; // userSID = @"";
		[prefs setObject:@"" forKey:@"storedSID"];
		[self displayMessage:@"no Internet connection"];
		[self errorImageOn];
		[statusItem setMenu:GRMenu];
		[self createLastCheckTimer];
		[lastCheckTimer fire];		
	} else {
		NSScanner * theScanner;
		theScanner = [NSScanner scannerWithString:[NSString stringWithString:result]];
		if ([theScanner scanString:@"SID=" intoString:NULL] &&
			[theScanner scanUpToString:@"\nLSID=" intoString:&storedSID]) {
			storedSID = [NSString stringWithFormat:@"SID=%@;",storedSID];
			networkManager.sid = storedSID;
			[self setTimeDelay:[[prefs valueForKey:@"timeDelay"] integerValue]];
			[mainTimer fire];
			[self createLastCheckTimer];
			[lastCheckTimer fire];
		} else {
			if ([[self getUserPasswordFromKeychain] isEqualToString:@""]) {
				[self displayAlertWithHeader:NSLocalizedString(@"Error",nil) 
									 andBody:NSLocalizedString(@"It seems you do not have a password in the Keychain. Please go to the preferences now and supply your password",nil)];
				[self displayMessage:@"please enter login details"];
			} else if ([[prefs valueForKey:@"Username"] isEqualToString:@""] || ![prefs valueForKey:@"Username"]) {
				[self displayAlertWithHeader:NSLocalizedString(@"Error",nil) 
									 andBody:NSLocalizedString(@"It seems you do not have a username filled in. Please go to the preferences now and supply your username",nil)];
				[self displayMessage:@"please enter login details"];
			} else {
				[self displayAlertWithHeader:NSLocalizedString(@"Authentication error",nil) 
									 andBody:[NSString stringWithFormat:@"Reader Notifier could not handshake with Google. You probably have entered a wrong user or pass. The error supplied by Google servers was: %@", result]];
				[self displayMessage:@"wrong user or pass"];				
			}
			storedSID = @"";
			[self errorImageOn];
		}
		[prefs setObject:storedSID forKey:@"storedSID"];
	}
}

- (void)processGoogleFeed:(NSData *)result {
	NSXMLDocument * atomdoc = [[NSXMLDocument alloc] initWithData:result options:0 error:&xmlError];
	[titles addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/title/text()" error:NULL]];
	[sources addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/source/title/text()" error:NULL]];
	[ids addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/id/text()" error:NULL]];
	[feeds addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/source/@gr:stream-id" error:NULL]];
	[user addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/id/text()" error:NULL]];
	DLog(@"retrieveGoogleFeed 1");
	NSUInteger k = 0;
	for(k = 0; k < [titles count]; k++) {
		NSArray * tempArray0 = [atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/link[@rel='alternate']/@href",k+1] error:NULL];
		if([tempArray0 count] > 0)
			[links insertObject:[[tempArray0 objectAtIndex:0] stringValue] atIndex:k];
		else
			[links insertObject:@"" atIndex:k];
	}
	DLog(@"retrieveGoogleFeed 2");
	NSUInteger m = 0;
	for (m = 0; m < [titles count]; m++) {
		NSArray * tempArray2 = [atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/summary/text()", m + 1] error:NULL];
		if ([tempArray2 count] > 0)
			[summaries insertObject:[NSString stringWithFormat:@"\n\n%@", [Utilities flattenHTML:[Utilities trimDownString:[[tempArray2 objectAtIndex:0] stringValue] withMaxLenght:maxLettersInSummary]]] atIndex:m];
		else {
			NSArray * tempArray3 = [atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/content/text()", m + 1] error:NULL];
			if([tempArray3 count] > 0)
				[summaries insertObject:[NSString stringWithFormat:@"\n\n%@", [Utilities flattenHTML:[Utilities trimDownString:[[tempArray3 objectAtIndex:0] stringValue] withMaxLenght:maxLettersInSummary]]] atIndex:m];
			else
				[summaries insertObject:@"" atIndex:m];
		}
	}
	DLog(@"retrieveGoogleFeed 2a");
	// torrentcasting
	NSUInteger l;
	for (l = 0; l < [titles count]; l++) {
		NSArray * tempArray2 = [atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/link[@type='application/x-bittorrent']/@href", l + 1] 
												   error:NULL];
		if ([tempArray2 count] > 0)
			[torrentcastlinks insertObject:[[tempArray2 objectAtIndex:0] stringValue] atIndex:l];
		else
			[torrentcastlinks insertObject:@"" atIndex:l];
	}
	[atomdoc release];
	DLog(@"retrieveGoogleFeed 3");
	NSUInteger j;
	for(j = 0; j < [feeds count]; j++)
		[feeds replaceObjectAtIndex:j withObject:[[feeds objectAtIndex:j] stringValue]];
	DLog(@"retrieveGoogleFeed 4");
	NSUInteger d;
	for(d = 0; d < [ids count]; d++)
		[ids replaceObjectAtIndex:d withObject:[[ids objectAtIndex:d] stringValue]];
	DLog(@"retrieveGoogleFeed 5");
	if (!xmlError) {
		// We need to set the global whether there are (at least one) more unread items online in the google reader interface
		if ([titles count] > [[prefs valueForKey:@"maxItems"] intValue]) {
			moreUnreadExistInGRInterface = YES;
			// We also remove the last item, since we do not wish to display it anywhere, or fuck up the count
			//  note, we remove the first item, which is actually the oldest (we reversed the array earlier)
			//  ! we could actually skip all the maxItems checks later, but they're nice to have.
			/// UPDATE! We do not reverse it any longer! So now we just remove the last item
			DLog(@"retrieveGoogleFeed 6");
			if ([ids count] > 0) {
				[titles removeLastObject];
				[sources removeLastObject];
				[ids removeLastObject];
				[feeds removeLastObject];
				[links removeLastObject];
				[summaries removeLastObject];
				[torrentcastlinks removeLastObject];
			}
			DLog(@"retrieveGoogleFeed 7");
			[self getUnreadCountWithDeferredCall:nil];			
		} else
			moreUnreadExistInGRInterface = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"PleaseUpdateMenu" object:nil];
	}
	DLog(@"retrieveGoogleFeed end");
}

- (void)processFailGoogleFeed:(NSError *)error {
	[self errorImageOn]; 
	currentlyFetchingAndUpdating = NO;
	[lastCheckTimer invalidate];
	[self createLastCheckTimer];
	[lastCheckTimer fire];
	[statusItem setMenu:GRMenu];
}

- (void)processUnreadCount:(NSData *)result withDeferred:(NetParam *)dc {
	NSXMLDocument * atomdoc2 = [[NSXMLDocument alloc] initWithData:result options:0 error:&xmlError];
	NSString * xQuery;
	if ([[prefs valueForKey:@"Label"] isEqualToString:@""]) // if the user is on labels, use that to check instead!
		xQuery = @"for $x in /object/list/object where $x/string[contains(., 'reading-list')] return $x/number[@name=\"count\"]/text()";
	else {
		NSString * format = @"for $x in /object/list/object where $x/string[contains(., '/label/%@')] return $x/number[@name=\"count\"]/text()";
		xQuery = [NSString stringWithFormat:format, [prefs valueForKey:@"Label"]];
	}
	NSArray * tempArray5 = [atomdoc2 objectsForXQuery:xQuery error:NULL];
	NSInteger k = 0, t = 0;
	NSString * dString;
	for (k = 0; k < [tempArray5 count]; k++) {
		dString = [[tempArray5 objectAtIndex:k] stringValue];
		t += [dString integerValue];
	}
	totalUnreadCount = t;
	[atomdoc2 release];
	DLog(@"The total count of unread items is now %d", t);
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
	[statusItem setMenu:GRMenu];
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
	if (lastCheckMinute > [[prefs valueForKey:@"timeDelay"] integerValue]) {
		DLog(@"lastTimeChecked is more than it should be, so we run update");
		if (!currentlyFetchingAndUpdating)
			[self checkNow:nil];
	} else {
		DLog(@"lastTimeCheckedTimer run %d", lastCheckMinute);
		if (lastCheckMinute == 0)
			[self displayLastTimeMessage:[NSString stringWithString:NSLocalizedString(@"Checked less than 1 min ago",nil)]]; /* ok */
		else if (lastCheckMinute == 1)
			[self displayLastTimeMessage:[NSString stringWithString:NSLocalizedString(@"Checked 1 min ago",nil)]]; /* ok */
		else if (lastCheckMinute < 60)
			[self displayLastTimeMessage:[NSString stringWithFormat:NSLocalizedString(@"Checked %d min ago",nil), lastCheckMinute]];
		else {
			NSUInteger hours = lastCheckMinute / 60;
			[self displayLastTimeMessage:[NSString stringWithFormat:NSLocalizedString(@"Checked %d hour(s) ago",nil), hours]]; /* ok */
		}
		lastCheckMinute++;
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

- (void)removeNumberOfItemsFromMenubar:(NSInteger)number {
	NSInteger v;
	for(v = itemsExclPreviewFields; v < number; v++) {
		[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	}
}

- (void)clearMenuAndSetUpdatingState {
	NSInteger n = [GRMenu numberOfItems];
	NSInteger v;
	for(v = itemsExclPreviewFields; v < n; v++) {
		[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	}	
	[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:indexOfPreviewFields];
	[GRMenu insertItemWithTitle:NSLocalizedString(@"Updating...",nil) action:nil keyEquivalent:@"" atIndex:indexOfPreviewFields];
}

- (void)removeAllItemsFromMenubar {
	NSInteger n = [GRMenu numberOfItems];
	NSInteger v;
	for(v = itemsExclPreviewFields; v < n; v++) {
		[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	}
}

- (void)displayMessage:(NSString *)message {
	// clear out the previewField so that we can put a "No connection" error
	NSInteger a = [GRMenu numberOfItems], v = 0;
	for(v = itemsExclPreviewFields; v < a; v++) {
		[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	}
	// put in the message
	[[GRMenu itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) andSmallText:message]];
}

- (void)displayLastTimeMessage:(NSString *)message {
	[[GRMenu itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Check Now",nil) andSmallText:message]];
}

- (void)displayTopMessage:(NSString *)message {
	// put in the message
	[[GRMenu itemAtIndex:0] setAttributedTitle:[self makeAttributedMenuStringWithBigText:NSLocalizedString(@"Go to Reader",nil) andSmallText:message]];
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
							 andBody:NSLocalizedString(@"We cannot find your user, which is pretty strange. Report this if you are sure to be connected to the internet.",nil)];
	}
	return storedUserNo;
}

- (void)checkNowWithDelayDetached:(NSNumber *)delay {
	[NSThread sleepForTimeInterval:[delay floatValue]];
	[self checkNow:nil];
}

- (void)removeOneItemFromMenu:(NSInteger)index {
	DLog(@"removeOneItemFromMenu begin");
	[self printStatus];
	[lastIds setArray:ids];
	[results removeAllObjects];
	DLog(@"ids count %d >= index %d", [ids count], index);
	if ([ids count] > index 
		&& [feeds count] > index 
		&& [links count] > index 
		&& [titles count] > index 
		&& [sources count] > index 
		&& [summaries count] > index 
		&& [torrentcastlinks count] > index) {
		[feeds removeObjectAtIndex:index];
		[ids removeObjectAtIndex:index];
		[links removeObjectAtIndex:index];
		[titles removeObjectAtIndex:index];
		[sources removeObjectAtIndex:index];
		[summaries removeObjectAtIndex:index];
		[torrentcastlinks removeObjectAtIndex:index];
		[self printStatus];
		DLog(@"running updateMenu from removeOneItemFromMenu");
		[self updateMenu];
	} else
		DLog(@"Err. this and that did not match, we don't remove anything");
	DLog(@"removeOneItemFromMenu end");	
}

- (void)errorImageOn {
	if ([[prefs valueForKey:@"showCount"] boolValue])
		[statusItem setAttributedTitle:[self makeAttributedStatusItemString:@""]];
	[statusItem setToolTip:NSLocalizedString(@"Failed to connect to Google Reader. Please try again.",nil)];
	[statusItem setAlternateImage:errorImage];
	[statusItem setImage:errorImage];
	[statusItem setMenu:GRMenu];
	storedSID = @"";
}

- (NSString *)getLabel {
	if ([[prefs valueForKey:@"Label"] isEqualToString:@""])
		return @"state/com.google/reading-list";
	else
		return [NSString stringWithFormat:@"label/%@",[prefs valueForKey:@"Label"]];
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
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"New Unread Items",nil)
									description:NSLocalizedString(@"Google Reader Notifier has found a number of new items.",nil)
							   notificationName:NSLocalizedString(@"New Unread Items",nil)
									   iconData:nil
									   priority:0
									   isSticky:NO
								   clickContext:nil];
	} else {
		NSUInteger i;
		// we don't display the possible extra feed that we grab
		for (i = 0; i < [newItems count] && i < [[prefs valueForKey:@"maxItems"] intValue]; i++) {
			NSUInteger notifyindex = [results indexOfObjectIdenticalTo:[newItems objectAtIndex:i]];
			[GrowlApplicationBridge notifyWithTitle:[NSString stringWithFormat:@"%@",[Utilities flattenHTML:[[sources objectAtIndex:notifyindex] stringValue]]] 
										description:[NSString stringWithFormat:@"%@",[Utilities flattenHTML:[[titles objectAtIndex:notifyindex] stringValue]]]
								   notificationName:NSLocalizedString(@"New Unread Items",nil)
										   iconData:nil
										   priority:0
										   isSticky:NO
									   clickContext:[NSString stringWithString:[ids objectAtIndex:notifyindex]]];
		}
	}
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
		[prefs setValue:[NSString stringWithString:torrentCastFolderPathString] forKey:@"torrentCastFolderPath"];
		[torrentCastFolderPath setStringValue:[prefs valueForKey:@"torrentCastFolderPath"]];
	}
	[panel release];
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
