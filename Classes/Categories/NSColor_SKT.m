/*  NSColor_SKT.m
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/
#import "NSColor_SKT.h"

@implementation NSColor(SKT)
// plist i/o: Format is a simple NSArchive.
+ (nullable instancetype)colorWithArchiveData:(nullable NSData *)data {
  NSColor *result = nil;
  if ([data isKindOfClass:[NSData class]]) {
    result = [NSUnarchiver unarchiveObjectWithData:data];
    if ( ! [result isKindOfClass:[NSColor class]]) {
      result = nil;
    }
  }
  return result;
}

- (nonnull NSData *)asArchiveData {
  return [NSArchiver archivedDataWithRootObject:self];
}

@end
