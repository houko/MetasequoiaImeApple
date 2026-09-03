#pragma once

#import <AppKit/AppKit.h>

@interface MetasequoiaPreferencesWindowController : NSWindowController
+ (instancetype)sharedController;
+ (NSInteger)storedScheme;
+ (void)setStoredScheme:(NSInteger)scheme;
+ (BOOL)storedAutocorrectEnabled;
+ (void)setAutocorrectEnabled:(BOOL)enabled;
- (void)showAndActivate;
@end
