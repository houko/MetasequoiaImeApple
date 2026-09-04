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
@property(nonatomic) BOOL updateCheckStarted;
@property(nonatomic) BOOL chineseSelected;
@property(nonatomic) BOOL englishSelected;
@end

@implementation PreferencesTarget
- (void)showPreferences:(id)sender
{
    (void)sender;
    self.preferencesShown = YES;
}

- (void)checkForUpdates:(id)sender
{
    (void)sender;
    self.updateCheckStarted = YES;
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

        require(menu.numberOfItems == 5, "The input menu did not contain input modes, update, and settings actions.");
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

        NSMenuItem *updateItem = [menu itemAtIndex:3];
        require([updateItem.title isEqualToString:@"检查更新…"], "The update action title was incorrect.");
        require(updateItem.action == @selector(checkForUpdates:), "The update action used the wrong selector.");
        require(updateItem.target == target && updateItem.enabled, "The update action was not enabled for its target.");

        NSMenuItem *settingsItem = [menu itemAtIndex:4];
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
        require(target.updateCheckStarted, "The update action did not invoke checkForUpdates:.");
        [menu performActionForItemAtIndex:4];
        require(target.preferencesShown, "The settings action did not invoke showPreferences:.");
    }
    return 0;
}
