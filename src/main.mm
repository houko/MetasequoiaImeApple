#import <AppKit/AppKit.h>
#import <InputMethodKit/InputMethodKit.h>

#import "InputSourceRegistration.h"
#import "PreferencesWindowController.h"
#import "UpdateChecker.h"

#include <cstdio>

int main(int argc, const char *argv[])
{
    @autoreleasepool
    {
        if (MetasequoiaShouldRegisterInputSource(argc, argv))
        {
            NSURL *bundleURL = NSBundle.mainBundle.bundleURL;
            NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
            OSStatus status = MetasequoiaRegisterAndEnableInputSources(
                bundleURL, bundleIdentifier, TISRegisterInputSource, TISCreateInputSourceList,
                TISGetInputSourceProperty, TISEnableInputSource);
            if (status != noErr)
            {
                std::fprintf(stderr, "Input source registration or enable failed with OSStatus %d.\n", status);
                return 1;
            }
            std::fprintf(stdout, "Registered and enabled %s\n", bundleURL.fileSystemRepresentation);
            return 0;
        }

        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        if (MetasequoiaShouldShowPreferences(argc, argv))
        {
            id closeObserver = [[NSNotificationCenter defaultCenter]
                addObserverForName:MetasequoiaStandalonePreferencesDidCloseNotification
                            object:nil
                             queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification *notification) {
                            (void)notification;
                            [application terminate:nil];
                        }];
            [[MetasequoiaPreferencesWindowController sharedController] showAndActivateForStandaloneLaunch];
            [application run];
            [[NSNotificationCenter defaultCenter] removeObserver:closeObserver];
            return 0;
        }

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
