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

@interface SBBookmarkIcon : NSObject
@property (nonatomic, retain) UIWebClip *webClip;
- (void)launch;
@end

@interface SpringBoard : UIApplication
-(void)applicationOpenURL:(id)url publicURLsOnly:(BOOL)only animating:(BOOL)animating sender:(id)sender additionalActivationFlag:(unsigned)flag; // iOS 5
-(void)applicationOpenURL:(NSURL *)url withApplication:(id)application sender:(id)sender publicURLsOnly:(BOOL)only animating:(BOOL)animating needsPermission:(BOOL)permission additionalActivationFlags:(id)flags; // iOS 6+
-(NSString *)displayIDForURLScheme:(NSString *)urlscheme isPublic:(BOOL)aPublic;
@end

@interface SBApplication : NSObject
@property(copy) NSString* displayIdentifier;
@end

@interface SBApplicationController : NSObject
+(instancetype)sharedInstanceIfExists;
-(SBApplication *)applicationWithDisplayIdentifier:(NSString *)displayIdentifier;
@end
