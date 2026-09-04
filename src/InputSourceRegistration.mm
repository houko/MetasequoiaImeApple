#import "InputSourceRegistration.h"

#include <cstring>

bool MetasequoiaShouldRegisterInputSource(int argc, const char *argv[])
{
    return argc == 2 && argv != nullptr && argv[1] != nullptr &&
           std::strcmp(argv[1], "--register-input-source") == 0;
}

OSStatus MetasequoiaRegisterInputSource(NSURL *bundleURL, MetasequoiaInputSourceRegistrar registrar)
{
    if (bundleURL == nil || registrar == nullptr)
    {
        return paramErr;
    }
    return registrar((__bridge CFURLRef)bundleURL);
}
