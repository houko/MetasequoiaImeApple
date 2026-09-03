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
@end

@implementation PreferencesTarget
- (void)showPreferences:(id)sender
{
    (void)sender;
    self.preferencesShown = YES;
}
@end

int main()
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        PreferencesTarget *target = [[PreferencesTarget alloc] init];
        NSMenu *menu = CreateMetasequoiaInputMenu(target);

        require(menu.numberOfItems == 1, "The input menu did not contain exactly one settings action.");
        NSMenuItem *settingsItem = [menu itemAtIndex:0];
        require([settingsItem.title isEqualToString:@"水杉输入法设置…"], "The settings action title was incorrect.");
        require(settingsItem.action == @selector(showPreferences:), "The settings action used the wrong selector.");
        require(settingsItem.target == target, "The settings action did not target the input controller.");
        require(settingsItem.enabled, "The settings action was unexpectedly disabled.");

        [menu performActionForItemAtIndex:0];
        require(target.preferencesShown, "The settings action did not invoke showPreferences:.");
    }
    return 0;
}
