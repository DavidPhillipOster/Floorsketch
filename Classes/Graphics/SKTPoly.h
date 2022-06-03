/*  SKTPoly.h
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTGraphic.h"

@class SKTVertex;

extern NSString *const SKTPolyPoints; // float pairs as text. x,y _  (svg:commas are optional. whitespace will do.)
extern NSString *const SKTPolyVertex;

// A polygon (closed) or a polyline (not)
@interface SKTPoly : SKTGraphic

@property (NS_NONATOMIC_IOSONLY, getter = isClosed) BOOL closed;

@property (readonly) NSUInteger countOfPt;
- (CGPoint)ptAtIndex:(NSUInteger)index;

- (void)addPt:(CGPoint)anPt;
- (void)insertPt:(CGPoint)anPt atIndex:(NSUInteger)index;
- (void)removeLastPt;
- (void)removePtAtIndex:(NSUInteger)index;
- (void)replacePtAtIndex:(NSUInteger)index withPt:(CGPoint)anPt;

- (void)updateBounds;

// KVO Compliance
- (NSUInteger)countOfVertex;
- (NSArray<SKTVertex *> *)vertexAtIndexes:(NSIndexSet *)indexes;
- (void)removeVertexAtIndexes:(NSIndexSet *)indexes;
- (void)insertVertex:(NSArray<SKTVertex *> *)vertices atIndexes:(NSIndexSet *)indexes;
- (void)replaceVertexAtIndexes:(NSIndexSet *)indexes withVertex:(NSArray<SKTVertex *> *)objects;

@end
