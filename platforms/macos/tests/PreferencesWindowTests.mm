#import "../src/PreferencesWindowController.h"
#import "../src/UpdateController.h"

#import <AppKit/AppKit.h>

#include <stdexcept>

@interface MetasequoiaPreferencesWindowController (Testing)
- (void)refreshControls;
@end

namespace
{
void require(bool condition, const char *message)
{
    if (!condition)
    {
        throw std::runtime_error(message);
    }
}

bool WaitUntil(BOOL (^condition)(void))
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while (!condition())
    {
        if ([deadline timeIntervalSinceNow] <= 0.0)
        {
            return false;
        }
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return true;
}

NSView *FindViewWithAccessibilityLabel(NSView *view, NSString *label)
{
    if ([view.accessibilityLabel isEqualToString:label])
    {
        return view;
    }
    for (NSView *subview in view.subviews)
    {
        NSView *match = FindViewWithAccessibilityLabel(subview, label);
        if (match != nil)
        {
            return match;
        }
    }
    return nil;
}

NSButton *FindButtonWithTitle(NSView *view, NSString *title)
{
    if ([view isKindOfClass:[NSButton class]] && [((NSButton *)view).title isEqualToString:title])
    {
        return (NSButton *)view;
    }
    for (NSView *subview in view.subviews)
    {
        NSButton *match = FindButtonWithTitle(subview, title);
        if (match != nil)
        {
            return match;
        }
    }
    return nil;
}
} // namespace

int main()
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        const char *showSettingsArguments[] = {"MetasequoiaIME", "--show-settings"};
        const char *extraSettingsArguments[] = {"MetasequoiaIME", "--show-settings", "unexpected"};
        const char *serverArguments[] = {"MetasequoiaIME"};
        require(MetasequoiaShouldShowPreferences(2, showSettingsArguments),
                "The standalone settings argument was not recognized.");
        require(!MetasequoiaShouldShowPreferences(3, extraSettingsArguments),
                "Standalone settings accepted unexpected arguments.");
        require(!MetasequoiaShouldShowPreferences(1, serverArguments),
                "A normal input-method launch was treated as standalone settings.");
        [MetasequoiaPreferencesWindowController setCandidatePanelStyle:1];
        [MetasequoiaPreferencesWindowController setCandidatePageSize:5];
        [MetasequoiaPreferencesWindowController setCandidateFontSize:16];
        [MetasequoiaPreferencesWindowController setCandidateLearningEnabled:NO];
        [MetasequoiaPreferencesWindowController setEnglishInputMode:YES];
        [MetasequoiaPreferencesWindowController setInputModeShortcutEnabled:NO];
        require([MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 1,
                "The vertical candidate layout preference was not stored.");
        require([MetasequoiaPreferencesWindowController storedCandidatePageSize] == 5,
                "The five-candidate page-size preference was not stored.");
        require([MetasequoiaPreferencesWindowController storedCandidateFontSize] == 16,
                "The small candidate font-size preference was not stored.");
        require(![MetasequoiaPreferencesWindowController storedCandidateLearningEnabled],
                "The disabled candidate-learning preference was not stored.");
        require([MetasequoiaPreferencesWindowController storedEnglishInputMode],
                "The English input-mode state was not stored.");
        require(![MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled],
                "The disabled input-mode shortcut preference was not stored.");

        MetasequoiaPreferencesWindowController *controller =
            [[MetasequoiaPreferencesWindowController alloc] init];
        [controller refreshControls];
        NSView *view = FindViewWithAccessibilityLabel(controller.window.contentView, @"候选排列");
        require([view isKindOfClass:[NSPopUpButton class]],
                "The settings window did not expose the candidate layout control.");
        NSPopUpButton *styleButton = (NSPopUpButton *)view;
        require(styleButton.numberOfItems == 2 &&
                    [[styleButton itemTitleAtIndex:0] isEqualToString:@"横向排列"] &&
                    [[styleButton itemTitleAtIndex:1] isEqualToString:@"纵向列表"],
                "The candidate layout control did not contain both supported layouts.");
        require(styleButton.indexOfSelectedItem == 1,
                "The candidate layout control did not reflect the stored vertical layout.");

        NSView *pageSizeView = FindViewWithAccessibilityLabel(controller.window.contentView, @"每页候选");
        require([pageSizeView isKindOfClass:[NSPopUpButton class]],
                "The settings window did not expose the candidate page-size control.");
        NSPopUpButton *pageSizeButton = (NSPopUpButton *)pageSizeView;
        require(pageSizeButton.numberOfItems == 3 &&
                    [[pageSizeButton itemTitleAtIndex:0] isEqualToString:@"5 个"] &&
                    [[pageSizeButton itemTitleAtIndex:1] isEqualToString:@"7 个"] &&
                    [[pageSizeButton itemTitleAtIndex:2] isEqualToString:@"9 个"],
                "The candidate page-size control did not contain all supported values.");
        require(pageSizeButton.indexOfSelectedItem == 0,
                "The candidate page-size control did not reflect the stored value.");

        NSView *fontSizeView = FindViewWithAccessibilityLabel(controller.window.contentView, @"候选字号");
        require([fontSizeView isKindOfClass:[NSPopUpButton class]],
                "The settings window did not expose the candidate font-size control.");
        NSPopUpButton *fontSizeButton = (NSPopUpButton *)fontSizeView;
        require(fontSizeButton.numberOfItems == 3 &&
                    [[fontSizeButton itemTitleAtIndex:0] isEqualToString:@"小（16 pt）"] &&
                    [[fontSizeButton itemTitleAtIndex:1] isEqualToString:@"标准（18 pt）"] &&
                    [[fontSizeButton itemTitleAtIndex:2] isEqualToString:@"大（20 pt）"],
                "The candidate font-size control did not contain all supported values.");
        require(fontSizeButton.indexOfSelectedItem == 0,
                "The candidate font-size control did not reflect the stored value.");

        NSView *learningView = FindViewWithAccessibilityLabel(controller.window.contentView, @"记住候选词频");
        require([learningView isKindOfClass:[NSButton class]],
                "The settings window did not expose the candidate-learning control.");
        NSButton *learningButton = (NSButton *)learningView;
        require(learningButton.state == NSControlStateValueOff,
                "The candidate-learning control did not reflect the stored disabled value.");

        NSView *shortcutView = FindViewWithAccessibilityLabel(controller.window.contentView,
                                                               @"Shift+Space 切换中英文");
        require([shortcutView isKindOfClass:[NSButton class]],
                "The settings window did not expose the input-mode shortcut control.");
        NSButton *shortcutButton = (NSButton *)shortcutView;
        require(shortcutButton.state == NSControlStateValueOff,
                "The input-mode shortcut control did not reflect the stored disabled value.");

        NSView *resetLearningView = FindViewWithAccessibilityLabel(controller.window.contentView,
                                                                   @"清除学习数据");
        require([resetLearningView isKindOfClass:[NSButton class]],
                "The settings window did not expose the learned-data reset button.");
        NSButton *resetLearningButton = (NSButton *)resetLearningView;
        NSView *updateView = FindViewWithAccessibilityLabel(controller.window.contentView, @"软件更新");
        require([updateView isKindOfClass:[NSButton class]],
                "The settings window did not expose the software-update control.");
        require([((NSButton *)updateView).title containsString:@"检查更新"],
                "The software-update control did not show the installed-version state.");
        require([((NSButton *)updateView).accessibilityHelp containsString:@"检查 GitHub"],
                "The software-update control did not expose its current state to assistive technology.");
        require(((NSButton *)updateView).action == @selector(checkForUpdates:) &&
                    ((NSButton *)updateView).target == controller,
                "The software-update control did not invoke the in-place Sparkle updater.");

        __block bool resetStartedAfterCancel = false;
        id cancelObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:MetasequoiaWillResetLearnedDataNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *notification) {
                        (void)notification;
                        resetStartedAfterCancel = true;
                    }];
        [resetLearningButton performClick:nil];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        NSWindow *confirmationSheet = controller.window.attachedSheet;
        require(confirmationSheet != nil, "The learned-data reset button did not present a confirmation sheet.");
        NSButton *cancelResetButton = FindButtonWithTitle(confirmationSheet.contentView, @"取消");
        NSButton *confirmResetButton = FindButtonWithTitle(confirmationSheet.contentView, @"清除");
        require(cancelResetButton != nil && confirmationSheet.defaultButtonCell == cancelResetButton.cell,
                "The learned-data reset confirmation did not make cancellation the default action.");
        require(confirmResetButton != nil && confirmResetButton.hasDestructiveAction,
                "The learned-data reset confirmation did not mark the clear action as destructive.");
        [cancelResetButton performClick:nil];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        [[NSNotificationCenter defaultCenter] removeObserver:cancelObserver];
        require(!resetStartedAfterCancel && controller.window.attachedSheet == nil,
                "Cancelling the learned-data reset started destructive work.");

        __block bool resetNotificationReceived = false;
        id resetObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:MetasequoiaWillResetLearnedDataNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *notification) {
                        (void)notification;
                        resetNotificationReceived = true;
                    }];
        [MetasequoiaPreferencesWindowController prepareInputSessionsForLearnedDataReset];
        [[NSNotificationCenter defaultCenter] removeObserver:resetObserver];
        require(resetNotificationReceived,
                "The learned-data reset did not synchronously request input-session quiescence.");

        [styleButton selectItemAtIndex:0];
        require([NSApp sendAction:styleButton.action to:styleButton.target from:styleButton],
                "The candidate layout control did not dispatch its action.");
        require([MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 0,
                "The candidate layout control did not store the selected horizontal layout.");

        [pageSizeButton selectItemAtIndex:1];
        require([NSApp sendAction:pageSizeButton.action to:pageSizeButton.target from:pageSizeButton],
                "The candidate page-size control did not dispatch its action.");
        require([MetasequoiaPreferencesWindowController storedCandidatePageSize] == 7,
                "The candidate page-size control did not store the selected value.");

        [fontSizeButton selectItemAtIndex:2];
        require([NSApp sendAction:fontSizeButton.action to:fontSizeButton.target from:fontSizeButton],
                "The candidate font-size control did not dispatch its action.");
        require([MetasequoiaPreferencesWindowController storedCandidateFontSize] == 20,
                "The candidate font-size control did not store the selected value.");

        learningButton.state = NSControlStateValueOn;
        require([NSApp sendAction:learningButton.action to:learningButton.target from:learningButton],
                "The candidate-learning control did not dispatch its action.");
        require([MetasequoiaPreferencesWindowController storedCandidateLearningEnabled],
                "The candidate-learning control did not store the selected value.");

        shortcutButton.state = NSControlStateValueOn;
        require([NSApp sendAction:shortcutButton.action to:shortcutButton.target from:shortcutButton],
                "The input-mode shortcut control did not dispatch its action.");
        require([MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled],
                "The input-mode shortcut control did not store the enabled value.");

        [MetasequoiaPreferencesWindowController setCandidatePanelStyle:99];
        require([MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 0,
                "An unsupported candidate layout preference was not normalized safely.");
        [MetasequoiaPreferencesWindowController setCandidatePageSize:99];
        require([MetasequoiaPreferencesWindowController storedCandidatePageSize] == 9,
                "An unsupported candidate page size was not normalized safely.");
        [MetasequoiaPreferencesWindowController setCandidateFontSize:99];
        require([MetasequoiaPreferencesWindowController storedCandidateFontSize] == 18,
                "An unsupported candidate font size was not normalized safely.");
        [MetasequoiaPreferencesWindowController setStoredScheme:1];
        [MetasequoiaPreferencesWindowController setAutocorrectEnabled:NO];
        [MetasequoiaPreferencesWindowController setHelpcodeEnabled:NO];
        [MetasequoiaPreferencesWindowController setChinesePunctuationEnabled:NO];
        [MetasequoiaPreferencesWindowController setCandidatePanelStyle:1];
        [MetasequoiaPreferencesWindowController setCandidatePageSize:5];
        [MetasequoiaPreferencesWindowController setCandidateFontSize:20];
        [MetasequoiaPreferencesWindowController setCandidateLearningEnabled:NO];
        [MetasequoiaPreferencesWindowController setInputModeShortcutEnabled:NO];
        [MetasequoiaPreferencesWindowController setEnglishInputMode:YES];
        NSButton *restoreDefaultsButton = FindButtonWithTitle(controller.window.contentView, @"恢复默认设置");
        require(restoreDefaultsButton != nil, "The settings window did not expose the restore-defaults button.");
        [restoreDefaultsButton performClick:nil];
        require([MetasequoiaPreferencesWindowController storedScheme] == 0 &&
                    [MetasequoiaPreferencesWindowController storedAutocorrectEnabled] &&
                    [MetasequoiaPreferencesWindowController storedHelpcodeEnabled] &&
                    [MetasequoiaPreferencesWindowController storedChinesePunctuationEnabled] &&
                    [MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 0 &&
                    [MetasequoiaPreferencesWindowController storedCandidatePageSize] == 9 &&
                    [MetasequoiaPreferencesWindowController storedCandidateFontSize] == 18 &&
                    [MetasequoiaPreferencesWindowController storedCandidateLearningEnabled] &&
                    [MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled],
                "Restoring defaults did not restore every visible setting.");
        NSArray<NSString *> *preferenceKeys = @[
            @"MetasequoiaImeInputScheme",
            @"MetasequoiaImeQuanpinAutocorrect",
            @"MetasequoiaImeHelpcodeEnabled",
            @"MetasequoiaImeChinesePunctuation",
            @"MetasequoiaImeCandidatePanelStyle",
            @"MetasequoiaImeCandidatePageSize",
            @"MetasequoiaImeCandidateFontSize",
            @"MetasequoiaImeCandidateLearning",
            @"MetasequoiaImeInputModeShortcutEnabled",
        ];
        for (NSString *key in preferenceKeys)
        {
            require([[NSUserDefaults standardUserDefaults] objectForKey:key] == nil,
                    "Restoring defaults left a persisted override that can pin an obsolete default.");
        }
        require([MetasequoiaPreferencesWindowController storedEnglishInputMode],
                "Restoring configurable defaults unexpectedly changed the current input mode.");
        [MetasequoiaPreferencesWindowController setEnglishInputMode:NO];
        require(![MetasequoiaPreferencesWindowController storedEnglishInputMode],
                "The Chinese input-mode state was not stored.");

        __block bool standaloneCloseObserved = false;
        id standaloneCloseObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:MetasequoiaStandalonePreferencesDidCloseNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *notification) {
                        (void)notification;
                        standaloneCloseObserved = true;
                    }];
        MetasequoiaPreferencesWindowController *standaloneController =
            [[MetasequoiaPreferencesWindowController alloc] init];
        [standaloneController showAndActivateForStandaloneLaunch];
        NSView *standaloneResetView = FindViewWithAccessibilityLabel(standaloneController.window.contentView,
                                                                     @"清除学习数据");
        require([standaloneResetView isKindOfClass:[NSButton class]] &&
                    !((NSButton *)standaloneResetView).enabled &&
                    [((NSButton *)standaloneResetView).accessibilityHelp containsString:@"输入菜单"],
                "Standalone settings allowed an unsafe learned-data reset.");
        NSButton *standaloneCloseButton = FindButtonWithTitle(standaloneController.window.contentView, @"关闭");
        require(standaloneCloseButton != nil, "The standalone settings window did not expose its close action.");
        [standaloneCloseButton performClick:nil];
        require(WaitUntil(^BOOL {
                    return standaloneCloseObserved && !standaloneController.window.visible;
                }),
                "Closing standalone settings did not finish or request application termination.");
        [[NSNotificationCenter defaultCenter] removeObserver:standaloneCloseObserver];
    }
    return 0;
}
