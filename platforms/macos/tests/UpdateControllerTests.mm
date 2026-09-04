#import "../src/UpdateController.h"

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

@interface FakeUpdateDriver : NSObject <MetasequoiaUpdateDriver>
@property(nonatomic) BOOL canCheckForUpdates;
@property(nonatomic) BOOL automaticallyChecksForUpdates;
@property(nonatomic) BOOL checked;
@end

@implementation FakeUpdateDriver
- (void)checkForUpdates:(id)sender
{
    (void)sender;
    self.checked = YES;
}
@end

int main()
{
    @autoreleasepool
    {
        __block BOOL activated = NO;
        FakeUpdateDriver *driver = [[FakeUpdateDriver alloc] init];
        driver.canCheckForUpdates = YES;
        driver.automaticallyChecksForUpdates = YES;
        MetasequoiaUpdateController *controller =
            [[MetasequoiaUpdateController alloc] initWithDriver:driver
                                             activationHandler:^{
                                                 activated = YES;
                                             }];

        require(controller.canCheckForUpdates, "The controller did not expose the Sparkle driver's readiness.");
        require(controller.automaticallyChecksForUpdates,
                "The controller did not expose Sparkle's automatic-check state.");
        [controller checkForUpdates:nil];
        require(activated, "A manual update check did not activate the accessory application UI.");
        require(driver.checked, "A manual update check was not forwarded to Sparkle.");

        driver.canCheckForUpdates = NO;
        require(!controller.canCheckForUpdates, "The controller cached an obsolete readiness state.");
        driver.automaticallyChecksForUpdates = NO;
        require(!controller.automaticallyChecksForUpdates,
                "The controller cached an obsolete automatic-check state.");
    }
    return 0;
}
