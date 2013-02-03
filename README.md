## Reader Notifier Reloaded

*Reader Notifier Reloaded* is a simple Mac app that stays on your menu bar, and checks your feeds on [Google Reader](http://www.google.com/reader/) to display notifications for new items.
It is very useful if you can't afford the time to regularly check new items in your subscriptions, but still want to discover interesting items as you work on other things.
It requires a Mac with relatively modern OS X (>= 10.6), and for notification, it bundles [Growl](http://growl.info) and supports [Notification Center](http://www.apple.com/osx/whats-new/#notification-center) on Mountain Lion (10.8).

<img src="https://raw.github.com/netj/readernotifier/master/README.files/readernotifier-screenshot.png"  alt="Screen Shot of Reader Notifier Reloaded's Menubar Item">

<img src="https://raw.github.com/netj/readernotifier/master/README.files/readernotifier-screenshot2.png" alt="Screen Shot of Reader Notifier Reloaded's Menu">

It is currently maintained by [Jaeho Shin](http://github.com/netj) with very slim resource.
Please [donate](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=Jaeho%2eShin%40Gmail%2ecom&lc=US&item_name=Reader%20Notifier%20Reloaded%20development%20support&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donate_LG%2egif%3aNonHosted) if you enjoy and find the app useful, active development might happen more often with your support.

### Installation

1. <big>**Download the [latest version](http://j.mp/ReaderNotifierDownload)**</big>.
2. Install the app by moving the extracted app to your Applications folder.
3. Latest OS X may refuse to open the app because it's not signed.  In that case, Control-click (or tap with two fingers, or click with the right button) and choose *Open* from the menu.

If you need an older version, check the [list of all previous versions](http://j.mp/ReaderNotifierAllVersions).

### Some background

Reader Notifier was originally created by [Troels Bay](http://troelsbay.eu/), forked by [canbuffi](http://github.com/canbuffi), and then reborn as Reader Notifier Reloaded by [Mike Godenzi](https://github.com/godenzim) and Claudio Marforio.  Jaeho Shin added favicon support, Korean localization, and some minor tweaks.

This is Jaeho's fork of [godenzi's Reader Notifier Reloaded](https://github.com/godenzim/readernotifier) to easily publish bug fixes and new features.  Like the original it is released under GPL.

----

*Here are the original FAQs from [Troels Bay's site](http://troelsbay.eu/software/reader):*

## Reader Notifier

**Reader Notifier** aims to supplement the official Mac Notifier menubar plugins for OS X, in adding support for Google Reader. **Reader Notifier** tells you when you have new unread rss/feed items available, and lets you visit those feeds without ever going to the Google Reader interface.

### Disclaimer and other information

This software is open source under the GPL license. It basically means that you can do whatever you like with the source code, but you have to keep it open source, and released under GPL if you redistribute it.
If this piece of software somehow breaks your computer, I cannot be held responsible. However, it is highly doubtful that it could ever do any harm apart from crashing itself in a worst case scenario. 

### Troubleshooting

One user has noted that upon new releases, he sometimes had to erase the preference file to avoid crashes. I still haven't located this bug, but please report back if you have the same issue. Preference file is located at ~/Library/Preferences/com.bay.ReaderNotifier.plist

### Q&A

Reader Notifier is provided as is. It should be fairly easy to understand the application and as such it does not need a help file. However, this section is for things perhaps not so obvious for the ordinary user:

* I want to be able to choose more than one label to look for! Well yes, while that is a mighty fine idea, Reader Notifier is made with the philosophy of as little post-processing as possible (to keep your computer clean of unnecessary CPU-cycles). So as long as Google does not have the option of viewing several labels at a single time in the Google Reader interface, it will not be a feature of Reader Notifier either. However, as a workaround, you can just make a new label and add it to all the feeds you want Reader Notifier to check. It is indeed possible for one single feed to have multiple labels.
* I want Reader Notifier to startup automatically! Okay then, you should go to System Preferences > Accounts > Login Items, and then drag the Application icon into the list.
* I want to disable growl notifictions! Go to System Preferences -> Growl, and uncheck the box at Reader Notifier. Expect never to be bothered again.
* I want - insert something here - to be implemented! Well that's probably a nice idea, but I won't know until you let me know! Why not use the comment function below?.

### Please help if you can

If you are of a creative nature, and want to make new menubar icons (or enhance the existing once) please send me suggestions! Especially the BW image displayed when no unread items exists is a bit rough. 
