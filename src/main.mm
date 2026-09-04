#import <AppKit/AppKit.h>
#import <InputMethodKit/InputMethodKit.h>

#import "InputSourceRegistration.h"
#import "UpdateChecker.h"

#include <cstdio>

int main(int argc, const char *argv[])
{
    @autoreleasepool
    {
        if (MetasequoiaShouldRegisterInputSource(argc, argv))
        {
            NSURL *bundleURL = NSBundle.mainBundle.bundleURL;
            OSStatus status = MetasequoiaRegisterInputSource(bundleURL, TISRegisterInputSource);
            if (status != noErr)
            {
                std::fprintf(stderr, "TISRegisterInputSource failed with OSStatus %d.\n", status);
                return 1;
            }
            std::fprintf(stdout, "Registered %s\n", bundleURL.fileSystemRepresentation);
            return 0;
        }

        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];

        NSBundle *bundle = [NSBundle mainBundle];
        NSString *connectionName = [bundle objectForInfoDictionaryKey:@"InputMethodConnectionName"];
        NSString *bundleIdentifier = bundle.bundleIdentifier;
        IMKServer *server = [[IMKServer alloc] initWithName:connectionName bundleIdentifier:bundleIdentifier];
        if (server == nil)
        {
            NSLog(@"Failed to initialize the Metasequoia InputMethodKit server.");
            return 1;
        }
        [[MetasequoiaUpdateChecker sharedChecker] checkForUpdatesIfNeeded];
        [application run];
        (void)server;
    }
    return 0;
}
