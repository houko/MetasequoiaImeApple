#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetasequoiaInputSnapshot : NSObject

@property(nonatomic, readonly, getter=isHandled) BOOL handled;
@property(nonatomic, copy, readonly, nullable) NSString *commitText;
@property(nonatomic, copy, readonly) NSString *preedit;
@property(nonatomic, copy, readonly) NSArray<NSString *> *candidates;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface MetasequoiaInputSessionBridge : NSObject

- (MetasequoiaInputSnapshot *)handleCharacter:(NSString *)character;
- (MetasequoiaInputSnapshot *)handleBackspace;
- (MetasequoiaInputSnapshot *)commitCandidate;
- (MetasequoiaInputSnapshot *)commitRaw;
- (MetasequoiaInputSnapshot *)cancel;
- (MetasequoiaInputSnapshot *)selectCandidateAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
