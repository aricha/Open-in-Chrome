//
//  openInChrome.mm
//  openInChrome
//
//  Created by Andrew Richardson on 12-06-28.
//  Copyright (c) 2012. All rights reserved.
//

// CaptainHook by Ryan Petrich
// see https://github.com/rpetrich/CaptainHook/

#import <Foundation/Foundation.h>
#import <CaptainHook.h>
#import <UIKit/UIKit.h>
#import "OpenInChromeModel.h"

static NSString *const OCBundleID = @"com.arichardson.openInChrome";
static NSString *const kOCOpenInChromeEnabled = @"openInChromeEnabled";

static BOOL OCHookEnabled = YES;

static void OCUpdateSettings() {
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] persistentDomainForName:OCBundleID];
    
    NSNumber *enabled = [settings objectForKey:kOCOpenInChromeEnabled];
    if (enabled) {
        OCHookEnabled = [enabled boolValue];
    }
}

static void OCSettingsDidChangeNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSDictionary *settings = [[NSUserDefaults standardUserDefaults] persistentDomainForName:OCBundleID];
    
    NSNumber *enabled = [settings objectForKey:kOCOpenInChromeEnabled];
    if (enabled) {
        OCHookEnabled = [enabled boolValue];
    }
}

static BOOL OCShouldReplaceURLForApplication(SBApplication *app)
{
	if (!app) return YES;
	
	NSString *displayID = [app displayIdentifier];
	
	// only replace for Safari (or no specific app)
	return (!displayID || [displayID isEqualToString:@"com.apple.mobilesafari"]);
}

CHDeclareClass(SpringBoard)
CHDeclareClass(SBBookmarkIcon)
CHDeclareClass(SBApplicationController)

// iOS 5
CHOptimizedMethod5(super, void, SpringBoard, applicationOpenURL, NSURL *, url, publicURLsOnly, BOOL, publicOnly, animating, BOOL, animate, sender, id, sender, additionalActivationFlag, unsigned, flag)
{
	CHDebugLog(@"Opening URL %@ using iOS 5 method", url);
	
	if (OCHookEnabled && [OpenInChromeModel shouldHandleURL:url])
	{
		NSURL *replacedURL = [OpenInChromeModel formatURLForChrome:url];
		if (replacedURL)
			url = replacedURL;
	}
	
	CHSuper5(SpringBoard, applicationOpenURL, url, publicURLsOnly, publicOnly, animating, animate, sender, sender, additionalActivationFlag, flag);
}

CHOptimizedMethod0(super, void, SBBookmarkIcon, launch)
{
	if (OCHookEnabled) {
		NSURL *pageURL = [self webClip].pageURL;
		
		if (pageURL && [OpenInChromeModel shouldHandleURL:pageURL]) {
			NSURL *replacedURL = [OpenInChromeModel formatURLForChrome:pageURL];
			if (replacedURL) {
				[[UIApplication sharedApplication] openURL:replacedURL];
				return;
			}
		}
	}
	CHSuper0(SBBookmarkIcon, launch);
}

// iOS 6+
CHOptimizedMethod7(super, void, SpringBoard, applicationOpenURL, NSURL *, url, withApplication, SBApplication *, application, sender, id, sender, publicURLsOnly, BOOL, publicOnly, animating, BOOL, animating, needsPermission, BOOL, needsPermission, additionalActivationFlags, id, flags)
{
	CHDebugLog(@"Opening URL %@ with application %@ using iOS 6 method", url, application);
	
	if (OCHookEnabled && [OpenInChromeModel shouldHandleURL:url])
	{
		NSURL *replacedURL = [OpenInChromeModel formatURLForChrome:url];
		if (replacedURL) {
			url = replacedURL;
			
			if (OCShouldReplaceURLForApplication(application) && CHRespondsTo(self, displayIDForURLScheme:isPublic:)) {
				NSString *displayID = [self displayIDForURLScheme:ChromeSchemeHTTP isPublic:YES];
				if (displayID) {
					SBApplication *replacedApp = [[CHClass(SBApplicationController) sharedInstanceIfExists] applicationWithDisplayIdentifier:displayID];
					CHDebugLog(@"replacing app %@ with Chrome app %@ with displayID %@", application, replacedApp, displayID);
					application = replacedApp;
				}
			}
		}
	}
	
	CHSuper7(SpringBoard, applicationOpenURL, url, withApplication, application, sender, sender, publicURLsOnly, publicOnly, animating, animating, needsPermission, needsPermission, additionalActivationFlags, flags);
}

CHConstructor
{
    @autoreleasepool {
        CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(darwin, NULL, OCSettingsDidChangeNotificationCallback, CFSTR("com.arichardson.openInChrome.settingsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        
        OCUpdateSettings();
		
		CHLoadLateClass(SpringBoard);
		CHLoadLateClass(SBApplicationController);
		CHLoadLateClass(SBBookmarkIcon);
		
		CHHook5(SpringBoard, applicationOpenURL, publicURLsOnly, animating, sender, additionalActivationFlag); // iOS 5
		CHHook7(SpringBoard, applicationOpenURL, withApplication, sender, publicURLsOnly, animating, needsPermission, additionalActivationFlags); // iOS 6+
		CHHook0(SBBookmarkIcon, launch);
    }
}
