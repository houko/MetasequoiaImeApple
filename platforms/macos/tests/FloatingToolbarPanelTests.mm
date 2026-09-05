#import "../src/FloatingToolbarPanel.h"

#import <AppKit/AppKit.h>

#include <cmath>
#include <stdexcept>

@interface FloatingToolbarTestDelegate : NSObject <MetasequoiaFloatingToolbarDelegate>
@property(nonatomic) BOOL toggledInputMode;
@property(nonatomic) BOOL toggledPunctuation;
@property(nonatomic) BOOL toggledFullWidth;
@property(nonatomic) BOOL toggledTraditionalOutput;
@property(nonatomic) BOOL openedSettings;
@end

@implementation FloatingToolbarTestDelegate
- (void)floatingToolbarDidRequestToggleInputMode:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    self.toggledInputMode = YES;
}

- (void)floatingToolbarDidRequestTogglePunctuation:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    self.toggledPunctuation = YES;
}

- (void)floatingToolbarDidRequestToggleFullWidth:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    self.toggledFullWidth = YES;
}

- (void)floatingToolbarDidRequestToggleTraditionalOutput:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    self.toggledTraditionalOutput = YES;
}

- (void)floatingToolbarDidRequestOpenSettings:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    self.openedSettings = YES;
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

bool NearlyEqual(CGFloat first, CGFloat second)
{
    return std::abs(first - second) < 0.01;
}

NSButton *FindButton(NSView *view, NSString *identifier)
{
    if ([view isKindOfClass:[NSButton class]] && [view.accessibilityIdentifier isEqualToString:identifier])
    {
        return (NSButton *)view;
    }
    for (NSView *subview in view.subviews)
    {
        NSButton *match = FindButton(subview, identifier);
        if (match != nil)
        {
            return match;
        }
    }
    return nil;
}
}

int main()
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        NSRect visibleFrame = NSMakeRect(100.0, 80.0, 1200.0, 800.0);
        NSRect defaultFrame = MetasequoiaFloatingToolbarFrame(NSMakeRect(0.0, 0.0, 272.0, 44.0),
                                                               visibleFrame,
                                                               NO);
        require(NearlyEqual(NSWidth(defaultFrame), 272.0) && NearlyEqual(NSHeight(defaultFrame), 44.0) &&
                    NearlyEqual(NSMaxX(defaultFrame), NSMaxX(visibleFrame) - 20.0) &&
                    NearlyEqual(NSMinY(defaultFrame), NSMinY(visibleFrame) + 20.0),
                "The floating toolbar did not use its expected size and lower-right safe area.");

        NSRect restoredFrame = MetasequoiaFloatingToolbarFrame(NSMakeRect(-300.0, 2000.0, 272.0, 44.0),
                                                                visibleFrame,
                                                                YES);
        require(NSMinX(restoredFrame) >= NSMinX(visibleFrame) + 12.0 &&
                    NSMaxX(restoredFrame) <= NSMaxX(visibleFrame) - 12.0 &&
                    NSMinY(restoredFrame) >= NSMinY(visibleFrame) + 12.0 &&
                    NSMaxY(restoredFrame) <= NSMaxY(visibleFrame) - 12.0,
                "A restored floating-toolbar frame was not clamped into the visible screen.");

        MetasequoiaFloatingToolbarPanel *panel = [[MetasequoiaFloatingToolbarPanel alloc] init];
        require((panel.styleMask & NSWindowStyleMaskNonactivatingPanel) != 0,
                "The floating toolbar would activate the input-method process when clicked.");
        require(panel.level == NSStatusWindowLevel && panel.movableByWindowBackground && panel.hasShadow &&
                    !panel.opaque,
                "The floating toolbar did not use the expected native floating-panel behavior.");
        require([panel.frameAutosaveName isEqualToString:@"MetasequoiaFloatingToolbarFrame"],
                "The floating toolbar did not remember its dragged position.");

        FloatingToolbarTestDelegate *firstDelegate = [[FloatingToolbarTestDelegate alloc] init];
        FloatingToolbarTestDelegate *secondDelegate = [[FloatingToolbarTestDelegate alloc] init];
        panel.toolbarDelegate = firstDelegate;
        [panel updateEnglishInputMode:NO
            chinesePunctuationEnabled:YES
                     fullWidthEnabled:NO
        traditionalChineseOutputEnabled:NO];

        NSButton *inputModeButton = FindButton(panel.contentView, @"MetasequoiaFloatingToolbarInputMode");
        NSButton *punctuationButton = FindButton(panel.contentView, @"MetasequoiaFloatingToolbarPunctuation");
        NSButton *fullWidthButton = FindButton(panel.contentView, @"MetasequoiaFloatingToolbarFullWidth");
        NSButton *traditionalOutputButton =
            FindButton(panel.contentView, @"MetasequoiaFloatingToolbarTraditionalOutput");
        NSButton *settingsButton = FindButton(panel.contentView, @"MetasequoiaFloatingToolbarSettings");
        require(inputModeButton != nil && punctuationButton != nil && fullWidthButton != nil &&
                    traditionalOutputButton != nil && settingsButton != nil,
                "The floating toolbar did not expose all five supported actions.");
        require([inputModeButton.title isEqualToString:@"中"] &&
                    [inputModeButton.accessibilityLabel isEqualToString:@"切换到英文输入"] &&
                    [punctuationButton.title isEqualToString:@"。"] &&
                    [fullWidthButton.title isEqualToString:@"半"] &&
                    [traditionalOutputButton.title isEqualToString:@"简"] &&
                    [traditionalOutputButton.accessibilityLabel isEqualToString:@"切换到繁体输出"],
                "The floating toolbar did not reflect the active input states.");

        [inputModeButton performClick:nil];
        [punctuationButton performClick:nil];
        [fullWidthButton performClick:nil];
        [traditionalOutputButton performClick:nil];
        [settingsButton performClick:nil];
        require(firstDelegate.toggledInputMode && firstDelegate.toggledPunctuation &&
                    firstDelegate.toggledFullWidth && firstDelegate.toggledTraditionalOutput &&
                    firstDelegate.openedSettings,
                "The floating toolbar did not forward every action to its active input controller.");

        [panel updateEnglishInputMode:YES
            chinesePunctuationEnabled:NO
                     fullWidthEnabled:YES
        traditionalChineseOutputEnabled:YES];
        require([inputModeButton.title isEqualToString:@"英"] && [punctuationButton.title isEqualToString:@"."] &&
                    [fullWidthButton.title isEqualToString:@"全"] &&
                    [traditionalOutputButton.title isEqualToString:@"繁"],
                "The floating toolbar did not refresh after input preferences changed.");

        [panel activateForDelegate:firstDelegate visible:YES];
        [panel activateForDelegate:secondDelegate visible:YES];
        [panel setVisible:NO forDelegate:firstDelegate];
        require(panel.visible && panel.toolbarDelegate == secondDelegate,
                "An old input controller changed the toolbar owned by the newly active controller.");
        [panel setVisible:NO forDelegate:secondDelegate];
        require(!panel.visible && panel.toolbarDelegate == secondDelegate,
                "Hiding the toolbar released its active input controller.");
        [panel setVisible:YES forDelegate:secondDelegate];
        require(panel.visible && panel.toolbarDelegate == secondDelegate,
                "The active input controller could not show its toolbar again.");
        [panel deactivateForDelegate:secondDelegate];
        require(!panel.visible && panel.toolbarDelegate == nil,
                "The active input controller did not release and hide the floating toolbar.");
    }
    return 0;
}
