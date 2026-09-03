#import "DictionaryInstaller.h"

#include "../vendor/MetasequoiaImeEngine/user_dictionary/user_dictionary_journal.h"

namespace
{
NSString *const MetasequoiaDictionaryErrorDomain = @"com.houko.inputmethod.MetasequoiaIME.dictionary";

BOOL Fail(NSError **error, NSInteger code, NSString *description)
{
    if (error != nullptr)
    {
        *error = [NSError errorWithDomain:MetasequoiaDictionaryErrorDomain
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey: description}];
    }
    return NO;
}

std::string FileSystemPath(NSURL *url)
{
    const char *path = url.fileSystemRepresentation;
    return path == nullptr ? std::string{} : std::string(path);
}
} // namespace

BOOL InstallMetasequoiaDictionary(NSURL *source, NSURL *dataDirectory, NSString *dictionaryFingerprint,
                                  NSError **error)
{
    if (error != nullptr)
    {
        *error = nil;
    }
    if (source == nil || dataDirectory == nil || dictionaryFingerprint.length == 0)
    {
        return Fail(error, 1, @"The bundled dictionary metadata is incomplete.");
    }

    @synchronized([NSFileManager class])
    {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary<NSFileAttributeKey, id> *sourceAttributes =
            [fileManager attributesOfItemAtPath:source.path error:error];
        if (sourceAttributes == nil || sourceAttributes.fileSize == 0)
        {
            if (sourceAttributes != nil)
            {
                return Fail(error, 2, @"The bundled msime.db dictionary is empty.");
            }
            return NO;
        }

        if (![fileManager createDirectoryAtURL:dataDirectory
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:error])
        {
            return NO;
        }

        NSURL *destination = [dataDirectory URLByAppendingPathComponent:@"msime.db" isDirectory:NO];
        NSURL *fingerprintFile = [dataDirectory URLByAppendingPathComponent:@"msime.db.sha256" isDirectory:NO];
        const BOOL destinationExists = [fileManager fileExistsAtPath:destination.path];
        if (destinationExists)
        {
            NSDictionary<NSFileAttributeKey, id> *destinationAttributes =
                [fileManager attributesOfItemAtPath:destination.path error:error];
            if (destinationAttributes == nil)
            {
                return NO;
            }

            NSString *installedFingerprint =
                [NSString stringWithContentsOfURL:fingerprintFile encoding:NSUTF8StringEncoding error:nil];
            if (destinationAttributes.fileSize > 0 && [installedFingerprint isEqualToString:dictionaryFingerprint])
            {
                return YES;
            }

            if (installedFingerprint == nil && [fileManager contentsEqualAtPath:source.path andPath:destination.path])
            {
                return [dictionaryFingerprint writeToURL:fingerprintFile
                                              atomically:YES
                                                encoding:NSUTF8StringEncoding
                                                   error:error];
            }
        }

        NSString *temporaryName = [@".msime.db.installing." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSURL *temporary = [dataDirectory URLByAppendingPathComponent:temporaryName isDirectory:NO];
        if (![fileManager copyItemAtURL:source toURL:temporary error:error])
        {
            return NO;
        }

        NSURL *userDatabase = [dataDirectory URLByAppendingPathComponent:@"msime_user.db" isDirectory:NO];
        NSURL *englishDatabase = [dataDirectory URLByAppendingPathComponent:@"msime_english.db" isDirectory:NO];
        if ([fileManager fileExistsAtPath:userDatabase.path] &&
            ![fileManager fileExistsAtPath:englishDatabase.path] &&
            ![fileManager createFileAtPath:englishDatabase.path contents:nil attributes:nil])
        {
            [fileManager removeItemAtURL:temporary error:nil];
            return Fail(error, 3, @"The English user dictionary could not be prepared for replay.");
        }
        const auto replay = user_dictionary::replay(FileSystemPath(userDatabase), FileSystemPath(temporary),
                                                    FileSystemPath(englishDatabase));
        if (replay.failed != 0 || !replay.error.empty())
        {
            [fileManager removeItemAtURL:temporary error:nil];
            NSString *description = [NSString
                stringWithFormat:@"User dictionary replay failed (%d operation(s)): %s", replay.failed,
                                 replay.error.c_str()];
            return Fail(error, 3, description);
        }

        BOOL installed = NO;
        if (destinationExists)
        {
            installed = [fileManager replaceItemAtURL:destination
                                        withItemAtURL:temporary
                                       backupItemName:nil
                                              options:0
                                     resultingItemURL:nil
                                                error:error];
        }
        else
        {
            installed = [fileManager moveItemAtURL:temporary toURL:destination error:error];
        }
        if (!installed)
        {
            [fileManager removeItemAtURL:temporary error:nil];
            return NO;
        }

        return [dictionaryFingerprint writeToURL:fingerprintFile
                                      atomically:YES
                                        encoding:NSUTF8StringEncoding
                                           error:error];
    }
}

BOOL EnsureMetasequoiaDictionary(NSError **error)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationSupport = [fileManager URLForDirectory:NSApplicationSupportDirectory
                                                    inDomain:NSUserDomainMask
                                           appropriateForURL:nil
                                                      create:YES
                                                       error:error];
    if (applicationSupport == nil)
    {
        return NO;
    }

    NSURL *dataDirectory = [applicationSupport URLByAppendingPathComponent:@"metasequoiaime" isDirectory:YES];
    NSURL *source = [[NSBundle mainBundle] URLForResource:@"msime" withExtension:@"db"];
    NSString *fingerprint = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MetasequoiaDictionarySHA256"];
    return InstallMetasequoiaDictionary(source, dataDirectory, fingerprint, error);
}
