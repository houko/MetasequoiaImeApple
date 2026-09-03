#pragma once

#import <Foundation/Foundation.h>

BOOL EnsureMetasequoiaDictionary(NSError **error);
BOOL PrepareMetasequoiaDictionary(NSURL *source, NSURL *dataDirectory, NSString *dictionaryFingerprint,
                                  NSError **error);
BOOL InstallMetasequoiaDictionary(NSURL *source, NSURL *dataDirectory, NSString *dictionaryFingerprint,
                                  NSError **error);
