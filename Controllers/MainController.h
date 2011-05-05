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
//  MainController.h
//  GoogleReader
//
//  Created by Eli Dourado on 12/8/05.
//  Modified by Troels Bay (troelsbay@troelsbay.eu)
//	Modified by Mike Godenzi (godenzim@gmail.com) and Claudio Marforio (www.cloudgoessocial.net) on 5/20/10
//

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>
#import <IOKit/IOKitLib.h>
#import <Sparkle/Sparkle.h>
#import "IPMNetworkManagerDelegate.h"

@class IPMNetworkManager;
@class NetParam;
@class Feed;

@interface MainController : NSObject<GrowlApplicationBridgeDelegate, IPMNetworkManagerDelegate> {
    IBOutlet NSSecureTextField * passwordField;
    IBOutlet NSTextField * usernameField;
    IBOutlet NSTextField * addNewFeedUrlField;
	IBOutlet NSTextField * torrentCastFolderPath;
	IBOutlet NSMenu * GRMenu;
	IBOutlet NSWindow * preferences; //preference window
	IBOutlet NSWindow * addfeedwindow; //addfeed window
	IBOutlet SUUpdater * updater;
	IBOutlet NSTextField * versionLabel;
	
	NSTimer * lastCheckTimer;
	
	NSStatusItem * statusItem;
	NSUserDefaults * prefs;
	
	NSMutableArray * feeds;
	NSMutableArray * oldFeeds;
	NSMutableArray * newFeeds;
	NSDictionary * normalAttrsDictionary;
	NSDictionary * smallAttrsDictionary;
	NSDictionary * cookieHeader;

    NSSet * feedProxyHostNames;
    NSMutableDictionary * feedProxyHostNameCache;
	
	NSString * torrentCastFolderPathString;
	NSString * currentToken;
	
	NSImage * unreadItemsImage;
	NSImage * highlightedImage;
	NSImage * nounreadItemsImage;
	NSImage * errorImage;
	
	IPMNetworkManager * networkManager;
	
	BOOL isLeopard;
	BOOL moreUnreadExistInGRInterface;
	BOOL needToRemoveNormalButtons;
	BOOL isCheckingCredential;
	
	NSInteger totalUnreadCount;
	NSInteger lastCheckMinute;
	NSInteger endOfFeedIndex;
}

- (void)downloadFile:(NSString *)filename atUrl:(NSString *)url;
- (NSAttributedString *)makeAttributedStatusItemString:(NSString *)text;
- (NSAttributedString *)makeAttributedMenuStringWithBigText:(NSString *)bigtext andSmallText:(NSString *)smalltext;
- (void)addFeed:(NSString *)url;
- (void)displayAlertWithHeader:(NSString *)headerText andBody:(NSString *)bodyText;
- (void)displayMessage:(NSString *)message;
- (void)loginToGoogle;
- (void)getTokenFromGoogle;
- (void)getUnreadCountWithDeferredCall:(NetParam *)dc;
- (void)retrieveGoogleFeed;
- (void)updateMenu;
- (NSString *)getLabel;
- (void)errorImageOn;
- (NSString *)getURLPrefix;
- (void)announce;
- (NSString *)getUserPasswordFromKeychain;
- (void)growlNotificationWasClicked:(id)clickContext;
- (NSDictionary *)registrationDictionaryForGrowl;
- (void)setupEventHandlers;
- (void)handleOpenLocationAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply;
- (void)createLastCheckTimer;
- (void)displayLastTimeMessage:(NSString *)message;
- (void)displayTopMessage:(NSString *)message;
- (void)lastTimeCheckedTimer:(NSTimer *)timer;
- (void)selectTorrentCastFolderEnded:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)markOneAsRead:(Feed *)f;
- (void)markAllAsReadDeferred;
- (void)markOneAsStarred:(Feed *)f;
- (void)awakenFromSleep;


- (IBAction)launchSite:(id)sender;
- (IBAction)markAllAsRead:(id)sender;
- (IBAction)launchLink:(id)sender;
- (IBAction)doCommandActionFromMenu:(id)sender;
- (IBAction)doShiftActionFromMenu:(id)sender;
- (IBAction)launchErrorHelp:(id)sender;
- (IBAction)checkGoogleAuth:(id)sender;
- (IBAction)openPrefs:(id)sender;
- (IBAction)checkNow:(id)sender;
- (IBAction)openAddFeedWindow:(id)sender;
- (IBAction)addFeedFromUI:(id)sender;
- (IBAction)selectTorrentCastFolder:(id)sender;
- (IBAction)gitHubButtonPressed:(id)sender;
- (IBAction)blogButtonPressed:(id)sender;

@end
