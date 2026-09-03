#pragma once

#import <AppKit/AppKit.h>

FOUNDATION_EXPORT NSNotificationName const MetasequoiaWillResetLearnedDataNotification;

@interface MetasequoiaPreferencesWindowController : NSWindowController
+ (instancetype)sharedController;
+ (void)prepareInputSessionsForLearnedDataReset;
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
+ (NSInteger)storedCandidateFontSize;
+ (void)setCandidateFontSize:(NSInteger)fontSize;
+ (BOOL)storedCandidateLearningEnabled;
+ (void)setCandidateLearningEnabled:(BOOL)enabled;
+ (BOOL)storedEnglishInputMode;
+ (void)setEnglishInputMode:(BOOL)enabled;
+ (BOOL)storedInputModeShortcutEnabled;
+ (void)setInputModeShortcutEnabled:(BOOL)enabled;
- (void)showAndActivate;
@end
