//
//  OpenInChromeModel.m
//  openInChrome
//
//  Created by Andrew Richardson on 12-07-12.
//
//

#import "OpenInChromeModel.h"
#import <UIKit/UIKit.h>

static NSString *const ChromeSchemeHTTP = @"googlechrome";
static NSString *const ChromeSchemeHTTPS = @"googlechromes";

@interface OpenInChromeModel ()

+ (BOOL)isChromeAppInstalled;
+ (NSArray *)supportedURLSchemes;
+ (BOOL)isSupportedURLScheme:(NSString *)scheme;

+ (NSURL *)defaultWebSearchURLForQuery:(NSString *)query;
+ (NSURL *)buildSearchURLForSearchEngine:(NSDictionary *)engine withQuery:(NSString *)query;
+ (NSURL *)webSearchURLForQuery:(NSString *)query;

@end

@implementation OpenInChromeModel

+ (NSArray *)supportedURLSchemes {
    return @[ @"http", @"https", @"x-web-search" ];
}

+ (BOOL)isSupportedURLScheme:(NSString *)scheme {
    return [[self supportedURLSchemes] containsObject:scheme];
}

+ (BOOL)isChromeAppInstalled {
    UIApplication *sb = [UIApplication sharedApplication];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", ChromeSchemeHTTP]];
    return [sb canOpenURL:url];
}

+ (BOOL)canHandleURL:(NSURL *)url {
    return ([self isSupportedURLScheme:[url scheme]] && [self isChromeAppInstalled]);
}

+ (NSString *)addPercentEscapesForString:(NSString *)string {
    return [(NSString *) CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                 (CFStringRef)string,
                                                                 NULL,
                                                                 (CFStringRef) @"!*'();:@&=+$,/?%#[]",
                                                                 kCFStringEncodingUTF8) autorelease];
}

+ (NSURL *)defaultWebSearchURLForQuery:(NSString *)query {
    NSString *languageCode = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
    NSString *escapedQuery = [self addPercentEscapesForString:query];
    
    NSString *searchString = [NSString stringWithFormat:@"%@://www.google.com/search?q=%@&ie=UTF-8&oe=UTF-8&hl=%@", ChromeSchemeHTTP, escapedQuery, languageCode];
    
    return [NSURL URLWithString:searchString];
}

+ (NSURL *)buildSearchURLForSearchEngine:(NSDictionary *)engine withQuery:(NSString *)query {
    NSString *searchURLKey = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"SearchURLTemplatePad" : @"SearchURLTemplate");
    NSString *searchURLTemplate = [engine objectForKey:searchURLKey];
    if (!searchURLTemplate)
        return nil;
    
    // remove scheme from URL (will be replaced by Chrome scheme)
    NSUInteger schemeStart = [searchURLTemplate rangeOfString:@"://"].location;
    if (schemeStart == NSNotFound)
        return nil;
    NSString *scheme = [searchURLTemplate substringToIndex:schemeStart];
    NSRange schemeRange = [scheme rangeOfString:@"http"];
    if (schemeRange.location == NSNotFound)
        return nil;
    searchURLTemplate = [searchURLTemplate stringByReplacingCharactersInRange:schemeRange withString:ChromeSchemeHTTP];
    
    
    // replaces the template URL placeholder with the appropriate term
    NSString *(^placeholderHandler)(NSString *) = ^NSString *(NSString *placeholder) {
        NSString *result = nil;
        
        if ([placeholder isEqualToString:@"searchTerms"])
            result = query;
        else if ([placeholder isEqualToString:@"topLevelDomain"]) {
            NSString *countryCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
            NSDictionary *topLevelDomains = [engine objectForKey:@"TopLevelDomains"];
            if (topLevelDomains) {
                result = [topLevelDomains objectForKey:countryCode];
            }
        }
        else if ([placeholder isEqualToString:@"languageCode"]) {
            result = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
        }
        
        return result;
    };
    
    NSMutableString *searchURLString = [NSMutableString stringWithString:searchURLTemplate];
    
    DLog(@"beginning placeholder parsing of template %@", searchURLString);
    
    BOOL hasPlaceholder = YES;
    while (hasPlaceholder) {
        NSUInteger placeholderStart = [searchURLString rangeOfString:@"{"].location;
        hasPlaceholder = (placeholderStart != NSNotFound);
        if (hasPlaceholder) {
            NSRange placeholderEndRange = [[searchURLString substringFromIndex:placeholderStart] rangeOfString:@"}"];
            NSRange placeholderRange = NSMakeRange(placeholderStart, NSMaxRange(placeholderEndRange));
            NSRange placeholderTextRange = NSMakeRange(placeholderStart + 1, placeholderEndRange.location - 1);
            
            DLog(@"placeholderRange: %@, string in range: %@", NSStringFromRange(placeholderRange), [searchURLString substringWithRange:placeholderRange]);
            
            if (placeholderRange.location + placeholderRange.length <= searchURLString.length) {
                NSString *replacedPlaceholder = placeholderHandler([searchURLString substringWithRange:placeholderTextRange]);
                
                if (!replacedPlaceholder) {
                    // could not handle placeholder, abort string parsing
                    DLog(@"could not handle placeholder %@, aborting", [searchURLString substringWithRange:placeholderTextRange]);
                    searchURLString = nil;
                    break;
                }
                
                // use full placeholder to remove the {} characters
                [searchURLString replaceCharactersInRange:placeholderRange withString:replacedPlaceholder];
            }
        }
    }
    
    NSURL *searchURL = nil;
    
    if (searchURLString && searchURLString.length > ChromeSchemeHTTP.length)
        searchURL = [NSURL URLWithString:searchURLString];
    
    DLog(@"Built search URL %@ from search engine %@", searchURL, engine);
    
    return searchURL;
}

+ (NSURL *)webSearchURLForQuery:(NSString *)query {
    NSURL *searchURL = nil;
    
    // TODO: may want to support Chrome's app settings for search engines as well
    // Chrome prefs location: {rootAppDir}/Library/Application Support/Google/Chrome/Default/Preferences
    // stored in JSON format; key: "default_search_provider"->"search_url"
    NSString *selectedEngineName = nil;
    NSDictionary *safariPrefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.mobilesafari"];
    
    if (safariPrefs) {
        selectedEngineName = [safariPrefs objectForKey:@"SearchEngineStringSetting"];
    }
    
    NSDictionary *searchEnginesPlist = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Safari/SearchEngines.plist"];
    
    if (selectedEngineName && searchEnginesPlist) {
        NSArray *searchEngines = [searchEnginesPlist objectForKey:@"SearchProviderList"];
        if (searchEngines) {
            NSDictionary *selectedEngine = nil;
            NSMutableArray *possibleEngines = [NSMutableArray array];
            
            NSString *languageCode = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
            
            for (NSDictionary *engine in searchEngines) {
                if ([[engine objectForKey:@"ShortName"] isEqual:selectedEngineName]) {
                    [possibleEngines addObject:engine];
                }
            }
            
            // prioritize engines that specify the user's current language
            // code above those that are language-agnostic
            for (NSDictionary *engine in possibleEngines) {
                NSArray *languages = [engine objectForKey:@"Language"];
                if ([languages containsObject:languageCode]) {
                    selectedEngine = engine;
                    break;
                }
                else if (!languages) {
                    // use as engine, but keep iterating in case there's
                    // another engine that specifies the language code
                    selectedEngine = engine;
                }
            }
            
            if (selectedEngine) {
                searchURL = [self buildSearchURLForSearchEngine:selectedEngine withQuery:query];
            }
        }
    }
    
    if (!searchURL) {
        searchURL = [self defaultWebSearchURLForQuery:query];
    }
    
    return searchURL;
}

+ (NSURL *) formatURLForChrome:(NSURL *)url {
    NSURL *formattedURL = nil;
    
    // search URL: x-web-search:///?{query}
    // wikipedia URL: x-web-search://wikipedia/?{query}
    
    if ([[url scheme] isEqualToString:@"x-web-search"]) {
        // must escape query manually
        NSString *query = [(NSString *) CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                (CFStringRef)[url query],
                                                                                NULL,
                                                                                (CFStringRef) @"!*'();:@&=+$,/?%#[]",
                                                                                kCFStringEncodingUTF8) autorelease];
        
        if ([[url host] isEqualToString:@"wikipedia"]) {
            NSString *languageCode = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
            NSString *urlString = [NSString stringWithFormat:@"%@://%@.wikipedia.org/w/index.php?search=%@&go=Go", ChromeSchemeHTTP, languageCode, query];
            
            if (urlString)
                formattedURL = [NSURL URLWithString:urlString];
        }
        else {
            formattedURL = [self webSearchURLForQuery:query];
        }
    }
    else {
        NSString *chromeScheme = ([[url scheme] isEqualToString:@"https"] ? ChromeSchemeHTTPS : ChromeSchemeHTTP);
        formattedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@:%@", chromeScheme, [url resourceSpecifier]]];
    }
    
    return formattedURL;
}

@end
