//
//  SKTParhScanner.h
//  FloorSketch
//
//  Created by david on 1/30/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

enum {
  SKTScannerMaxArgCount = 7
};

/**
 A scanner for parsing the d attribute of an SVG path.
 */
@interface SKTPathScanner : NSObject <NSCopying>

@property (readonly, copy) NSString *string;

- (instancetype)initWithString:(NSString *)string NS_DESIGNATED_INITIALIZER;

/// A scanner suitable for reading a <path> d attribute.
+ (instancetype)scannerWithString:(NSString *)string;

/// Returns true each time it successfully reads an atom from the string.
/// may store up to SKTScannerMaxArgCount into the writeable float array.
- (BOOL)getVerb:(unichar *)verbp argCount:(NSUInteger *)countp args:(CGFloat *)args;

@end

NS_ASSUME_NONNULL_END
