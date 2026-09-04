#import "UpdateChecker.h"

NSNotificationName const MetasequoiaUpdateAvailabilityDidChangeNotification =
    @"MetasequoiaUpdateAvailabilityDidChangeNotification";

namespace
{
constexpr NSTimeInterval kAutomaticCheckInterval = 24.0 * 60.0 * 60.0;
NSString *const kAvailableVersionKey = @"MetasequoiaImeAvailableUpdateVersion";
NSString *const kLastUpdateCheckKey = @"MetasequoiaImeLastUpdateCheck";
NSString *const kLatestReleaseEndpoint =
    @"https://api.github.com/repos/houko/MetasequoiaImeMac/releases/latest";
NSString *const kReleasePagePrefix = @"https://github.com/houko/MetasequoiaImeMac/releases/tag/v";

NSArray<NSNumber *> *VersionComponents(NSString *version)
{
    if (![version isKindOfClass:[NSString class]])
    {
        return nil;
    }
    NSArray<NSString *> *parts = [version componentsSeparatedByString:@"."];
    if (parts.count != 3)
    {
        return nil;
    }
    NSCharacterSet *nonDigits = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    NSMutableArray<NSNumber *> *components = [NSMutableArray arrayWithCapacity:3];
    for (NSString *part in parts)
    {
        if (part.length == 0 || part.length > 9 || [part rangeOfCharacterFromSet:nonDigits].location != NSNotFound)
        {
            return nil;
        }
        [components addObject:@(part.integerValue)];
    }
    return components;
}

MetasequoiaUpdateFetcher ProductionFetcher()
{
    return ^(MetasequoiaUpdateFetchCompletion completion) {
        NSURL *url = [NSURL URLWithString:kLatestReleaseEndpoint];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.timeoutInterval = 15.0;
        [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
        [request setValue:@"2022-11-28" forHTTPHeaderField:@"X-GitHub-Api-Version"];
        [request setValue:@"MetasequoiaIME-UpdateChecker" forHTTPHeaderField:@"User-Agent"];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
        NSURLSessionDataTask *task = [session
            dataTaskWithRequest:request
              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                  NSInteger statusCode = 0;
                  if ([response isKindOfClass:[NSHTTPURLResponse class]])
                  {
                      statusCode = ((NSHTTPURLResponse *)response).statusCode;
                  }
                  completion(data, statusCode, error);
                  [session finishTasksAndInvalidate];
              }];
        [task resume];
    };
}
} // namespace

BOOL MetasequoiaVersionIsNewer(NSString *candidateVersion, NSString *currentVersion)
{
    NSArray<NSNumber *> *candidate = VersionComponents(candidateVersion);
    NSArray<NSNumber *> *current = VersionComponents(currentVersion);
    if (candidate == nil || current == nil)
    {
        return NO;
    }
    for (NSUInteger index = 0; index < candidate.count; ++index)
    {
        if (candidate[index].integerValue != current[index].integerValue)
        {
            return candidate[index].integerValue > current[index].integerValue;
        }
    }
    return NO;
}

NSString *MetasequoiaReleaseVersionFromData(NSData *data)
{
    if (data == nil)
    {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    NSDictionary *release = (NSDictionary *)object;
    NSString *tagName = release[@"tag_name"];
    NSNumber *draft = release[@"draft"];
    NSNumber *prerelease = release[@"prerelease"];
    if (![tagName isKindOfClass:[NSString class]] || ![draft isKindOfClass:[NSNumber class]] ||
        ![prerelease isKindOfClass:[NSNumber class]] || draft.boolValue || prerelease.boolValue ||
        ![tagName hasPrefix:@"v"])
    {
        return nil;
    }
    NSString *version = [tagName substringFromIndex:1];
    return VersionComponents(version) == nil ? nil : version;
}

@interface MetasequoiaUpdateChecker ()
@property(nonatomic, readwrite, nullable) NSString *availableVersion;
@end

@implementation MetasequoiaUpdateChecker
{
    NSUserDefaults *_defaults;
    NSString *_currentVersion;
    MetasequoiaUpdateFetcher _fetcher;
    MetasequoiaUpdateClock _clock;
    BOOL _checking;
    NSMutableArray<MetasequoiaUpdateCheckCompletion> *_pendingCompletions;
}

+ (instancetype)sharedChecker
{
    static MetasequoiaUpdateChecker *checker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        checker = [[self alloc] initWithDefaults:NSUserDefaults.standardUserDefaults
                                  currentVersion:version != nil ? version : @"0.0.0"
                                         fetcher:ProductionFetcher()
                                           clock:^{
                                               return [NSDate date];
                                           }];
    });
    return checker;
}

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults
                   currentVersion:(NSString *)currentVersion
                          fetcher:(MetasequoiaUpdateFetcher)fetcher
                            clock:(MetasequoiaUpdateClock)clock
{
    self = [super init];
    if (self == nil)
    {
        return nil;
    }
    _defaults = defaults;
    _currentVersion = [currentVersion copy];
    _fetcher = [fetcher copy];
    _clock = [clock copy];
    _pendingCompletions = [NSMutableArray array];
    NSString *cachedVersion = [_defaults stringForKey:kAvailableVersionKey];
    if (MetasequoiaVersionIsNewer(cachedVersion, _currentVersion))
    {
        self.availableVersion = cachedVersion;
    }
    else
    {
        [_defaults removeObjectForKey:kAvailableVersionKey];
    }
    return self;
}

- (NSURL *)releaseURL
{
    if (self.availableVersion == nil)
    {
        return nil;
    }
    return [NSURL URLWithString:[kReleasePagePrefix stringByAppendingString:self.availableVersion]];
}

- (void)checkForUpdatesIfNeeded
{
    NSDate *now = _clock();
    NSDate *lastCheck = [_defaults objectForKey:kLastUpdateCheckKey];
    if ([lastCheck isKindOfClass:[NSDate class]])
    {
        NSTimeInterval elapsed = [now timeIntervalSinceDate:lastCheck];
        if (elapsed >= 0.0 && elapsed < kAutomaticCheckInterval)
        {
            return;
        }
    }
    [self checkForUpdates:nil];
}

- (void)checkForUpdates:(MetasequoiaUpdateCheckCompletion)completion
{
    if (completion != nil)
    {
        [_pendingCompletions addObject:[completion copy]];
    }
    if (_checking)
    {
        return;
    }
    _checking = YES;
    [_defaults setObject:_clock() forKey:kLastUpdateCheckKey];
    _fetcher(^(NSData *data, NSInteger statusCode, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MetasequoiaUpdateCheckState state = MetasequoiaUpdateCheckStateFailed;
            if (error == nil && statusCode == 200)
            {
                NSString *latestVersion = MetasequoiaReleaseVersionFromData(data);
                if (latestVersion != nil)
                {
                    if (MetasequoiaVersionIsNewer(latestVersion, self->_currentVersion))
                    {
                        self.availableVersion = latestVersion;
                        [self->_defaults setObject:latestVersion forKey:kAvailableVersionKey];
                        state = MetasequoiaUpdateCheckStateAvailable;
                    }
                    else
                    {
                        self.availableVersion = nil;
                        [self->_defaults removeObjectForKey:kAvailableVersionKey];
                        state = MetasequoiaUpdateCheckStateCurrent;
                    }
                }
            }
            self->_checking = NO;
            NSArray<MetasequoiaUpdateCheckCompletion> *completions = [self->_pendingCompletions copy];
            [self->_pendingCompletions removeAllObjects];
            [[NSNotificationCenter defaultCenter]
                postNotificationName:MetasequoiaUpdateAvailabilityDidChangeNotification
                              object:self];
            for (MetasequoiaUpdateCheckCompletion pendingCompletion in completions)
            {
                pendingCompletion(state);
            }
        });
    });
}

@end
