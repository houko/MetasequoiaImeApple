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
        [MetasequoiaPreferencesWindowController setCandidatePageSize:5];
        [MetasequoiaPreferencesWindowController setCandidateLearningEnabled:NO];
        [MetasequoiaPreferencesWindowController setEnglishInputMode:YES];
        require([MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 1,
                "The vertical candidate layout preference was not stored.");
        require([MetasequoiaPreferencesWindowController storedCandidatePageSize] == 5,
                "The five-candidate page-size preference was not stored.");
        require(![MetasequoiaPreferencesWindowController storedCandidateLearningEnabled],
                "The disabled candidate-learning preference was not stored.");
        require([MetasequoiaPreferencesWindowController storedEnglishInputMode],
                "The English input-mode state was not stored.");

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

        NSView *learningView = FindViewWithAccessibilityLabel(controller.window.contentView, @"记住候选词频");
        require([learningView isKindOfClass:[NSButton class]],
                "The settings window did not expose the candidate-learning control.");
        NSButton *learningButton = (NSButton *)learningView;
        require(learningButton.state == NSControlStateValueOff,
                "The candidate-learning control did not reflect the stored disabled value.");

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

        learningButton.state = NSControlStateValueOn;
        require([NSApp sendAction:learningButton.action to:learningButton.target from:learningButton],
                "The candidate-learning control did not dispatch its action.");
        require([MetasequoiaPreferencesWindowController storedCandidateLearningEnabled],
                "The candidate-learning control did not store the selected value.");

        [MetasequoiaPreferencesWindowController setCandidatePanelStyle:99];
        require([MetasequoiaPreferencesWindowController storedCandidatePanelStyle] == 0,
                "An unsupported candidate layout preference was not normalized safely.");
        [MetasequoiaPreferencesWindowController setCandidatePageSize:99];
        require([MetasequoiaPreferencesWindowController storedCandidatePageSize] == 9,
                "An unsupported candidate page size was not normalized safely.");
        [MetasequoiaPreferencesWindowController setEnglishInputMode:NO];
        require(![MetasequoiaPreferencesWindowController storedEnglishInputMode],
                "The Chinese input-mode state was not stored.");
    }
    return 0;
}
