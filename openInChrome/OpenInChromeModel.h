//
//  OpenInChromeModel.h
//  openInChrome
//
//  Created by Andrew Richardson on 12-07-12.
//
//

#import <Foundation/Foundation.h>

@interface OpenInChromeModel : NSObject

+ (BOOL)canHandleURL:(NSURL *)url;
+ (NSURL *)formatURLForChrome:(NSURL *)url;

@end