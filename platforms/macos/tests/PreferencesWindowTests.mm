#import "../src/PreferencesWindowController.h"
#import "../src/UpdateController.h"

#import <AppKit/AppKit.h>

#include <algorithm>
#include <cmath>
#include <stdexcept>

@interface MetasequoiaPreferencesWindowController (Testing)
- (instancetype)initWithUpdateController:(MetasequoiaUpdateController *)updateController;
- (void)refreshControls;
- (void)refreshUpdateControls;
- (void)selectPreferencesPage:(id)sender;
- (void)openWebsite:(id)sender;
- (void)openFeedback:(id)sender;
@end

@interface PreferencesFakeUpdateDriver : NSObject <MetasequoiaUpdateDriver>
@property(nonatomic) BOOL canCheckForUpdates;
@property(nonatomic) BOOL automaticallyChecksForUpdates;
@end

@implementation PreferencesFakeUpdateDriver
- (void)checkForUpdates:(id)sender
{
    (void)sender;
}
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

double RelativeLuminance(NSColor *color)
{
    NSColor *srgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    CGFloat alpha = 0.0;
    require(srgb != nil, "A candidate preview color could not be converted to sRGB.");
    [srgb getRed:&red green:&green blue:&blue alpha:&alpha];
    auto linearChannel = [](CGFloat component) {
        return component <= 0.03928 ? component / 12.92
                                    : std::pow((component + 0.055) / 1.055, 2.4);
    };
    return (0.2126 * linearChannel(red)) + (0.7152 * linearChannel(green)) +
           (0.0722 * linearChannel(blue));
}

double ContrastRatio(NSColor *first, NSColor *second)
{
    const double firstLuminance = RelativeLuminance(first);
    const double secondLuminance = RelativeLuminance(second);
    const double lighter = std::max(firstLuminance, secondLuminance);
    const double darker = std::min(firstLuminance, secondLuminance);
    return (lighter + 0.05) / (darker + 0.05);
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

NSInteger CountButtonsWithAction(NSView *view, SEL action)
{
    NSInteger count = 0;
    if ([view isKindOfClass:[NSButton class]] && ((NSButton *)view).action == action)
    {
        ++count;
    }
    for (NSView *subview in view.subviews)
    {
        count += CountButtonsWithAction(subview, action);
    }
    return count;
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
        [MetasequoiaPreferencesWindowController setCandidatePageShortcut:1];
        [MetasequoiaPreferencesWindowController setCandidateLearningEnabled:NO];
        [MetasequoiaPreferencesWindowController setEnglishInputMode:YES];
        [MetasequoiaPreferencesWindowController setInputModeShortcutEnabled:NO];
        [MetasequoiaPreferencesWindowController setFullWidthInputEnabled:NO];
        [MetasequoiaPreferencesWindowController setWubiAutoCommitUniqueEnabled:NO];
        [MetasequoiaPreferencesWindowController setStoredScheme:2];
        require([MetasequoiaPreferencesWindowController storedScheme] == 2,
                "The Wubi input scheme preference was not stored.");
        [MetasequoiaPreferencesWindowController setStoredScheme:99];
        require([MetasequoiaPreferencesWindowController storedScheme] == 0,
                "An unsupported input scheme preference was not normalized safely.");
        [MetasequoiaPreferencesWindowController setStoredScheme:2];
        require([MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 1,
                "The vertical candidate layout preference was not stored.");
        require([MetasequoiaPreferencesWindowController storedCandidatePageSize] == 5,
                "The five-candidate page-size preference was not stored.");
        require([MetasequoiaPreferencesWindowController storedCandidateFontSize] == 16,
                "The small candidate font-size preference was not stored.");
        require([MetasequoiaPreferencesWindowController storedCandidatePageShortcut] == 1,
                "The bracket candidate page shortcut preference was not stored.");
        require(![MetasequoiaPreferencesWindowController storedCandidateLearningEnabled],
                "The disabled candidate-learning preference was not stored.");
        require([MetasequoiaPreferencesWindowController storedEnglishInputMode],
                "The English input-mode state was not stored.");
        require(![MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled],
                "The disabled input-mode shortcut preference was not stored.");
        require(![MetasequoiaPreferencesWindowController storedFullWidthInputEnabled],
                "The disabled full-width input preference was not stored.");
        require(![MetasequoiaPreferencesWindowController storedWubiAutoCommitUniqueEnabled],
                "The disabled Wubi auto-commit preference was not stored.");

        PreferencesFakeUpdateDriver *updateDriver = [[PreferencesFakeUpdateDriver alloc] init];
        updateDriver.canCheckForUpdates = YES;
        updateDriver.automaticallyChecksForUpdates = YES;
        MetasequoiaUpdateController *updateController =
            [[MetasequoiaUpdateController alloc] initWithDriver:updateDriver activationHandler:^{}];
        MetasequoiaPreferencesWindowController *controller =
            [[MetasequoiaPreferencesWindowController alloc] initWithUpdateController:updateController];
        [controller refreshControls];
        NSButton *generalNavigationButton = FindButtonWithTitle(controller.window.contentView, @"键盘输入");
        NSButton *appearanceNavigationButton = FindButtonWithTitle(controller.window.contentView, @"外观");
        NSButton *dataNavigationButton = FindButtonWithTitle(controller.window.contentView, @"词库与数据");
        NSButton *updatesNavigationButton = FindButtonWithTitle(controller.window.contentView, @"更新与反馈");
        require(generalNavigationButton != nil && appearanceNavigationButton != nil && dataNavigationButton != nil &&
                    updatesNavigationButton != nil,
                "The settings window did not expose all sidebar destinations.");
        NSColor *generalTitleColor = [generalNavigationButton.attributedTitle attribute:NSForegroundColorAttributeName
                                                                                atIndex:0
                                                                         effectiveRange:nil];
        require([generalTitleColor isEqual:[NSColor whiteColor]],
                "The settings sidebar did not render navigation titles in white.");
        require([generalNavigationButton.contentTintColor isEqual:[NSColor whiteColor]] &&
                    ![generalNavigationButton.image isTemplate],
                "The settings sidebar did not render navigation symbols in white.");
        require(generalNavigationButton.state == NSControlStateValueOn &&
                    appearanceNavigationButton.state == NSControlStateValueOff &&
                    dataNavigationButton.state == NSControlStateValueOff &&
                    updatesNavigationButton.state == NSControlStateValueOff &&
                    [generalNavigationButton.accessibilityValue integerValue] == 1 &&
                    [appearanceNavigationButton.accessibilityValue integerValue] == 0,
                "The settings sidebar did not mark the initial page as selected.");
        NSView *generalPage = FindViewWithAccessibilityLabel(controller.window.contentView, @"键盘输入设置页");
        NSView *appearancePage = FindViewWithAccessibilityLabel(controller.window.contentView, @"外观设置页");
        NSView *dataPage = FindViewWithAccessibilityLabel(controller.window.contentView, @"词库与数据设置页");
        NSView *updatesPage = FindViewWithAccessibilityLabel(controller.window.contentView, @"更新与反馈设置页");
        require(generalPage != nil && appearancePage != nil && dataPage != nil && updatesPage != nil,
                "The settings window did not create all functional pages.");
        require(!generalPage.hidden && appearancePage.hidden && dataPage.hidden && updatesPage.hidden,
                "The settings window did not open on the keyboard-input page.");
        [appearanceNavigationButton performClick:nil];
        require(generalPage.hidden && !appearancePage.hidden && dataPage.hidden &&
                    appearanceNavigationButton.state == NSControlStateValueOn &&
                    generalNavigationButton.state == NSControlStateValueOff,
                "The appearance sidebar item did not reveal and select the appearance page.");
        [dataNavigationButton performClick:nil];
        require(generalPage.hidden && appearancePage.hidden && !dataPage.hidden &&
                    dataNavigationButton.state == NSControlStateValueOn,
                "The data sidebar item did not reveal and select the data page.");
        [updatesNavigationButton performClick:nil];
        require(generalPage.hidden && appearancePage.hidden && dataPage.hidden && !updatesPage.hidden &&
                    updatesNavigationButton.state == NSControlStateValueOn,
                "The updates sidebar item did not reveal and select the updates page.");
        [generalNavigationButton performClick:nil];

        NSView *candidatePageShortcutView =
            FindViewWithAccessibilityLabel(controller.window.contentView, @"候选翻页快捷键");
        require([candidatePageShortcutView isKindOfClass:[NSPopUpButton class]] &&
                    ((NSPopUpButton *)candidatePageShortcutView).indexOfSelectedItem == 1,
                "The keyboard-input page did not reflect the stored candidate page shortcut.");
        NSPopUpButton *candidatePageShortcutButton = (NSPopUpButton *)candidatePageShortcutView;
        require(candidatePageShortcutButton.numberOfItems == 3 &&
                    [[candidatePageShortcutButton itemTitleAtIndex:0] isEqualToString:@"- / ="] &&
                    [[candidatePageShortcutButton itemTitleAtIndex:1] isEqualToString:@"[ / ]"] &&
                    [[candidatePageShortcutButton itemTitleAtIndex:2] isEqualToString:@"Page Up / Page Down"],
                "The candidate page shortcut control did not contain all supported key pairs.");
        [candidatePageShortcutButton selectItemAtIndex:2];
        require([NSApp sendAction:candidatePageShortcutButton.action
                               to:candidatePageShortcutButton.target
                             from:candidatePageShortcutButton] &&
                    [MetasequoiaPreferencesWindowController storedCandidatePageShortcut] == 2,
                "The candidate page shortcut choice did not persist.");

        NSButton *quanpinSchemeButton = FindButtonWithTitle(controller.window.contentView, @"全拼输入");
        NSButton *shuangpinSchemeButton = FindButtonWithTitle(controller.window.contentView, @"小鹤双拼");
        NSButton *wubiSchemeButton = FindButtonWithTitle(controller.window.contentView, @"五笔输入（86 五笔）");
        NSButton *fullWidthButton = FindButtonWithTitle(controller.window.contentView, @"Option+Shift+H 切换全半角");
        require(quanpinSchemeButton != nil && shuangpinSchemeButton != nil && wubiSchemeButton != nil,
                "The keyboard-input page did not expose every supported input scheme.");
        require(fullWidthButton != nil && fullWidthButton.state == NSControlStateValueOff,
                "The keyboard-input page did not expose the full-width input toggle.");
        fullWidthButton.state = NSControlStateValueOn;
        require([NSApp sendAction:fullWidthButton.action to:fullWidthButton.target from:fullWidthButton] &&
                    [MetasequoiaPreferencesWindowController storedFullWidthInputEnabled],
                "The full-width input toggle did not persist its enabled state.");
        require(wubiSchemeButton.state == NSControlStateValueOn,
                "The keyboard-input page did not reflect the stored Wubi scheme.");
        [shuangpinSchemeButton performClick:nil];
        require([MetasequoiaPreferencesWindowController storedScheme] == 1,
                "The Shuangpin scheme choice did not persist its selection.");
        [wubiSchemeButton performClick:nil];
        require([MetasequoiaPreferencesWindowController storedScheme] == 2,
                "The Wubi scheme choice did not persist its selection.");
        NSView *wubiSettingsView =
            FindViewWithAccessibilityLabel(controller.window.contentView, @"五笔功能设置");
        require([wubiSettingsView isKindOfClass:[NSButton class]],
                "The keyboard-input page did not expose the Wubi settings entry.");
        [((NSButton *)wubiSettingsView) performClick:nil];
        NSView *wubiPage = FindViewWithAccessibilityLabel(controller.window.contentView, @"五笔设置页");
        require(wubiPage != nil && !wubiPage.hidden && generalPage.hidden,
                "The Wubi settings entry did not open its detail page.");
        NSView *wubiAutoCommitView =
            FindViewWithAccessibilityLabel(controller.window.contentView, @"四码唯一候选自动上屏");
        require([wubiAutoCommitView isKindOfClass:[NSButton class]] &&
                    ((NSButton *)wubiAutoCommitView).state == NSControlStateValueOff,
                "The Wubi detail page did not reflect the stored auto-commit preference.");
        NSButton *wubiAutoCommitButton = (NSButton *)wubiAutoCommitView;
        wubiAutoCommitButton.state = NSControlStateValueOn;
        require([NSApp sendAction:wubiAutoCommitButton.action
                               to:wubiAutoCommitButton.target
                             from:wubiAutoCommitButton] &&
                    [MetasequoiaPreferencesWindowController storedWubiAutoCommitUniqueEnabled],
                "The Wubi auto-commit option did not persist its enabled state.");
        NSButton *backToKeyboardButton = FindButtonWithTitle(controller.window.contentView, @"返回键盘输入");
        [backToKeyboardButton performClick:nil];
        require(!generalPage.hidden && wubiPage.hidden,
                "The Wubi detail page did not return to keyboard-input settings.");

        NSButton *websiteButton = FindButtonWithTitle(controller.window.contentView, @"msime.app");
        require(websiteButton != nil && websiteButton.action == @selector(openWebsite:) &&
                    websiteButton.target == controller,
                "The settings sidebar did not expose the canonical product website.");
        NSColor *websiteTitleColor = [websiteButton.attributedTitle attribute:NSForegroundColorAttributeName
                                                                      atIndex:0
                                                               effectiveRange:nil];
        require([websiteTitleColor isEqual:[NSColor whiteColor]],
                "The canonical website link was unreadable against the sidebar.");

        [controller.window.contentView layoutSubtreeIfNeeded];
        NSView *schemeCard = FindViewWithAccessibilityLabel(controller.window.contentView, @"输入方式卡片");
        NSView *behaviorCard = FindViewWithAccessibilityLabel(controller.window.contentView, @"中英文状态切换卡片");
        NSView *candidatePageShortcutCard =
            FindViewWithAccessibilityLabel(controller.window.contentView, @"候选翻页快捷键卡片");
        NSView *learningCard = FindViewWithAccessibilityLabel(controller.window.contentView, @"候选与学习卡片");
        NSView *softwareUpdateCard =
            FindViewWithAccessibilityLabel(controller.window.contentView, @"软件更新卡片");
        NSView *feedbackCard = FindViewWithAccessibilityLabel(controller.window.contentView, @"反馈与帮助卡片");
        require(schemeCard.frame.size.width == behaviorCard.frame.size.width &&
                    schemeCard.frame.size.width == candidatePageShortcutCard.frame.size.width &&
                    schemeCard.frame.size.width == learningCard.frame.size.width &&
                    schemeCard.frame.size.width == softwareUpdateCard.frame.size.width &&
                    schemeCard.frame.size.width == feedbackCard.frame.size.width,
                "The settings cards did not consistently fill the content width.");
        NSRect candidatePageShortcutCardRect =
            [generalPage convertRect:candidatePageShortcutCard.bounds fromView:candidatePageShortcutCard];
        require(NSMaxY(candidatePageShortcutCardRect) <= NSMaxY(generalPage.bounds),
                "The candidate page shortcut card overflowed the keyboard-input page.");
        NSRect feedbackCardRect = [updatesPage convertRect:feedbackCard.bounds fromView:feedbackCard];
        require(NSMaxY(feedbackCardRect) <= NSMaxY(updatesPage.bounds),
                "The feedback card overflowed the updates page.");

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

        NSView *candidatePreview =
            FindViewWithAccessibilityLabel(controller.window.contentView, @"候选窗口预览");
        NSView *appearanceCard =
            FindViewWithAccessibilityLabel(controller.window.contentView, @"候选窗口卡片");
        require(candidatePreview != nil,
                "The appearance page did not expose a candidate-window preview.");
        require(candidatePreview.frame.size.width == appearanceCard.frame.size.width,
                "The candidate preview did not fill the appearance-page content width.");
        NSRect appearanceCardRect = [appearancePage convertRect:appearanceCard.bounds fromView:appearanceCard];
        require(NSMaxY(appearanceCardRect) <= NSMaxY(appearancePage.bounds),
                "The appearance controls overflowed the settings page below the preview.");
        require([candidatePreview.accessibilityValue isEqualToString:@"纵向列表，5 个候选，16 pt"],
                "The candidate preview did not reflect the stored appearance settings.");
        NSAppearance *darkAppearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        __block NSColor *darkCanvasColor = nil;
        __block NSColor *darkPanelColor = nil;
        __block NSColor *darkAccentColor = nil;
        [darkAppearance performAsCurrentDrawingAppearance:^{
            darkCanvasColor = [[NSColor controlBackgroundColor]
                colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
            darkPanelColor = [[candidatePreview valueForKey:@"previewPanelFillColor"]
                colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
            darkAccentColor = [[candidatePreview valueForKey:@"previewAccentColor"]
                colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
        }];
        require(std::abs(RelativeLuminance(darkPanelColor) - RelativeLuminance(darkCanvasColor)) >= 0.01,
                "The candidate panel collapsed into the preview canvas in Dark Aqua.");
        require(ContrastRatio(darkAccentColor, darkPanelColor) >= 4.5,
                "The preview preedit color did not remain readable in Dark Aqua.");

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
        NSView *versionView = FindViewWithAccessibilityLabel(controller.window.contentView, @"当前版本");
        require([versionView isKindOfClass:[NSTextField class]] &&
                    ((NSTextField *)versionView).stringValue.length > 0,
                "The updates page did not expose the installed version.");
        NSView *automaticUpdatesView =
            FindViewWithAccessibilityLabel(controller.window.contentView, @"自动更新状态");
        require([automaticUpdatesView isKindOfClass:[NSTextField class]] &&
                    [((NSTextField *)automaticUpdatesView).stringValue isEqualToString:@"已开启自动检查"],
                "The updates page did not show the enabled automatic-check state.");
        updateDriver.automaticallyChecksForUpdates = NO;
        [controller refreshUpdateControls];
        require([((NSTextField *)automaticUpdatesView).stringValue isEqualToString:@"自动检查已关闭"],
                "The updates page did not refresh the disabled automatic-check state.");
        NSView *checkNowView = FindViewWithAccessibilityLabel(controller.window.contentView, @"立即检查更新");
        require([checkNowView isKindOfClass:[NSButton class]] &&
                    [((NSButton *)checkNowView).title containsString:@"检查更新"] &&
                    [((NSButton *)checkNowView).accessibilityHelp containsString:@"msime.app"] &&
                    ((NSButton *)checkNowView).action == @selector(checkForUpdates:) &&
                    ((NSButton *)checkNowView).target == controller,
                "The updates page did not expose an in-place update action.");
        require(CountButtonsWithAction(controller.window.contentView, @selector(checkForUpdates:)) == 1,
                "The settings window exposed duplicate software-update actions.");
        NSView *feedbackView = FindViewWithAccessibilityLabel(controller.window.contentView, @"提交反馈");
        require([feedbackView isKindOfClass:[NSButton class]] &&
                    ((NSButton *)feedbackView).action == @selector(openFeedback:) &&
                    ((NSButton *)feedbackView).target == controller,
                "The updates page did not expose a feedback action.");
        NSColor *feedbackTitleColor = [((NSButton *)feedbackView).attributedTitle
            attribute:NSForegroundColorAttributeName
              atIndex:0
       effectiveRange:nil];
        require([feedbackTitleColor isEqual:[NSColor linkColor]],
                "The updates-page actions did not remain visually distinct from disabled controls.");

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
        require([candidatePreview.accessibilityValue isEqualToString:@"横向排列，7 个候选，20 pt"],
                "The candidate preview did not update after the appearance controls changed.");

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
        [MetasequoiaPreferencesWindowController setCandidatePageShortcut:2];
        [MetasequoiaPreferencesWindowController setCandidateLearningEnabled:NO];
        [MetasequoiaPreferencesWindowController setInputModeShortcutEnabled:NO];
        [MetasequoiaPreferencesWindowController setFullWidthInputEnabled:YES];
        [MetasequoiaPreferencesWindowController setEnglishInputMode:YES];
        [MetasequoiaPreferencesWindowController setWubiAutoCommitUniqueEnabled:YES];
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
                    [MetasequoiaPreferencesWindowController storedCandidatePageShortcut] == 0 &&
                    [MetasequoiaPreferencesWindowController storedCandidateLearningEnabled] &&
                    [MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled] &&
                    ![MetasequoiaPreferencesWindowController storedFullWidthInputEnabled] &&
                    ![MetasequoiaPreferencesWindowController storedWubiAutoCommitUniqueEnabled],
                "Restoring defaults did not restore every visible setting.");
        NSArray<NSString *> *preferenceKeys = @[
            @"MetasequoiaImeInputScheme",
            @"MetasequoiaImeQuanpinAutocorrect",
            @"MetasequoiaImeHelpcodeEnabled",
            @"MetasequoiaImeChinesePunctuation",
            @"MetasequoiaImeCandidatePanelStyle",
            @"MetasequoiaImeCandidatePageSize",
            @"MetasequoiaImeCandidateFontSize",
            @"MetasequoiaImeCandidatePageShortcut",
            @"MetasequoiaImeCandidateLearning",
            @"MetasequoiaImeInputModeShortcutEnabled",
            @"MetasequoiaImeFullWidthInputEnabled",
            @"MetasequoiaImeWubiAutoCommitUnique",
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
            [[MetasequoiaPreferencesWindowController alloc] initWithUpdateController:updateController];
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
