#import "../src/InputSourceRegistration.h"

#include <stdexcept>

namespace
{
NSURL *registeredURL = nil;

void require(bool condition, const char *message)
{
    if (!condition)
    {
        throw std::runtime_error(message);
    }
}

OSStatus CaptureRegistration(CFURLRef location)
{
    registeredURL = (__bridge NSURL *)location;
    return noErr;
}

OSStatus RejectRegistration(CFURLRef location)
{
    (void)location;
    return -50;
}
} // namespace

int main()
{
    @autoreleasepool
    {
        const char *registrationArguments[] = {"MetasequoiaIME", "--register-input-source"};
        const char *ordinaryArguments[] = {"MetasequoiaIME"};
        const char *unknownArguments[] = {"MetasequoiaIME", "--unknown"};
        require(MetasequoiaShouldRegisterInputSource(2, registrationArguments),
                "The registration command was not recognized.");
        require(!MetasequoiaShouldRegisterInputSource(1, ordinaryArguments),
                "Ordinary InputMethodKit startup was treated as registration.");
        require(!MetasequoiaShouldRegisterInputSource(2, unknownArguments),
                "An unknown command was treated as registration.");

        NSURL *bundleURL = [NSURL fileURLWithPath:@"/tmp/MetasequoiaIME.app" isDirectory:YES];
        require(MetasequoiaRegisterInputSource(bundleURL, CaptureRegistration) == noErr,
                "A successful registration callback was reported as failed.");
        require([registeredURL isEqual:bundleURL], "Registration did not receive the installed bundle URL.");
        require(MetasequoiaRegisterInputSource(bundleURL, RejectRegistration) == -50,
                "A registration callback failure was not preserved.");
        require(MetasequoiaRegisterInputSource(nil, CaptureRegistration) == paramErr,
                "A missing bundle URL was accepted.");
        require(MetasequoiaRegisterInputSource(bundleURL, nullptr) == paramErr,
                "A missing registration callback was accepted.");
    }
    return 0;
}
