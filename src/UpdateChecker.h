#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MetasequoiaUpdateCheckState) {
    MetasequoiaUpdateCheckStateFailed,
    MetasequoiaUpdateCheckStateCurrent,
    MetasequoiaUpdateCheckStateAvailable,
};

typedef void (^MetasequoiaUpdateFetchCompletion)(NSData *_Nullable data, NSInteger statusCode,
                                                  NSError *_Nullable error);
typedef void (^MetasequoiaUpdateFetcher)(MetasequoiaUpdateFetchCompletion completion);
typedef void (^MetasequoiaUpdateCheckCompletion)(MetasequoiaUpdateCheckState state);
typedef NSDate *_Nonnull (^MetasequoiaUpdateClock)(void);

FOUNDATION_EXPORT NSNotificationName const MetasequoiaUpdateAvailabilityDidChangeNotification;

BOOL MetasequoiaVersionIsNewer(NSString *candidateVersion, NSString *currentVersion);
NSString *_Nullable MetasequoiaReleaseVersionFromData(NSData *data);

@interface MetasequoiaUpdateChecker : NSObject
+ (instancetype)sharedChecker;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults
                   currentVersion:(NSString *)currentVersion
                          fetcher:(MetasequoiaUpdateFetcher)fetcher
                            clock:(MetasequoiaUpdateClock)clock;
@property(nonatomic, readonly, nullable) NSString *availableVersion;
@property(nonatomic, readonly, nullable) NSURL *releaseURL;
- (void)checkForUpdatesIfNeeded;
- (void)checkForUpdates:(nullable MetasequoiaUpdateCheckCompletion)completion;
@end

NS_ASSUME_NONNULL_END
