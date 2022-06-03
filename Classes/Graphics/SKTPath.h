/*  SKTPath.h
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTGraphic.h"

@class SKTPathAtom;

extern NSString *const SKTPathString;

// Represents an SVG path. Basically an array of path atoms.
@interface SKTPath : SKTGraphic

@property (NS_NONATOMIC_IOSONLY, getter = isClosed) BOOL closed;

+ (NSMutableArray *)stringToPathAtoms:(NSString *)s;

// KVO Compliance
- (NSUInteger)countOfPathAtom;
- (NSArray<SKTPathAtom *> *)pathAtomAtIndexes:(NSIndexSet *)indexes;
- (void)removePathAtomAtIndexes:(NSIndexSet *)indexes;
- (void)insertPathAtom:(NSArray<SKTPathAtom *> *)atoms atIndexes:(NSIndexSet *)indexes;
- (void)replacePathAtomAtIndexes:(NSIndexSet *)indexes withPathAtom:(NSArray<SKTPathAtom *> *)objects;

@end
