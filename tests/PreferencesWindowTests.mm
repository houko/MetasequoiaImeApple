#import "../src/PreferencesWindowController.h"

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
} // namespace

int main()
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        [MetasequoiaPreferencesWindowController setCandidatePanelStyle:1];
        require([MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 1,
                "The vertical candidate layout preference was not stored.");

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

        [styleButton selectItemAtIndex:0];
        require([NSApp sendAction:styleButton.action to:styleButton.target from:styleButton],
                "The candidate layout control did not dispatch its action.");
        require([MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 0,
                "The candidate layout control did not store the selected horizontal layout.");

        [MetasequoiaPreferencesWindowController setCandidatePanelStyle:99];
        require([MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 0,
                "An unsupported candidate layout preference was not normalized safely.");

    }
    return 0;
}
