#import "DictionaryInstaller.h"

BOOL EnsureMetasequoiaDictionary(NSError **error)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationSupport = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:error];
    if (applicationSupport == nil)
    {
        return NO;
    }

    NSURL *dataDirectory = [applicationSupport URLByAppendingPathComponent:@"metasequoiaime" isDirectory:YES];
    if (![fileManager createDirectoryAtURL:dataDirectory withIntermediateDirectories:YES attributes:nil error:error])
    {
        return NO;
    }

    NSURL *source = [[NSBundle mainBundle] URLForResource:@"msime" withExtension:@"db"];
    if (source == nil)
    {
        if (error != nullptr)
        {
            *error = [NSError errorWithDomain:@"com.houko.inputmethod.MetasequoiaIME" code:1 userInfo:@{NSLocalizedDescriptionKey: @"The bundled msime.db dictionary is missing."}];
        }
        return NO;
    }

    NSDictionary<NSFileAttributeKey, id> *sourceAttributes = [fileManager attributesOfItemAtPath:source.path error:error];
    if (sourceAttributes == nil || [sourceAttributes fileSize] == 0)
    {
        return NO;
    }

    NSURL *destination = [dataDirectory URLByAppendingPathComponent:@"msime.db" isDirectory:NO];
    if ([fileManager fileExistsAtPath:destination.path])
    {
        NSDictionary<NSFileAttributeKey, id> *destinationAttributes = [fileManager attributesOfItemAtPath:destination.path error:error];
        if (destinationAttributes != nil && [destinationAttributes fileSize] == [sourceAttributes fileSize])
        {
            return YES;
        }
        if (![fileManager removeItemAtURL:destination error:error])
        {
            return NO;
        }
    }
    return [fileManager copyItemAtURL:source toURL:destination error:error];
}
