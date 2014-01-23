//
//  PrivateHeaders.h
//  openInChrome
//
//  Created by Andrew Richardson on 2013-01-28.
//
//

#import <UIKit/UIKit.h>

#pragma mark - UIKit

UIKIT_EXTERN UIApplication *UIApp;

@interface UIApplication ()
-(NSString *)displayIDForURLScheme:(NSString *)urlscheme isPublic:(BOOL)aPublic;
@end

@interface UIWebClip : NSObject
@property(retain) NSURL* pageURL;
@end

#pragma mark - SpringBoard

typedef NSInteger SBIconLaunchLocation;

@interface SBIcon : NSObject
- (void)launch; // iOS 5-6
- (void)launchFromLocation:(SBIconLaunchLocation)location; // iOS 7
@end

@interface SBLeafIcon : SBIcon
@end

@protocol SBLeafIconDataSource <NSObject> // iOS 7
- (BOOL)icon:(SBLeafIcon *)icon launchFromLocation:(SBIconLaunchLocation)location;
@end

@interface SBBookmark : NSObject <SBLeafIconDataSource> // iOS 7
@property (retain, nonatomic) UIWebClip *webClip;
@end

@interface SBBookmarkIcon : SBLeafIcon
@property (retain, nonatomic) UIWebClip *webClip; // iOS 5-6
@property (retain, nonatomic) SBBookmark *bookmark; // iOS 7
@end

@interface SpringBoard : UIApplication
-(void)applicationOpenURL:(NSURL *)url publicURLsOnly:(BOOL)only;
-(void)applicationOpenURL:(id)url publicURLsOnly:(BOOL)only animating:(BOOL)animating sender:(id)sender additionalActivationFlag:(unsigned)flag; // iOS 5
-(void)applicationOpenURL:(NSURL *)url withApplication:(id)application sender:(id)sender publicURLsOnly:(BOOL)only animating:(BOOL)animating needsPermission:(BOOL)permission additionalActivationFlags:(id)flags; // iOS 6
-(void)applicationOpenURL:(NSURL *)url withApplication:(id)application sender:(id)sender publicURLsOnly:(BOOL)only animating:(BOOL)animating needsPermission:(BOOL)permission additionalActivationFlags:(id)flags activationHandler:(id)handler; // iOS 7
-(NSString *)displayIDForURLScheme:(NSString *)urlscheme isPublic:(BOOL)aPublic;
@end

@interface SBApplication : NSObject
@property(copy) NSString* displayIdentifier;
@end

@interface SBApplicationController : NSObject
+(instancetype)sharedInstanceIfExists;
-(SBApplication *)applicationWithDisplayIdentifier:(NSString *)displayIdentifier;
@end
