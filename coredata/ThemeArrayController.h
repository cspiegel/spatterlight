//
//  ThemeArrayController.h
//  Spatterlight
//
//  Created by Petter Sjölund on 2020-01-31.
//
//

#import <Cocoa/Cocoa.h>

@class Theme;

@interface ThemeArrayController : NSArrayController

@property (readonly) Theme *selectedTheme;

@end
