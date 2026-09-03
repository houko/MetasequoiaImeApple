#import "../src/DictionaryInstaller.h"

#include "../vendor/MetasequoiaImeEngine/user_dictionary/user_dictionary_journal.h"

#include <sqlite3.h>

#include <stdexcept>
#include <string>

namespace
{
void Require(bool condition, const char *message)
{
    if (!condition)
    {
        throw std::runtime_error(message);
    }
}

void WriteString(NSString *value, NSURL *url)
{
    NSError *error = nil;
    Require([value writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error],
            error.localizedDescription.UTF8String);
}

std::string ReadString(NSURL *url)
{
    NSError *error = nil;
    NSString *value = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    Require(value != nil, error.localizedDescription.UTF8String);
    return value.UTF8String;
}

void ExecuteSql(NSURL *url, const char *sql)
{
    sqlite3 *database = nullptr;
    Require(sqlite3_open(url.fileSystemRepresentation, &database) == SQLITE_OK, "Failed to open test database.");
    char *message = nullptr;
    const int result = sqlite3_exec(database, sql, nullptr, nullptr, &message);
    const std::string error = message == nullptr ? "SQLite statement failed." : message;
    sqlite3_free(message);
    sqlite3_close(database);
    Require(result == SQLITE_OK, error.c_str());
}

std::int64_t ReadWeight(NSURL *url, const char *word)
{
    sqlite3 *database = nullptr;
    Require(sqlite3_open_v2(url.fileSystemRepresentation, &database, SQLITE_OPEN_READONLY, nullptr) == SQLITE_OK,
            "Failed to open installed dictionary.");
    sqlite3_stmt *statement = nullptr;
    Require(sqlite3_prepare_v2(database, "SELECT weight FROM tbl_2_n WHERE value=?1", -1, &statement, nullptr) ==
                SQLITE_OK,
            "Failed to prepare weight query.");
    Require(sqlite3_bind_text(statement, 1, word, -1, SQLITE_TRANSIENT) == SQLITE_OK,
            "Failed to bind weight query.");
    Require(sqlite3_step(statement) == SQLITE_ROW, "Installed dictionary word was missing.");
    const std::int64_t weight = sqlite3_column_int64(statement, 0);
    sqlite3_finalize(statement);
    sqlite3_close(database);
    return weight;
}

NSURL *CreateDirectory(NSURL *root, NSString *name)
{
    NSURL *directory = [root URLByAppendingPathComponent:name isDirectory:YES];
    NSError *error = nil;
    Require([[NSFileManager defaultManager] createDirectoryAtURL:directory
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error],
            error.localizedDescription.UTF8String);
    return directory;
}
} // namespace

int main()
{
    @autoreleasepool
    {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *root = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
            URLByAppendingPathComponent:[@"metasequoia-dictionary-installer-" stringByAppendingString:NSUUID.UUID.UUIDString]
                               isDirectory:YES];
        NSError *error = nil;
        Require([fileManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:&error],
                error.localizedDescription.UTF8String);

        NSURL *sameSizeDirectory = CreateDirectory(root, @"same-size");
        NSURL *sameSizeSource = [root URLByAppendingPathComponent:@"same-size-source.db"];
        NSURL *sameSizeDestination = [sameSizeDirectory URLByAppendingPathComponent:@"msime.db"];
        WriteString(@"new-data", sameSizeSource);
        WriteString(@"old-data", sameSizeDestination);
        Require(InstallMetasequoiaDictionary(sameSizeSource, sameSizeDirectory, @"new-fingerprint", &error),
                error.localizedDescription.UTF8String);
        Require(ReadString(sameSizeDestination) == "new-data",
                "A same-size dictionary update was incorrectly skipped.");

        WriteString(@"learned-data", sameSizeDestination);
        Require(InstallMetasequoiaDictionary(sameSizeSource, sameSizeDirectory, @"new-fingerprint", &error),
                error.localizedDescription.UTF8String);
        Require(ReadString(sameSizeDestination) == "learned-data",
                "A matching dictionary fingerprint overwrote learned data.");

        NSURL *replayDirectory = CreateDirectory(root, @"replay");
        NSURL *replaySource = [root URLByAppendingPathComponent:@"replay-source.db"];
        NSURL *replayDestination = [replayDirectory URLByAppendingPathComponent:@"msime.db"];
        ExecuteSql(replaySource,
                   "CREATE TABLE tbl_2_n(key TEXT, jp TEXT, value TEXT, weight INTEGER);"
                   "INSERT INTO tbl_2_n VALUES('ni''hao','nh','你好',200);"
                   "INSERT INTO tbl_2_n VALUES('ni''hao','nh','拟好',100);");
        ExecuteSql(replayDestination,
                   "CREATE TABLE tbl_2_n(key TEXT, jp TEXT, value TEXT, weight INTEGER);"
                   "INSERT INTO tbl_2_n VALUES('ni''hao','nh','你好',200);"
                   "INSERT INTO tbl_2_n VALUES('ni''hao','nh','拟好',201);");
        const std::string userDatabase =
            [replayDirectory URLByAppendingPathComponent:@"msime_user.db"].fileSystemRepresentation;
        Require(user_dictionary::record_upsert(userDatabase, user_dictionary::DictionaryKind::Pinyin, "ni'hao",
                                               "拟好", 999),
                "Failed to create the user dictionary journal fixture.");
        WriteString(@"old-fingerprint", [replayDirectory URLByAppendingPathComponent:@"msime.db.sha256"]);
        Require(InstallMetasequoiaDictionary(replaySource, replayDirectory, @"new-fingerprint", &error),
                error.localizedDescription.UTF8String);
        Require(ReadWeight(replayDestination, "拟好") == 999,
                "The user dictionary journal was not replayed onto the upgraded dictionary.");

        NSURL *failureDirectory = CreateDirectory(root, @"failure");
        NSURL *failureDestination = [failureDirectory URLByAppendingPathComponent:@"msime.db"];
        WriteString(@"keep-me", failureDestination);
        error = nil;
        NSURL *missingSource = [root URLByAppendingPathComponent:@"missing.db"];
        Require(!InstallMetasequoiaDictionary(missingSource, failureDirectory, @"missing", &error),
                "A missing bundled dictionary unexpectedly succeeded.");
        Require(ReadString(failureDestination) == "keep-me", "A failed update removed the working dictionary.");
        error = nil;
        Require(!PrepareMetasequoiaDictionary(missingSource, failureDirectory, @"missing", &error),
                "A corrupt existing dictionary was accepted as an update fallback.");
        Require(error != nil, "A rejected dictionary fallback did not preserve the update error.");

        NSURL *replayFailureDirectory = CreateDirectory(root, @"replay-failure");
        NSURL *replayFailureSource = [root URLByAppendingPathComponent:@"replay-failure-source.db"];
        NSURL *replayFailureDestination = [replayFailureDirectory URLByAppendingPathComponent:@"msime.db"];
        ExecuteSql(replayFailureSource,
                   "CREATE TABLE tbl_2_n(key TEXT, jp TEXT, value TEXT, weight INTEGER);"
                   "INSERT INTO tbl_2_n VALUES('ni''hao','nh','你好',200);");
        ExecuteSql(replayFailureDestination,
                   "CREATE TABLE tbl_2_n(key TEXT, jp TEXT, value TEXT, weight INTEGER);"
                   "INSERT INTO tbl_2_n VALUES('ni''hao','nh','你好',321);");
        const std::string invalidUserDatabase =
            [replayFailureDirectory URLByAppendingPathComponent:@"msime_user.db"].fileSystemRepresentation;
        Require(user_dictionary::record_upsert(invalidUserDatabase, user_dictionary::DictionaryKind::Pinyin,
                                               "wo'ai", "我爱", 999),
                "Failed to create the invalid replay fixture.");
        error = nil;
        Require(!InstallMetasequoiaDictionary(replayFailureSource, replayFailureDirectory, @"new-fingerprint",
                                              &error),
                "An invalid user dictionary replay unexpectedly succeeded.");
        Require(ReadWeight(replayFailureDestination, "你好") == 321,
                "A failed journal replay replaced the working dictionary.");
        error = nil;
        Require(PrepareMetasequoiaDictionary(replayFailureSource, replayFailureDirectory, @"new-fingerprint",
                                             &error),
                "A valid existing dictionary was not used after an update failure.");
        Require(error == nil, "A successful dictionary fallback leaked the update error.");
        Require(ReadWeight(replayFailureDestination, "你好") == 321,
                "Dictionary fallback did not preserve the existing working database.");

        Require([fileManager removeItemAtURL:root error:&error], error.localizedDescription.UTF8String);
    }
    return 0;
}
