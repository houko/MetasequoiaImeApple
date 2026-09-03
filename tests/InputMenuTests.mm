#import "../src/InputMenu.h"

#import <AppKit/AppKit.h>

#include <stdexcept>

namespace
{
void require(bool condition, const char *message)
{
    if (!condition)
    {
        throw std::runtime_error(message);
    }
}
} // namespace

@interface PreferencesTarget : NSObject
@property(nonatomic) BOOL preferencesShown;
@property(nonatomic) BOOL chineseSelected;
@property(nonatomic) BOOL englishSelected;
@end

@implementation PreferencesTarget
- (void)showPreferences:(id)sender
{
    (void)sender;
    self.preferencesShown = YES;
}

- (void)selectChineseMode:(id)sender
{
    (void)sender;
    self.chineseSelected = YES;
}

- (void)selectEnglishMode:(id)sender
{
    (void)sender;
    self.englishSelected = YES;
}
@end

int main()
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        PreferencesTarget *target = [[PreferencesTarget alloc] init];
        NSMenu *menu = CreateMetasequoiaInputMenu(target, NO);

        require(menu.numberOfItems == 4, "The input menu did not contain both input modes and settings.");
        NSMenuItem *chineseItem = [menu itemAtIndex:0];
        NSMenuItem *englishItem = [menu itemAtIndex:1];
        require([chineseItem.title isEqualToString:@"中文输入"] &&
                    chineseItem.action == @selector(selectChineseMode:) && chineseItem.target == target &&
                    chineseItem.state == NSControlStateValueOn,
                "The Chinese input mode was not represented as selected.");
        require([englishItem.title isEqualToString:@"英文输入"] &&
                    englishItem.action == @selector(selectEnglishMode:) && englishItem.target == target &&
                    englishItem.state == NSControlStateValueOff,
                "The English input mode was not represented as unselected.");
        require([menu itemAtIndex:2].separatorItem, "The input modes were not separated from settings.");

        NSMenuItem *settingsItem = [menu itemAtIndex:3];
        require([settingsItem.title isEqualToString:@"水杉输入法设置…"], "The settings action title was incorrect.");
        require(settingsItem.action == @selector(showPreferences:), "The settings action used the wrong selector.");
        require(settingsItem.target == target, "The settings action did not target the input controller.");
        require(settingsItem.enabled, "The settings action was unexpectedly disabled.");

        [menu performActionForItemAtIndex:1];
        require(target.englishSelected, "The English input mode action was not dispatched.");
        NSMenu *englishMenu = CreateMetasequoiaInputMenu(target, YES);
        require([englishMenu itemAtIndex:0].state == NSControlStateValueOff &&
                    [englishMenu itemAtIndex:1].state == NSControlStateValueOn,
                "The English input mode was not represented as selected.");
        [englishMenu performActionForItemAtIndex:0];
        require(target.chineseSelected, "The Chinese input mode action was not dispatched.");

        [menu performActionForItemAtIndex:3];
        require(target.preferencesShown, "The settings action did not invoke showPreferences:.");
    }
    return 0;
}
