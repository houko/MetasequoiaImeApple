#pragma once

#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>

using MetasequoiaInputSourceRegistrar = OSStatus (*)(CFURLRef location);

bool MetasequoiaShouldRegisterInputSource(int argc, const char *argv[]);
OSStatus MetasequoiaRegisterInputSource(NSURL *bundleURL, MetasequoiaInputSourceRegistrar registrar);
