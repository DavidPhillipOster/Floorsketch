/*  SKTPoly.m
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTPoly.h"

#import "NSColor_SKT.h"
#import "SKTVertex.h"

NSString *const SKTPolyPoints = @"pts";

NSString *const SKTPolyVertex = @"vertex";


@interface SKTPoly()
@property(nonatomic) NSMutableArray *pts;
@end

@implementation SKTPoly

- (instancetype)init {
  self = [super init];
  if (self) {
    _pts = [NSMutableArray array];
  }
  return self;
}

- (instancetype)initWithProperties:(NSDictionary *)properties {
  self = [super initWithProperties:properties];
  if (self) {
    _closed = [properties[SKTGraphicClosed] boolValue];
    NSString *s = properties[SKTPolyPoints];
    if ([s respondsToSelector:@selector(characterAtIndex:)]) {
      _pts = [SKTPoly stringToPoints:s];
      [self setBounds:[self computeBounds]];
    } else {
      return nil;
    }
  }
  return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
  SKTPoly *result = [super copyWithZone:zone];
  if (_closed) {
    [result setClosed:YES];
  }
  [result setPts:[[self pts] mutableCopyWithZone:zone]];
  return result;
}

- (CGRect)computeBounds {
  if (0 == [_pts count]) {
    return CGRectZero;
  }
  CGPoint minP = [_pts[0] pointValue];
  CGPoint maxP = minP;
  for (NSValue *pV in _pts) {
    CGPoint pt = [pV pointValue];
    if (pt.x < minP.x) {
      minP.x = pt.x;
    }
    if (maxP.x < pt.x) {
      maxP.x = pt.x;
    }
    if (pt.y < minP.y) {
      minP.y = pt.y;
    }
    if (maxP.y < pt.y) {
      maxP.y = pt.y;
    }
  }
  return CGRectMake(minP.x, minP.y, maxP.x - minP.x, maxP.y - minP.y);
}

+ (NSMutableArray *)stringToPoints:(NSString *)s {
  NSMutableArray *a = [NSMutableArray array];
  NSScanner *scanner = [[NSScanner alloc] initWithString:s];
  NSMutableCharacterSet *skipChars = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
  [skipChars addCharactersInString:@","];
  [scanner setCharactersToBeSkipped:skipChars];
  float x, y;
  while ([scanner scanFloat:&x] && [scanner scanFloat:&y]) {
    if (!(isnan(x) || isnan(y))) {
      NSValue *p = [NSValue valueWithPoint:CGPointMake(x, y)];
      [a addObject:p];
    }
  }
  return a;
}

- (NSMutableDictionary *)properties {
  NSMutableDictionary *properties = [super properties];
  if ([self isClosed]) {
    properties[SKTGraphicClosed] = @YES;
  }
  properties[SKTPolyPoints] = [self ptsAsString];
  return properties;
}

- (NSBezierPath *)bezierPathForDrawing {
  NSBezierPath *path = nil;
  NSUInteger count = [_pts count];
  if (2 <= count) {
    path = [NSBezierPath bezierPath];
    CGPoint p = [self ptAtIndex:0];
    [path moveToPoint:p];
    for (NSUInteger i = 1; i < count; ++i) {
      CGPoint p = [self ptAtIndex:i];
      [path lineToPoint:p];
    }
    if ([self isClosed]) {
      [path closePath];
    }
  }
  CGFloat lineWidth = [self strokeWidth];
  if (0 < lineWidth && lineWidth < 1) {
    lineWidth = 0;
  }
  [path setLineWidth:lineWidth];
  return path;
}

- (BOOL)isContentsUnderPoint:(NSPoint)point {
  return [[self bezierPathForDrawing] containsPoint:point];
}

- (NSString *)asSVGString {
  return [self asSVGStringVerb:[self isClosed] ? @"polygon" : @"polyline"];
}

- (NSString *)svgAttributesString {
  return [NSString stringWithFormat:@"points=\"%@\" %@",
    [self ptsAsString],
    [super svgAttributesString]];
}

- (NSString *)ptsAsString {
  NSMutableArray *a = [NSMutableArray array];
  for (NSValue *pV in _pts) {
    CGPoint pt = [pV pointValue];
    NSString *s = [NSString stringWithFormat:@"%.5g,%.5g", pt.x, pt.y];
    [a addObject:s];
  }
  return [a componentsJoinedByString:@"  "];
}

- (void)setBounds:(CGRect)bounds {
  [super setBounds:bounds];
  if (0.001 <= bounds.size.width && 0.001 <= bounds.size.height && nil == _pts) {
#if 0 // diamond
    CGPoint p1 = CGPointMake(bounds.origin.x, bounds.origin.y + bounds.size.height/2);
    CGPoint p2 = CGPointMake(bounds.origin.x + bounds.size.width/2, bounds.origin.y);
    CGPoint p3 = CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height/2);
    CGPoint p4 = CGPointMake(bounds.origin.x + bounds.size.width/2, bounds.origin.y + bounds.size.height);
    _pts = [@[ [NSValue valueWithPoint:p1], [NSValue valueWithPoint:p2], [NSValue valueWithPoint:p3], [NSValue valueWithPoint:p4] ] mutableCopy];
#else
    // Assme we're creating interactively.
    CGPoint p1 = CGPointMake(bounds.origin.x, bounds.origin.y + bounds.size.height);
    CGPoint p2 = CGPointMake(bounds.origin.x + bounds.size.width/2, bounds.origin.y);
    CGPoint p3 = CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height);
    _pts = [@[ [NSValue valueWithPoint:p1], [NSValue valueWithPoint:p2], [NSValue valueWithPoint:p3] ] mutableCopy];
#endif
    _closed = YES;
  }
  CGRect oldBounds = [self computeBounds];

  if ( ! CGRectEqualToRect(bounds, oldBounds)) {
    CGPoint translate = CGPointMake(bounds.origin.x - oldBounds.origin.x, bounds.origin.y - oldBounds.origin.y);
    if ( ! CGPointEqualToPoint(CGPointZero, translate)) {
      int count = (int)[_pts count];
      for (int i = 0; i < count; ++i) {
        NSValue *pV = _pts[i];
        CGPoint pt = [pV pointValue];
        pt.x += translate.x;
        pt.y += translate.y;
        pV = [NSValue valueWithPoint:pt];
        _pts[i] = pV;
      }
    }
    CGFloat sx;
    if (oldBounds.size.width == 0){
      sx = 1;
    } else {
      sx = bounds.size.width / oldBounds.size.width;
    }
    CGFloat sy;
    if (oldBounds.size.height == 0) {
      sy = 1;
    } else {
      sy = bounds.size.height / oldBounds.size.height;
    }
    CGSize scale = CGSizeMake(sx, sy);
    if ( ! CGSizeEqualToSize(CGSizeMake(1,1), scale)) {
      int count = (int)[_pts count];
      for (int i = 0; i < count; ++i) {
        NSValue *pV = _pts[i];
        CGPoint pt = [pV pointValue];
        pt.x = ((pt.x - bounds.origin.x) * scale.width) + bounds.origin.x;
        pt.y = ((pt.y- bounds.origin.y) * scale.height) + bounds.origin.y;
        pV = [NSValue valueWithPoint:pt];
        _pts[i] = pV;
      }
    }
  }
}

- (void)flipHorizontally {
  CGRect bounds = [self bounds];
  int count = (int)[_pts count];
  for (int i = 0; i < count; ++i) {
    NSValue *pV = _pts[i];
    CGPoint pt = [pV pointValue];
    pt.x = (bounds.origin.x + bounds.size.width) - (pt.x - bounds.origin.x);
    pV = [NSValue valueWithPoint:pt];
    _pts[i] = pV;
  }
}

- (void)flipVertically {
  CGRect bounds = [self bounds];
  int count = (int)[_pts count];
  for (int i = 0; i < count; ++i) {
    NSValue *pV = _pts[i];
    CGPoint pt = [pV pointValue];
    pt.y = (bounds.origin.y + bounds.size.height) - (pt.y - bounds.origin.y);
    pV = [NSValue valueWithPoint:pt];
    _pts[i] = pV;
  }
}

- (NSUInteger)countOfPt {
  return [_pts count];
}

- (CGPoint)ptAtIndex:(NSUInteger)index {
  NSValue *p = _pts[index];
  return [p pointValue];
}

- (void)addPt:(CGPoint)pt {
  [self insertPt:pt atIndex:[self countOfPt]];
}

- (void)insertPt:(CGPoint)pt atIndex:(NSUInteger)index {
  NSValue *p = [NSValue valueWithPoint:pt];
  [_pts insertObject:p atIndex:index];
}

- (void)removeLastPt {
  NSUInteger count = [self countOfPt];
  if (count) {
    [self removePtAtIndex:count -1];
  }
}

- (void)removePtAtIndex:(NSUInteger)index {
  [_pts removeObjectAtIndex:index];
}

- (void)replacePtAtIndex:(NSUInteger)index withPt:(CGPoint)pt {
  CGPoint oldPt = [self ptAtIndex:index];
  if ( ! CGPointEqualToPoint(pt, oldPt)) {
    NSUndoManager *undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget:self] replacePtAtIndex:index withPt:oldPt];
    if ( ! ([undoManager isUndoing] || [undoManager isRedoing])) {
      [undoManager setActionName:NSLocalizedStringFromTable(@"Move Vertex", @"UndoStrings", @"Action name for moving a point.")];
    }
    NSValue *p = [NSValue valueWithPoint:pt];
    [_pts replaceObjectAtIndex:index withObject:p];
    [self updateBounds];
  }
}

// Call this after modifying the points array to trigger drawing by changing bounds.
// self setbounds would try to translate/scale to new bounds, so we call super to skup that.
// Incrementing the ipdate count before and after the change triggers a redraw of the old and new positions.
- (void)updateBounds {
  [self setUpdateCount:1 + [self updateCount]];
  CGRect newBounds = [self computeBounds];
  [super setBounds:newBounds];
  [self setUpdateCount:1 + [self updateCount]];
}

- (NSUInteger)countOfVertex {
  return [_pts count];
}

- (NSArray < SKTVertex *> *)vertexAtIndexes:(NSIndexSet *)indexes {
  NSMutableArray *vertices = [NSMutableArray array];
  for (NSUInteger i = [indexes firstIndex]; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) {
    NSValue *pV = _pts[i];
    CGPoint pt = [pV pointValue];
    SKTVertex *vertex = [[SKTVertex alloc] init];
    vertex.xPosition = pt.x;
    vertex.yPosition = pt.y;
    vertex.index = i;
    vertex.scriptingContainer = self;
    [vertices addObject:vertex];
  }
  return vertices;
}

- (void)removeVertexAtIndexes:(NSIndexSet *)indexes {
  // Make it undoable.
  NSUndoManager *undoManager = [self undoManager];
  [[undoManager prepareWithInvocationTarget:self] insertVertex:[self vertexAtIndexes:indexes] atIndexes:indexes];
  if ( ! ([undoManager isUndoing] || [undoManager isRedoing])) {
    NSString *s;
    if (1 == [indexes count]) {
      s = NSLocalizedStringFromTable(@"Delete Vertex", @"UndoStrings", @"Action name for moving a point.");
    } else {
      s = NSLocalizedStringFromTable(@"Delete Vertices", @"UndoStrings", @"Action name for moving points.");
    }
    [undoManager setActionName:s];
  }
  [_pts removeObjectsAtIndexes:indexes];
  [self updateBounds];
}

- (void)insertVertex:(NSArray < SKTVertex *> *)vertices atIndexes:(NSIndexSet *)indexes {
  // Make it undoable.
  NSUndoManager *undoManager = [self undoManager];
  [undoManager registerUndoWithTarget:self selector:@selector(removeVertexAtIndexes:) object:indexes];
  if ( ! ([undoManager isUndoing] || [undoManager isRedoing])) {
    NSString *s;
    if (1 == [indexes count]) {
      s = NSLocalizedStringFromTable(@"Add Vertex", @"UndoStrings", @"Action name for moving a point.");
    } else {
      s = NSLocalizedStringFromTable(@"Add Vertices", @"UndoStrings", @"Action name for moving points.");
    }
    [undoManager setActionName:s];
  }
  NSMutableArray *a = [NSMutableArray array];
  for (SKTVertex *v in vertices) {
    CGPoint p = CGPointMake(v.xPosition, v.yPosition);
    NSValue *pV = [NSValue valueWithPoint:p];
    [a addObject:pV];
  }
  [_pts insertObjects:a atIndexes:indexes];
  [self updateBounds];
}

- (void)replaceVertexAtIndexes:(NSIndexSet *)indexes withVertex:(NSArray < SKTVertex *> *)objects {
  // Make it undoable.
  NSUndoManager *undoManager = [self undoManager];
  [[undoManager prepareWithInvocationTarget:self] replaceVertexAtIndexes:indexes withVertex:[self vertexAtIndexes:indexes]];
  if ( ! ([undoManager isUndoing] || [undoManager isRedoing])) {
    NSString *s;
    if (1 == [indexes count]) {
      s = NSLocalizedStringFromTable(@"Move Vertex", @"UndoStrings", @"Action name for moving a point.");
    } else {
      s = NSLocalizedStringFromTable(@"Move Vertices", @"UndoStrings", @"Action name for moving points.");
    }
    [undoManager setActionName:s];
  }

  for (NSUInteger k = [objects count] - 1, i = [indexes lastIndex]; NSNotFound != i; i = [indexes indexLessThanIndex:i], --k) {
    SKTVertex *v = objects[k];
    CGPoint p = CGPointMake(v.xPosition, v.yPosition);
    NSValue *pV = [NSValue valueWithPoint:p];
    _pts[i] = pV;
  }
  [self updateBounds];
}

- (NSArray < SKTVertex *> *)vertexs {
  return [self vertices];
}

- (BOOL)canOpenPolygon {
  return self.closed;
}

- (BOOL)canClosePolygon {
  return !self.closed;
}

- (SKTGraphic *)graphicByOpening {
  [self setClosed:NO];
  return [self copy];
}

- (SKTGraphic *)graphicByClosing {
  [self setClosed:YES];
  return [self copy];
}


#pragma mark - Drawing

// The only properties managed by SKTGraphic that affect the drawing bounds are the bounds and the the stroke width.
+ (NSSet *)keyPathsForValuesAffectingDrawingBounds {
  NSMutableSet *result = [[super keyPathsForValuesAffectingDrawingBounds] mutableCopy];
  [result addObjectsFromArray:@[SKTGraphicClosed, SKTPolyPoints, SKTPolyVertex]];
  return result;
}

#pragma mark - Undo

- (NSUndoManager *)undoManager {
  NSUndoManager *result = nil;
  if ([self.scriptingContainer respondsToSelector:@selector(undoManager)]) {
    result = [self.scriptingContainer performSelector:@selector(undoManager)];
  }
  return result;
}

- (NSSet *)keysForValuesToObserveForUndo {
  NSMutableSet *keys = [[super keysForValuesToObserveForUndo] mutableCopy];
  [keys addObject:SKTGraphicClosed];
  return keys;
}

+ (NSString *)presentablePropertyNameForKey:(NSString *)key {
  static NSDictionary *presentablePropertyNamesByKey = nil;
  if (!presentablePropertyNamesByKey) {
    presentablePropertyNamesByKey = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                     NSLocalizedStringFromTable(@"closed", @"UndoStrings", @"Action noun part for SKTGraphicClosed."), SKTGraphicClosed,
                                     nil];
  }
  NSString *presentablePropertyName = presentablePropertyNamesByKey[key];
  if (!presentablePropertyName) {
    presentablePropertyName = [super presentablePropertyNameForKey:key];
  }
  return presentablePropertyName;
}

#pragma mark - Scripting

- (NSArray *)vertices {
  NSMutableArray *vertices = [NSMutableArray array];
  int count = (int)[_pts count];
  for (int i = 0; i < count; ++i) {
    NSValue *pV = _pts[i];
    CGPoint pt = [pV pointValue];
    SKTVertex *vertex = [[SKTVertex alloc] init];
    vertex.xPosition = pt.x;
    vertex.yPosition = pt.y;
    vertex.index = i;
    vertex.scriptingContainer = self;
    [vertices addObject:vertex];
  }
  return vertices;
}

// Conformance to the NSObject(SKTGraphicScriptingContainer) informal protocol.
// vertices don't have unique IDs or names, so just return an index specifier.
- (NSScriptObjectSpecifier *)objectSpecifierForVertex:(SKTVertex *)vertex {
  NSScriptObjectSpecifier *objectSpecifier = [self objectSpecifier];
  NSScriptObjectSpecifier *vertexObjectSpecifier = [[NSIndexSpecifier alloc] initWithContainerClassDescription:[objectSpecifier keyClassDescription] containerSpecifier:objectSpecifier key:@"vertices" index:[vertex index]];
  return vertexObjectSpecifier;

}

@end
