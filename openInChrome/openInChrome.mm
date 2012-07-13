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
#import "CaptainHook/CaptainHook.h"
#import <substrate.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "OpenInChromeModel.h"

static NSString *const OpenInChromeBundleID = @"com.arichardson.openInChrome";
static NSString *const kOpenInChromeEnabled = @"openInChromeEnabled";

static NSString *const ChromeSchemeHTTP = @"googlechrome";
static NSString *const ChromeSchemeHTTPS = @"googlechromes";

@interface UIWebClip : NSObject
@property(retain) NSURL* pageURL;
@end

@interface SBBookmarkIcon : NSObject
@property (nonatomic, retain) UIWebClip *webClip;
- (void)launch;
@end

@interface SpringBoard : UIApplication
-(void)applicationOpenURL:(id)url publicURLsOnly:(BOOL)only animating:(BOOL)animating sender:(id)sender additionalActivationFlag:(unsigned)flag;
-(NSString *)displayIDForURLScheme:(NSString *)scheme isPublic:(BOOL)isPublic;
@end

static BOOL hookEnabled = YES;

static void UpdateOpenInChromeSettings() {
    NSDictionary *settings = [[NSUserDefaults standardUserDefaults] persistentDomainForName:OpenInChromeBundleID];
    
    NSNumber *enabled = [settings objectForKey:kOpenInChromeEnabled];
    if (enabled) {
        hookEnabled = [enabled boolValue];
    }
}

static void SettingsDidChangeNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSDictionary *settings = [[NSUserDefaults standardUserDefaults] persistentDomainForName:OpenInChromeBundleID];
    
    NSNumber *enabled = [settings objectForKey:kOpenInChromeEnabled];
    if (enabled) {
        hookEnabled = [enabled boolValue];
    }
}

CHConstructor
{	
    @autoreleasepool {
        CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(darwin, NULL, SettingsDidChangeNotificationCallback, CFSTR("com.arichardson.openInChrome.settingsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        
        UpdateOpenInChromeSettings();
        
        static Class _SpringBoard, _SBBookmarkIcon;
        
        _SpringBoard = NSClassFromString(@"SpringBoard");
        _SBBookmarkIcon = NSClassFromString(@"SBBookmarkIcon");
        
        static IMP origOpenURL = NULL;
        SEL openURLSel = @selector(applicationOpenURL:publicURLsOnly:animating:sender:additionalActivationFlag:);
        
        void (^chromeOpenURL)(SpringBoard *, NSURL *, BOOL, BOOL, id, unsigned) = nil;
        chromeOpenURL = ^(SpringBoard *sb, NSURL *url, BOOL publicOnly, BOOL animate, id sender, unsigned flag)
        {
            if (hookEnabled && [OpenInChromeModel canHandleURL:url])
            {
                NSURL *replacedURL = [OpenInChromeModel formatURLForChrome:url];
                if (replacedURL)
                    url = replacedURL;
            }
            
            origOpenURL(sb, openURLSel, url, publicOnly, animate, sender, flag);
        };
        
        IMP chromeOpenURLImp = imp_implementationWithBlock(chromeOpenURL);
        MSHookMessageEx(_SpringBoard, openURLSel, chromeOpenURLImp, &origOpenURL);
        
        static IMP origLaunch = NULL;
        SEL launchSel = @selector(launch);
        void (^chromeLaunchWebClip)(SBBookmarkIcon *) = ^(SBBookmarkIcon *icon)
        {
            if (hookEnabled) {
                NSURL *pageURL = [icon webClip].pageURL;
                
                if (pageURL && [OpenInChromeModel canHandleURL:pageURL]) {
                    NSURL *replacedURL = [OpenInChromeModel formatURLForChrome:pageURL];
                    if (replacedURL) {
                        [[UIApplication sharedApplication] openURL:replacedURL];
                        return;
                    }
                }
            }
            origLaunch(icon, launchSel);
        };
        
        IMP chromeLaunchWebClipImp = imp_implementationWithBlock(chromeLaunchWebClip);
        MSHookMessageEx(_SBBookmarkIcon, launchSel, chromeLaunchWebClipImp, &origLaunch);
    }
}
