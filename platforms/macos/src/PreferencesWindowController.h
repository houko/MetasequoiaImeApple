#pragma once

#import <AppKit/AppKit.h>

FOUNDATION_EXPORT NSNotificationName const MetasequoiaWillResetLearnedDataNotification;
FOUNDATION_EXPORT NSNotificationName const MetasequoiaStandalonePreferencesDidCloseNotification;
FOUNDATION_EXPORT NSNotificationName const MetasequoiaFloatingToolbarDidChangeNotification;
FOUNDATION_EXPORT NSNotificationName const MetasequoiaTraditionalChineseOutputDidChangeNotification;

bool MetasequoiaShouldShowPreferences(int argc, const char *argv[]);

@interface MetasequoiaPreferencesWindowController : NSWindowController <NSWindowDelegate>
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
+ (NSInteger)storedCandidatePageShortcut;
+ (void)setCandidatePageShortcut:(NSInteger)shortcut;
+ (BOOL)storedCandidateLearningEnabled;
+ (void)setCandidateLearningEnabled:(BOOL)enabled;
+ (BOOL)storedEnglishInputMode;
+ (void)setEnglishInputMode:(BOOL)enabled;
+ (BOOL)storedInputModeShortcutEnabled;
+ (void)setInputModeShortcutEnabled:(BOOL)enabled;
+ (BOOL)storedFullWidthInputEnabled;
+ (void)setFullWidthInputEnabled:(BOOL)enabled;
+ (BOOL)storedFloatingToolbarEnabled;
+ (void)setFloatingToolbarEnabled:(BOOL)enabled;
+ (BOOL)storedTraditionalChineseOutputEnabled;
+ (void)setTraditionalChineseOutputEnabled:(BOOL)enabled;
+ (BOOL)storedWubiAutoCommitUniqueEnabled;
+ (void)setWubiAutoCommitUniqueEnabled:(BOOL)enabled;
- (void)showAndActivate;
- (void)showAndActivateForStandaloneLaunch;
@end
