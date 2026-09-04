#import "MetasequoiaInputSessionBridge.h"

#include "InputSessionAdapter.h"

#include <cstdlib>
#include <memory>
#include <string>
#include <utility>

namespace {
NSString *StringFromUTF8(const std::string &value) {
  NSString *string = [[NSString alloc] initWithBytes:value.data()
                                              length:value.size()
                                            encoding:NSUTF8StringEncoding];
  return string == nil ? @"" : string;
}

void ConfigureDataDirectory() {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *applicationSupport =
        [fileManager URLForDirectory:NSApplicationSupportDirectory
                            inDomain:NSUserDomainMask
                   appropriateForURL:nil
                              create:YES
                               error:nil];
    NSURL *dataDirectory =
        [applicationSupport URLByAppendingPathComponent:@"metasequoiaime"
                                            isDirectory:YES];
    if (dataDirectory != nil && [fileManager createDirectoryAtURL:dataDirectory
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil]) {
      setenv("METASEQUOIA_IME_DATA_DIR", dataDirectory.fileSystemRepresentation,
             1);
    }
  });
}
} // namespace

@interface MetasequoiaInputSnapshot ()

- (instancetype)initWithHandled:(BOOL)handled
                     commitText:(nullable NSString *)commitText
                        preedit:(NSString *)preedit
                     candidates:(NSArray<NSString *> *)candidates;

@end

@implementation MetasequoiaInputSnapshot

- (instancetype)initWithHandled:(BOOL)handled
                     commitText:(nullable NSString *)commitText
                        preedit:(NSString *)preedit
                     candidates:(NSArray<NSString *> *)candidates {
  self = [super init];
  if (self != nil) {
    _handled = handled;
    _commitText = [commitText copy];
    _preedit = [preedit copy];
    _candidates = [candidates copy];
  }
  return self;
}

@end

@implementation MetasequoiaInputSessionBridge {
  std::unique_ptr<metasequoia::apple::InputSessionAdapter> _adapter;
}

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    ConfigureDataDirectory();
    _adapter = std::make_unique<metasequoia::apple::InputSessionAdapter>();
  }
  return self;
}

- (MetasequoiaInputSnapshot *)handleCharacter:(NSString *)character {
  const char *utf8 = character.UTF8String;
  if (utf8 == nullptr || utf8[0] == '\0' || utf8[1] != '\0') {
    return [self snapshotFrom:_adapter->handle_character('\0')];
  }
  return [self snapshotFrom:_adapter->handle_character(utf8[0])];
}

- (MetasequoiaInputSnapshot *)handleBackspace {
  return [self snapshotFrom:_adapter->handle_backspace()];
}

- (MetasequoiaInputSnapshot *)commitCandidate {
  return [self snapshotFrom:_adapter->commit_candidate()];
}

- (MetasequoiaInputSnapshot *)commitRaw {
  return [self snapshotFrom:_adapter->commit_raw()];
}

- (MetasequoiaInputSnapshot *)cancel {
  return [self snapshotFrom:_adapter->cancel()];
}

- (MetasequoiaInputSnapshot *)selectCandidateAtIndex:(NSUInteger)index {
  return [self
      snapshotFrom:_adapter->select_candidate(static_cast<std::size_t>(index))];
}

- (MetasequoiaInputSnapshot *)snapshotFrom:
    (metasequoia::apple::InputSnapshot)snapshot {
  NSMutableArray<NSString *> *candidates =
      [NSMutableArray arrayWithCapacity:snapshot.candidates.size()];
  for (const auto &candidate : snapshot.candidates) {
    [candidates addObject:StringFromUTF8(candidate)];
  }

  NSString *commitText =
      snapshot.commit.has_value() ? StringFromUTF8(*snapshot.commit) : nil;
  return [[MetasequoiaInputSnapshot alloc]
      initWithHandled:snapshot.handled
           commitText:commitText
              preedit:StringFromUTF8(snapshot.preedit)
           candidates:candidates];
}

@end
