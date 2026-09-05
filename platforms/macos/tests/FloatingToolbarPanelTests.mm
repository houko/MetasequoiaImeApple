#import "../src/FloatingToolbarPanel.h"

#import <AppKit/AppKit.h>

#include <cmath>
#include <stdexcept>

@interface FloatingToolbarTestDelegate : NSObject <MetasequoiaFloatingToolbarDelegate>
@property(nonatomic) BOOL toggledInputMode;
@property(nonatomic) BOOL toggledPunctuation;
@property(nonatomic) BOOL toggledFullWidth;
@property(nonatomic) BOOL openedSettings;
@property(nonatomic, strong) MetasequoiaFloatingToolbarPanel *ownedPanel;
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

- (void)floatingToolbarDidRequestOpenSettings:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    self.openedSettings = YES;
}

- (void)dealloc
{
    // Mirrors MetasequoiaInputController, which releases the toolbar while it is being deallocated.
    [self.ownedPanel deactivateForDelegate:self];
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
        NSRect defaultFrame = MetasequoiaFloatingToolbarFrame(NSMakeRect(0.0, 0.0, 220.0, 44.0),
                                                               visibleFrame,
                                                               NO);
        require(NearlyEqual(NSMaxX(defaultFrame), NSMaxX(visibleFrame) - 20.0) &&
                    NearlyEqual(NSMinY(defaultFrame), NSMinY(visibleFrame) + 20.0),
                "The floating toolbar did not default to the screen's lower-right safe area.");

        NSRect restoredFrame = MetasequoiaFloatingToolbarFrame(NSMakeRect(-300.0, 2000.0, 220.0, 44.0),
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
        [panel updateEnglishInputMode:NO chinesePunctuationEnabled:YES fullWidthEnabled:NO];

        NSButton *inputModeButton = FindButton(panel.contentView, @"MetasequoiaFloatingToolbarInputMode");
        NSButton *punctuationButton = FindButton(panel.contentView, @"MetasequoiaFloatingToolbarPunctuation");
        NSButton *fullWidthButton = FindButton(panel.contentView, @"MetasequoiaFloatingToolbarFullWidth");
        NSButton *settingsButton = FindButton(panel.contentView, @"MetasequoiaFloatingToolbarSettings");
        require(inputModeButton != nil && punctuationButton != nil && fullWidthButton != nil &&
                    settingsButton != nil,
                "The floating toolbar did not expose all four supported actions.");
        require([inputModeButton.title isEqualToString:@"中"] &&
                    [inputModeButton.accessibilityLabel isEqualToString:@"切换到英文输入"] &&
                    [punctuationButton.title isEqualToString:@"。"] &&
                    [fullWidthButton.title isEqualToString:@"半"],
                "The floating toolbar did not reflect the active input states.");

        [inputModeButton performClick:nil];
        [punctuationButton performClick:nil];
        [fullWidthButton performClick:nil];
        [settingsButton performClick:nil];
        require(firstDelegate.toggledInputMode && firstDelegate.toggledPunctuation &&
                    firstDelegate.toggledFullWidth && firstDelegate.openedSettings,
                "The floating toolbar did not forward every action to its active input controller.");

        [panel updateEnglishInputMode:YES chinesePunctuationEnabled:NO fullWidthEnabled:YES];
        require([inputModeButton.title isEqualToString:@"英"] && [punctuationButton.title isEqualToString:@"."] &&
                    [fullWidthButton.title isEqualToString:@"全"],
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
        NSRect screenFrame = (panel.screen != nil ? panel.screen : NSScreen.mainScreen).visibleFrame;
        NSRect draggedFrame = panel.frame;
        draggedFrame.origin = NSMakePoint(NSMinX(screenFrame) + 2.0, NSMinY(screenFrame) + 2.0);
        [panel setFrame:draggedFrame display:NO];
        [panel setVisible:YES forDelegate:secondDelegate];
        require(NSEqualRects(panel.frame, draggedFrame),
                "Refreshing a visible floating toolbar moved it away from where the user placed it.");
        require([inputModeButton.toolTip isEqualToString:inputModeButton.accessibilityLabel] &&
                    [settingsButton.toolTip isEqualToString:settingsButton.accessibilityLabel],
                "The floating toolbar buttons did not expose their action as a tooltip.");
        [panel deactivateForDelegate:secondDelegate];
        require(!panel.visible && panel.toolbarDelegate == nil,
                "The active input controller did not release and hide the floating toolbar.");
        @autoreleasepool
        {
            FloatingToolbarTestDelegate *dyingDelegate = [[FloatingToolbarTestDelegate alloc] init];
            dyingDelegate.ownedPanel = panel;
            [panel activateForDelegate:dyingDelegate visible:YES];
            require(panel.visible && panel.toolbarDelegate == dyingDelegate,
                    "The floating toolbar did not accept a new input controller.");
        }
        require(!panel.visible && panel.toolbarDelegate == nil,
                "A deallocated input controller left the floating toolbar on screen.");

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *savedFrameKey = @"NSWindow Frame MetasequoiaFloatingToolbarFrame";
        id previousSavedFrame = [defaults objectForKey:savedFrameKey];
        NSScreen *restoreScreen = panel.screen != nil ? panel.screen : NSScreen.mainScreen;
        NSRect restoreVisibleFrame =
            restoreScreen != nil ? restoreScreen.visibleFrame : NSMakeRect(0.0, 0.0, 1200.0, 800.0);
        NSRect savedFrame = NSMakeRect(std::round(NSMaxX(restoreVisibleFrame) - 220.0 - 60.0),
                                       std::round(NSMaxY(restoreVisibleFrame) - 44.0 - 60.0),
                                       220.0,
                                       44.0);
        // Serializing through a panel writes exactly the string AppKit itself stores for that frame, so the test does not depend on the private layout of the saved-frame default.
        MetasequoiaFloatingToolbarPanel *savingPanel = [[MetasequoiaFloatingToolbarPanel alloc] init];
        [savingPanel setFrame:savedFrame display:NO];
        [defaults setObject:[savingPanel stringWithSavedFrame] forKey:savedFrameKey];

        MetasequoiaFloatingToolbarPanel *restoredPanel = [[MetasequoiaFloatingToolbarPanel alloc] init];
        FloatingToolbarTestDelegate *restoredDelegate = [[FloatingToolbarTestDelegate alloc] init];
        [restoredPanel activateForDelegate:restoredDelegate visible:YES];
        require(NearlyEqual(NSMinX(restoredPanel.frame), NSMinX(savedFrame)) &&
                    NearlyEqual(NSMinY(restoredPanel.frame), NSMinY(savedFrame)),
                "A relaunched floating toolbar did not reopen at the position saved by the previous session.");
        [restoredPanel deactivateForDelegate:restoredDelegate];

        if (previousSavedFrame != nil)
        {
            [defaults setObject:previousSavedFrame forKey:savedFrameKey];
        }
        else
        {
            [defaults removeObjectForKey:savedFrameKey];
        }
    }
    return 0;
}
