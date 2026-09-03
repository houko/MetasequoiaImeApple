#pragma once

#import <AppKit/AppKit.h>

@interface MetasequoiaPreferencesWindowController : NSWindowController
+ (instancetype)sharedController;
+ (NSInteger)storedScheme;
+ (void)setStoredScheme:(NSInteger)scheme;
+ (BOOL)storedAutocorrectEnabled;
+ (void)setAutocorrectEnabled:(BOOL)enabled;
+ (BOOL)storedHelpcodeEnabled;
+ (void)setHelpcodeEnabled:(BOOL)enabled;
+ (BOOL)storedChinesePunctuationEnabled;
+ (void)setChinesePunctuationEnabled:(BOOL)enabled;
+ (NSInteger)storedCandidatePanelStyle;
+ (void)setCandidatePanelStyle:(NSInteger)style;
+ (NSInteger)storedCandidatePageSize;
+ (void)setCandidatePageSize:(NSInteger)pageSize;
- (void)showAndActivate;
@end
