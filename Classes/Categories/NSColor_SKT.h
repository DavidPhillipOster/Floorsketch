/*  NSColor_SKT.h
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import <Foundation/Foundation.h>

@interface NSColor(SKT)
// plist i/o: Format is a simple NSArchive.
+ (nullable instancetype)colorWithArchiveData:(nullable NSData *)data;

- (nonnull NSData *)asArchiveData;
@end
