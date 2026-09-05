#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetasequoiaInputSnapshot : NSObject

@property(nonatomic, readonly, getter=isHandled) BOOL handled;
@property(nonatomic, copy, readonly, nullable) NSString *commitText;
@property(nonatomic, copy, readonly) NSString *preedit;
@property(nonatomic, copy, readonly) NSArray<NSString *> *candidates;
/// Set when the key was handled but something behind it failed, such as a local input mode whose
/// table is missing. Input stays usable, so a frontend reports this rather than failing.
@property(nonatomic, copy, readonly, nullable) NSString *diagnosticText;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface MetasequoiaInputSessionBridge : NSObject

- (MetasequoiaInputSnapshot *)handleCharacter:(NSString *)character;
- (MetasequoiaInputSnapshot *)handleCandidateKey:(NSString *)character;
- (MetasequoiaInputSnapshot *)handlePunctuation:(NSString *)character;
- (MetasequoiaInputSnapshot *)handleBackspace;
- (MetasequoiaInputSnapshot *)commitCandidate;
- (MetasequoiaInputSnapshot *)commitRaw;
- (MetasequoiaInputSnapshot *)cancel;
- (MetasequoiaInputSnapshot *)selectCandidateAtIndex:(NSUInteger)index;
- (MetasequoiaInputSnapshot *)switchToShuangpin:(BOOL)usesShuangpin;

@end

NS_ASSUME_NONNULL_END
