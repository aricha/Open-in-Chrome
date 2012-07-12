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

static NSString *const OpenInChromeBundleID = @"com.arichardson.openInChrome";

static NSString *const kOpenInChromeEnabled = @"openInChromeEnabled";

@class SBDisplay;

@interface SpringBoard : UIApplication
-(void)applicationOpenURL:(id)url publicURLsOnly:(BOOL)only animating:(BOOL)animating sender:(id)sender additionalActivationFlag:(unsigned)flag;
-(NSString *)displayIDForURLScheme:(NSString *)scheme isPublic:(BOOL)isPublic;
@end

@interface SBApplicationController : NSObject
+(SBApplicationController *)sharedInstance;
-(SBDisplay *)applicationWithDisplayIdentifier:(NSString *)displayID;
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
        
        static Class _SBApplicationController, _SpringBoard;
        
        _SBApplicationController = NSClassFromString(@"SBApplicationController");
        _SpringBoard = NSClassFromString(@"SpringBoard");
        
        static IMP origOpenURL = NULL;
        SEL openURLSel = @selector(applicationOpenURL:publicURLsOnly:animating:sender:additionalActivationFlag:);
        
        void (^chromeHookOpenURL)(SpringBoard *, NSURL *, BOOL, BOOL, id, unsigned) = nil;
        chromeHookOpenURL = ^(SpringBoard *sb, NSURL *url, BOOL publicOnly, BOOL animate, id sender, unsigned flag)
        {
            if (hookEnabled && [[sb displayIDForURLScheme:[url scheme] isPublic:YES] isEqualToString:@"com.apple.mobilesafari"])
            {                
                // TODO: add support for searches
                // search URL: x-web-search:///?{query}
                // wikipedia URL: x-web-search://wikipedia/?{query}
                // chrome prefs location: {rootAppDir}/Library/Application Support/Google/Chrome/Default/Preferences
                // stored in JSON format; key: "default_search_provider"->"search_url"
                
                NSString *chromeScheme = ([[url scheme] isEqualToString:@"https"] ? @"googlecrhomes" : @"googlechrome");
                
                NSString *displayID = [sb displayIDForURLScheme:chromeScheme isPublic:YES];
                if (displayID) {
                    // Chrome installed, replace URL
                    url = [NSURL URLWithString:[NSString stringWithFormat:@"%@:%@", chromeScheme, [url resourceSpecifier]]];
                }
            }
            
            origOpenURL(sb, openURLSel, url, publicOnly, animate, sender, flag);
        };
        
        IMP chromeHookImp = imp_implementationWithBlock(chromeHookOpenURL);
        MSHookMessageEx(_SpringBoard, openURLSel, chromeHookImp, &origOpenURL);
    }
}
