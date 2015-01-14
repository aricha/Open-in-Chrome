//
//  openInChrome.m
//  openInChrome
//
//  Created by Andrew Richardson on 12-06-28.
//  Copyright (c) 2012. All rights reserved.
//

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
	OCUpdateSettings();
}

static BOOL OCShouldReplaceURLForApplication(SBApplication *app)
{
	if (!app) return YES;

    NSString *bundleID = @"";
    if (CHRespondsTo(app, bundleIdentifier)) {
        bundleID = [app bundleIdentifier];
    } else if (CHRespondsTo(app, displayIdentifier)) {
        bundleID = [app displayIdentifier];
    }

	// only replace for Safari (or no specific app)
	return (!bundleID || [bundleID isEqualToString:@"com.apple.mobilesafari"]);
}

CHDeclareClass(SpringBoard)
CHDeclareClass(SBBookmarkIcon)
CHDeclareClass(SBApplicationController)
CHDeclareClass(SBBookmark)

static BOOL HandleApplicationOpenURL(SpringBoard *self, NSURL **urlRef, SBApplication **applicationRef)
{
    if (!urlRef)
        return NO;
    
    BOOL handled = NO;
    if (OCHookEnabled && [OpenInChromeModel shouldHandleURL:*urlRef])
	{
		NSURL *replacedURL = [OpenInChromeModel formatURLForChrome:*urlRef];
		if (replacedURL) {
			*urlRef = replacedURL;
            handled = YES;
        }
        
        if (handled && applicationRef && OCShouldReplaceURLForApplication(*applicationRef) && CHRespondsTo(self, displayIDForURLScheme:isPublic:)) {
            NSString *displayID = [self displayIDForURLScheme:ChromeSchemeHTTP isPublic:YES];
            if (displayID) {
                SBApplication *replacedApp = nil;

                SBApplicationController *appController = [CHClass(SBApplicationController) sharedInstanceIfExists];
                if (CHRespondsTo(appController, applicationWithBundleIdentifier:)) {
                    // TODO: Does any translation from display ID -> bundle ID need to be done?
                    replacedApp = [appController applicationWithBundleIdentifier:displayID];
                } else if (CHRespondsTo(appController, applicationWithDisplayIdentifier:)) {
                    replacedApp = [appController applicationWithDisplayIdentifier:displayID];
                }

                if (replacedApp) {
                    CHDebugLog(@"replacing app %@ with Chrome app %@ with displayID %@", *applicationRef, replacedApp, displayID);
                    *applicationRef = replacedApp;
                }
            }
        }
	}
    return handled;
}

// iOS 5
CHOptimizedMethod5(self, void, SpringBoard, applicationOpenURL, NSURL *, url, publicURLsOnly, BOOL, publicOnly, animating, BOOL, animate, sender, id, sender, additionalActivationFlag, unsigned, flag)
{
	CHDebugLog(@"Opening URL %@ using iOS 5 method", url);
	
	HandleApplicationOpenURL(self, &url, NULL);
	
	CHSuper5(SpringBoard, applicationOpenURL, url, publicURLsOnly, publicOnly, animating, animate, sender, sender, additionalActivationFlag, flag);
}

// iOS 6
CHOptimizedMethod7(self, void, SpringBoard, applicationOpenURL, NSURL *, url, withApplication, SBApplication *, application, sender, id, sender, publicURLsOnly, BOOL, publicOnly, animating, BOOL, animating, needsPermission, BOOL, needsPermission, additionalActivationFlags, id, flags)
{
	CHDebugLog(@"Opening URL %@ with application %@ using iOS 6 method", url, application);
	
	HandleApplicationOpenURL(self, &url, &application);
    
	CHSuper7(SpringBoard, applicationOpenURL, url, withApplication, application, sender, sender, publicURLsOnly, publicOnly, animating, animating, needsPermission, needsPermission, additionalActivationFlags, flags);
}

static BOOL HandleApplicationOpenURLWithReentrantGuard(SpringBoard *self, NSURL **urlRef, id *applicationRef) {
    // SpringBoard appears to be doing some setup prior to calling this method that is application-specific,
    // so changing the app from within this method causes a nasty hang. Rather than try and recreate that setup,
    // just set up a new openURL stack instead and suppress hooking behaviour to avoid the risk of an infinite loop.
    static BOOL suppressed = NO;
    BOOL handled = NO;
    if (!suppressed && (handled = HandleApplicationOpenURL(self, urlRef, applicationRef))) {
        suppressed = YES;
        if (CHRespondsTo(self, applicationOpenURL:)) {
            [self applicationOpenURL:*urlRef];
        } else if (CHRespondsTo(self, applicationOpenURL:publicURLsOnly:)) {
            [self applicationOpenURL:*urlRef publicURLsOnly:NO];
        }
        suppressed = NO;
    }
    return handled;
}

// iOS 7.0.x
CHOptimizedMethod8(self, void, SpringBoard, applicationOpenURL, NSURL *, url, withApplication, SBApplication *, application, sender, id, sender, publicURLsOnly, BOOL, publicOnly, animating, BOOL, animating, needsPermission, BOOL, needsPermission, additionalActivationFlags, id, flags, activationHandler, id, activationHandler)
{
    CHDebugLog(@"Opening URL %@ with application %@ using iOS 7.0 method", url, application);
    
    if (!HandleApplicationOpenURLWithReentrantGuard(self, &url, &application)) {
        CHSuper8(SpringBoard, applicationOpenURL, url, withApplication, application, sender, sender, publicURLsOnly, publicOnly, animating, animating, needsPermission, needsPermission, additionalActivationFlags, flags, activationHandler, activationHandler);
    }
}

// iOS 7.1.x
CHOptimizedMethod8(self, void, SpringBoard, applicationOpenURL, NSURL *, url, withApplication, SBApplication *, application, sender, id, sender, publicURLsOnly, BOOL, publicOnly, animating, BOOL, animating, needsPermission, BOOL, needsPermission, activationContext, id, context, activationHandler, id, activationHandler)
{
    CHDebugLog(@"Opening URL %@ with application %@ using iOS 7.1 method", url, application);
    
    if (!HandleApplicationOpenURLWithReentrantGuard(self, &url, &application)) {
        CHSuper8(SpringBoard, applicationOpenURL, url, withApplication, application, sender, sender, publicURLsOnly, publicOnly, animating, animating, needsPermission, needsPermission, activationContext, context, activationHandler, activationHandler);
    }
}

// iOS 8
CHOptimizedMethod8(self, void, SpringBoard, applicationOpenURL, NSURL *, url, withApplication, SBApplication *, application, sender, id, sender, publicURLsOnly, BOOL, publicOnly, animating, BOOL, animating, needsPermission, BOOL, needsPermission, activationSettings, id, settings, withResult, id, resultHandler)
{
    CHDebugLog(@"Opening URL %@ with application %@ using iOS 8 method", url, application);

    if (!HandleApplicationOpenURLWithReentrantGuard(self, &url, &application)) {
        CHSuper8(SpringBoard, applicationOpenURL, url, withApplication, application, sender, sender, publicURLsOnly, publicOnly, animating, animating, needsPermission, needsPermission, activationSettings, settings, withResult, resultHandler);
    }
}

static BOOL HandleBookmarkIconLaunch(UIWebClip *webClip)
{
    BOOL handled = NO;
    if (OCHookEnabled) {
        NSURL *pageURL = webClip.pageURL;
        if (pageURL && [OpenInChromeModel shouldHandleURL:pageURL]) {
            NSURL *replacedURL = [OpenInChromeModel formatURLForChrome:pageURL];
            if (replacedURL) {
                [[UIApplication sharedApplication] openURL:replacedURL];
                handled = YES;
            }
        }
    }
    return handled;
}

CHOptimizedMethod0(self, void, SBBookmarkIcon, launch)
{
    if (OCHookEnabled && HandleBookmarkIconLaunch(self.webClip)) {
        return;
    } else {
        CHSuper0(SBBookmarkIcon, launch);
    }
}

CHOptimizedMethod2(self, BOOL, SBBookmark, icon, SBLeafIcon *, icon, launchFromLocation, SBIconLaunchLocation, location)
{
    if (OCHookEnabled && HandleBookmarkIconLaunch(self.webClip)) {
        return YES;
    } else {
        return CHSuper2(SBBookmark, icon, icon, launchFromLocation, location);
    }
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
        CHLoadLateClass(SBBookmark);
		
		CHHook5(SpringBoard, applicationOpenURL, publicURLsOnly, animating, sender, additionalActivationFlag); // iOS 5
		CHHook7(SpringBoard, applicationOpenURL, withApplication, sender, publicURLsOnly, animating, needsPermission, additionalActivationFlags); // iOS 6
        CHHook8(SpringBoard, applicationOpenURL, withApplication, sender, publicURLsOnly, animating, needsPermission, additionalActivationFlags, activationHandler); // iOS 7.0
        CHHook8(SpringBoard, applicationOpenURL, withApplication, sender, publicURLsOnly, animating, needsPermission, activationContext, activationHandler); // iOS 7.1
        CHHook8(SpringBoard, applicationOpenURL, withApplication, sender, publicURLsOnly, animating, needsPermission, activationSettings, withResult); // iOS 8

		CHHook0(SBBookmarkIcon, launch); // iOS 5-6
        CHHook2(SBBookmark, icon, launchFromLocation); // iOS 7.x
    }
}
