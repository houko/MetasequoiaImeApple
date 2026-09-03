#import "DictionaryInstaller.h"

#include "../vendor/MetasequoiaImeEngine/user_dictionary/user_dictionary_journal.h"

#include <sqlite3.h>

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

BOOL IsUsableDictionary(NSURL *dictionary)
{
    const std::string path = FileSystemPath(dictionary);
    if (path.empty())
    {
        return NO;
    }

    sqlite3 *database = nullptr;
    if (sqlite3_open_v2(path.c_str(), &database, SQLITE_OPEN_READONLY, nullptr) != SQLITE_OK)
    {
        sqlite3_close(database);
        return NO;
    }

    sqlite3_stmt *integrityStatement = nullptr;
    BOOL integrityValid = sqlite3_prepare_v2(database, "PRAGMA quick_check(1)", -1, &integrityStatement, nullptr) ==
                              SQLITE_OK &&
                          sqlite3_step(integrityStatement) == SQLITE_ROW;
    if (integrityValid)
    {
        const unsigned char *result = sqlite3_column_text(integrityStatement, 0);
        integrityValid = result != nullptr && std::string(reinterpret_cast<const char *>(result)) == "ok";
    }
    sqlite3_finalize(integrityStatement);

    sqlite3_stmt *schemaStatement = nullptr;
    BOOL schemaValid = integrityValid &&
                       sqlite3_prepare_v2(database,
                                          "SELECT 1 FROM sqlite_master WHERE type='table' AND name GLOB 'tbl_*' "
                                          "LIMIT 1",
                                          -1, &schemaStatement, nullptr) == SQLITE_OK &&
                       sqlite3_step(schemaStatement) == SQLITE_ROW;
    sqlite3_finalize(schemaStatement);
    sqlite3_close(database);
    return schemaValid;
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

BOOL PrepareMetasequoiaDictionary(NSURL *source, NSURL *dataDirectory, NSString *dictionaryFingerprint,
                                  NSError **error)
{
    NSError *installError = nil;
    if (InstallMetasequoiaDictionary(source, dataDirectory, dictionaryFingerprint, &installError))
    {
        if (error != nullptr)
        {
            *error = nil;
        }
        return YES;
    }

    NSURL *existingDictionary = [dataDirectory URLByAppendingPathComponent:@"msime.db" isDirectory:NO];
    if (IsUsableDictionary(existingDictionary))
    {
        NSLog(@"Bundled dictionary update failed; continuing with the validated existing dictionary.");
        if (error != nullptr)
        {
            *error = nil;
        }
        return YES;
    }

    if (installError != nil)
    {
        if (error != nullptr)
        {
            *error = installError;
        }
        return NO;
    }
    return Fail(error, 4, @"No usable Metasequoia dictionary is available.");
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
    return PrepareMetasequoiaDictionary(source, dataDirectory, fingerprint, error);
}
