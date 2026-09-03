#import <AppKit/AppKit.h>
#import <InputMethodKit/InputMethodKit.h>

int main(int argc, const char *argv[])
{
    (void)argc;
    (void)argv;
    @autoreleasepool
    {
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
        [application run];
        (void)server;
    }
    return 0;
}
