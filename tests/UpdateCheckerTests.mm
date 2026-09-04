#import "../src/UpdateChecker.h"

#include <stdexcept>

namespace
{
void require(bool condition, const char *message)
{
    if (!condition)
    {
        throw std::runtime_error(message);
    }
}

void WaitForCondition(BOOL (^condition)(void))
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
    while (!condition() && [deadline timeIntervalSinceNow] > 0.0)
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    require(condition(), "Timed out waiting for the update check.");
}
} // namespace

int main()
{
    @autoreleasepool
    {
        require(MetasequoiaVersionIsNewer(@"0.20.14", @"0.20.13"), "A newer patch was not detected.");
        require(MetasequoiaVersionIsNewer(@"1.0.0", @"0.99.99"), "A newer major version was not detected.");
        require(!MetasequoiaVersionIsNewer(@"0.20.13", @"0.20.13"), "An equal version was marked newer.");
        require(!MetasequoiaVersionIsNewer(@"0.20", @"0.20.13"), "An invalid version was accepted.");

        NSData *release = [@"{\"tag_name\":\"v0.20.14\",\"draft\":false,\"prerelease\":false}"
            dataUsingEncoding:NSUTF8StringEncoding];
        require([MetasequoiaReleaseVersionFromData(release) isEqualToString:@"0.20.14"],
                "A valid latest-release response was not parsed.");
        NSData *unsignedRelease = [@"{\"tag_name\":\"v0.20.14\",\"draft\":false,\"prerelease\":false,"
                                    "\"assets\":[{\"name\":\"MetasequoiaIME-v0.20.14-macos-universal-unsigned.zip\","
                                    "\"browser_download_url\":\"https://attacker.invalid/payload.zip\"}]}"
            dataUsingEncoding:NSUTF8StringEncoding];
        require([MetasequoiaRecommendedDownloadURLFromData(unsignedRelease).absoluteString
                    isEqualToString:@"https://github.com/houko/MetasequoiaImeMac/releases/download/v0.20.14/"
                                    "MetasequoiaIME-v0.20.14-macos-universal-unsigned.zip"],
                "The unsigned archive did not use its reconstructed trusted download URL.");
        NSData *signedRelease = [@"{\"tag_name\":\"v0.20.14\",\"draft\":false,\"prerelease\":false,"
                                  "\"assets\":["
                                  "{\"name\":\"MetasequoiaIME-v0.20.14-macos-universal-unsigned.zip\"},"
                                  "{\"name\":\"MetasequoiaIME-v0.20.14-macos-universal.zip\"}]}"
            dataUsingEncoding:NSUTF8StringEncoding];
        require([MetasequoiaRecommendedDownloadURLFromData(signedRelease).lastPathComponent
                    isEqualToString:@"MetasequoiaIME-v0.20.14-macos-universal.zip"],
                "A signed archive was not preferred over an unsigned archive.");
        NSData *untrustedAsset = [@"{\"tag_name\":\"v0.20.14\",\"draft\":false,\"prerelease\":false,"
                                   "\"assets\":[{\"name\":\"unrelated.zip\","
                                   "\"browser_download_url\":\"https://attacker.invalid/payload.zip\"}]}"
            dataUsingEncoding:NSUTF8StringEncoding];
        require(MetasequoiaRecommendedDownloadURLFromData(untrustedAsset) == nil,
                "An archive without the exact release filename was accepted.");
        require(MetasequoiaRecommendedDownloadURLFromData(release) == nil,
                "A release without a ZIP asset unexpectedly produced a direct download.");
        NSData *prerelease = [@"{\"tag_name\":\"v0.21.0\",\"draft\":false,\"prerelease\":true}"
            dataUsingEncoding:NSUTF8StringEncoding];
        require(MetasequoiaReleaseVersionFromData(prerelease) == nil,
                "A prerelease was accepted as an automatic update.");
        require(MetasequoiaReleaseVersionFromData([@"not-json" dataUsingEncoding:NSUTF8StringEncoding]) == nil,
                "Malformed release metadata was accepted.");

        NSString *suiteName = [@"MetasequoiaUpdateCheckerTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        [defaults removePersistentDomainForName:suiteName];
        NSDate *now = [NSDate dateWithTimeIntervalSince1970:2'000'000'000.0];
        __block NSInteger fetchCount = 0;
        MetasequoiaUpdateFetcher fetcher = ^(MetasequoiaUpdateFetchCompletion completion) {
            ++fetchCount;
            completion(unsignedRelease, 200, nil);
        };
        MetasequoiaUpdateChecker *checker =
            [[MetasequoiaUpdateChecker alloc] initWithDefaults:defaults
                                               currentVersion:@"0.20.13"
                                                      fetcher:fetcher
                                                        clock:^NSDate * {
                                                            return now;
                                                        }];
        [checker checkForUpdatesIfNeeded];
        WaitForCondition(^BOOL {
            return checker.availableVersion != nil;
        });
        require([checker.availableVersion isEqualToString:@"0.20.14"],
                "The available version was not cached.");
        require([checker.releaseURL.absoluteString
                    isEqualToString:@"https://github.com/houko/MetasequoiaImeMac/releases/tag/v0.20.14"],
                "The update URL did not use the trusted release origin.");
        require([checker.downloadURL.absoluteString
                    isEqualToString:@"https://github.com/houko/MetasequoiaImeMac/releases/download/v0.20.14/"
                                    "MetasequoiaIME-v0.20.14-macos-universal-unsigned.zip"],
                "The update checker did not expose the recommended archive.");
        NSDictionary *cachedUpdate = [defaults dictionaryForKey:@"MetasequoiaImeAvailableUpdate"];
        require([cachedUpdate[@"version"] isEqualToString:@"0.20.14"] &&
                    [cachedUpdate[@"archiveVariant"] isEqualToString:@"unsigned"],
                "The update version and archive variant were not cached as one record.");
        [defaults setObject:@"0.20.15" forKey:@"MetasequoiaImeAvailableUpdateVersion"];
        [defaults setObject:@"signed" forKey:@"MetasequoiaImeAvailableUpdateArchiveVariant"];
        NSUserDefaults *restoredDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        MetasequoiaUpdateChecker *restoredChecker =
            [[MetasequoiaUpdateChecker alloc] initWithDefaults:restoredDefaults
                                               currentVersion:@"0.20.13"
                                                      fetcher:fetcher
                                                        clock:^NSDate * {
                                                            return now;
                                                        }];
        require([restoredChecker.availableVersion isEqualToString:@"0.20.14"],
                "Interleaved legacy keys overrode the atomic cached update record.");
        require([restoredChecker.downloadURL.absoluteString isEqualToString:checker.downloadURL.absoluteString],
                "The recommended archive was not restored in a new input-method process.");
        [restoredDefaults setObject:@{
            @"version" : @"0.20.14",
            @"archiveVariant" : @"https://attacker.invalid/payload.zip",
        }
                            forKey:@"MetasequoiaImeAvailableUpdate"];
        MetasequoiaUpdateChecker *tamperedDefaultsChecker =
            [[MetasequoiaUpdateChecker alloc] initWithDefaults:restoredDefaults
                                               currentVersion:@"0.20.13"
                                                      fetcher:fetcher
                                                        clock:^NSDate * {
                                                            return now;
                                                        }];
        require(tamperedDefaultsChecker.downloadURL == nil,
                "An invalid cached archive variant produced a download URL.");
        require(tamperedDefaultsChecker.releaseURL != nil,
                "An invalid cached archive variant removed the trusted release-page fallback.");
        [restoredChecker checkForUpdatesIfNeeded];
        [checker checkForUpdatesIfNeeded];
        require(fetchCount == 1, "The automatic update check ignored its daily throttle.");

        __block MetasequoiaUpdateCheckState manualState = MetasequoiaUpdateCheckStateFailed;
        [checker checkForUpdates:^(MetasequoiaUpdateCheckState state) {
            manualState = state;
        }];
        WaitForCondition(^BOOL {
            return fetchCount == 2 && manualState != MetasequoiaUpdateCheckStateFailed;
        });
        require(manualState == MetasequoiaUpdateCheckStateAvailable,
                "A manual update check did not report the available release.");

        NSData *currentRelease = [@"{\"tag_name\":\"v0.20.13\",\"draft\":false,\"prerelease\":false}"
            dataUsingEncoding:NSUTF8StringEncoding];
        MetasequoiaUpdateChecker *currentChecker =
            [[MetasequoiaUpdateChecker alloc] initWithDefaults:defaults
                                               currentVersion:@"0.20.13"
                                                      fetcher:^(MetasequoiaUpdateFetchCompletion completion) {
                                                          completion(currentRelease, 200, nil);
                                                      }
                                                        clock:^NSDate * {
                                                            return now;
                                                        }];
        __block BOOL currentCheckFinished = NO;
        [currentChecker checkForUpdates:^(MetasequoiaUpdateCheckState state) {
            currentCheckFinished = state == MetasequoiaUpdateCheckStateCurrent;
        }];
        WaitForCondition(^BOOL {
            return currentCheckFinished;
        });
        require(currentChecker.availableVersion == nil,
                "An installed current version left a stale update notification cached.");

        NSString *coalescingSuiteName =
            [@"MetasequoiaUpdateCheckerCoalescingTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *coalescingDefaults = [[NSUserDefaults alloc] initWithSuiteName:coalescingSuiteName];
        [coalescingDefaults removePersistentDomainForName:coalescingSuiteName];
        __block NSInteger coalescedFetchCount = 0;
        __block MetasequoiaUpdateFetchCompletion delayedFetchCompletion = nil;
        MetasequoiaUpdateChecker *coalescingChecker =
            [[MetasequoiaUpdateChecker alloc] initWithDefaults:coalescingDefaults
                                               currentVersion:@"0.20.13"
                                                      fetcher:^(MetasequoiaUpdateFetchCompletion completion) {
                                                          ++coalescedFetchCount;
                                                          delayedFetchCompletion = [completion copy];
                                                      }
                                                        clock:^NSDate * {
                                                            return now;
                                                        }];
        __block NSInteger completionCount = 0;
        [coalescingChecker checkForUpdates:^(MetasequoiaUpdateCheckState state) {
            require(state == MetasequoiaUpdateCheckStateAvailable,
                    "A coalesced update check returned the wrong state.");
            ++completionCount;
        }];
        [coalescingChecker checkForUpdates:^(MetasequoiaUpdateCheckState state) {
            require(state == MetasequoiaUpdateCheckStateAvailable,
                    "A second coalesced update check returned the wrong state.");
            ++completionCount;
        }];
        require(coalescedFetchCount == 1 && delayedFetchCompletion != nil,
                "Concurrent update checks were not coalesced into one request.");
        delayedFetchCompletion(release, 200, nil);
        WaitForCondition(^BOOL {
            return completionCount == 2;
        });

        __block MetasequoiaUpdateCheckState failureState = MetasequoiaUpdateCheckStateCurrent;
        MetasequoiaUpdateChecker *failureChecker =
            [[MetasequoiaUpdateChecker alloc] initWithDefaults:coalescingDefaults
                                               currentVersion:@"0.20.13"
                                                      fetcher:^(MetasequoiaUpdateFetchCompletion completion) {
                                                          NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                                                               code:NSURLErrorNotConnectedToInternet
                                                                                           userInfo:nil];
                                                          completion(nil, 0, error);
                                                      }
                                                        clock:^NSDate * {
                                                            return now;
                                                        }];
        [failureChecker checkForUpdates:^(MetasequoiaUpdateCheckState state) {
            failureState = state;
        }];
        WaitForCondition(^BOOL {
            return failureState == MetasequoiaUpdateCheckStateFailed;
        });

        NSString *retrySuiteName =
            [@"MetasequoiaUpdateCheckerRetryTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *retryDefaults = [[NSUserDefaults alloc] initWithSuiteName:retrySuiteName];
        [retryDefaults removePersistentDomainForName:retrySuiteName];
        __block NSDate *retryNow = now;
        __block NSInteger retryFetchCount = 0;
        MetasequoiaUpdateChecker *retryChecker =
            [[MetasequoiaUpdateChecker alloc] initWithDefaults:retryDefaults
                                               currentVersion:@"0.20.13"
                                                      fetcher:^(MetasequoiaUpdateFetchCompletion completion) {
                                                          ++retryFetchCount;
                                                          if (retryFetchCount == 1)
                                                          {
                                                              NSError *error = [NSError
                                                                  errorWithDomain:NSURLErrorDomain
                                                                             code:NSURLErrorNotConnectedToInternet
                                                                         userInfo:nil];
                                                              completion(nil, 0, error);
                                                          }
                                                          else
                                                          {
                                                              completion(unsignedRelease, 200, nil);
                                                          }
                                                      }
                                                        clock:^NSDate * {
                                                            return retryNow;
                                                        }];
        __block BOOL initialFailureFinished = NO;
        [retryChecker checkForUpdates:^(MetasequoiaUpdateCheckState state) {
            initialFailureFinished = state == MetasequoiaUpdateCheckStateFailed;
        }];
        WaitForCondition(^BOOL {
            return initialFailureFinished;
        });
        retryNow = [now dateByAddingTimeInterval:30.0 * 60.0];
        [retryChecker checkForUpdatesIfNeeded];
        require(retryFetchCount == 1, "A failed update check retried before the one-hour backoff elapsed.");
        retryNow = [now dateByAddingTimeInterval:61.0 * 60.0];
        [retryChecker checkForUpdatesIfNeeded];
        WaitForCondition(^BOOL {
            return retryFetchCount == 2 && retryChecker.availableVersion != nil;
        });
        retryNow = [now dateByAddingTimeInterval:3.0 * 60.0 * 60.0];
        [retryChecker checkForUpdatesIfNeeded];
        require(retryFetchCount == 2, "A successful update check ignored the daily throttle.");

        [defaults removePersistentDomainForName:suiteName];
        [coalescingDefaults removePersistentDomainForName:coalescingSuiteName];
        [retryDefaults removePersistentDomainForName:retrySuiteName];
    }
    return 0;
}
