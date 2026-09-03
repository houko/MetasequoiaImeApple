#pragma once

#import <AppKit/AppKit.h>

@interface MetasequoiaPreferencesWindowController : NSWindowController
+ (instancetype)sharedController;
- (void)showAndActivate;
@end
