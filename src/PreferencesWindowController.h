#pragma once

#import <AppKit/AppKit.h>

@interface MetasequoiaPreferencesWindowController : NSWindowController
+ (instancetype)sharedController;
+ (NSInteger)storedScheme;
+ (void)setStoredScheme:(NSInteger)scheme;
- (void)showAndActivate;
@end
