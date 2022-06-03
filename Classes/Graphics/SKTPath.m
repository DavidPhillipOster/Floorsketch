/*  SKTPath.m
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTPath.h"

#import "NSColor_SKT.h"
#import "SKTPathAtom.h"
#import "SKTPathScanner.h"

NSString *const SKTPathString = @"pathString";

@interface SKTPath()
@property(nonatomic) NSMutableArray *atoms;
@end

@implementation SKTPath

- (instancetype)initWithProperties:(NSDictionary *)properties {
  self = [super initWithProperties:properties];
  if (self) {
    _closed = [properties[SKTGraphicClosed] boolValue];
    NSString *s = properties[SKTPathString];
    if ([s respondsToSelector:@selector(characterAtIndex:)]) {
      _atoms = [SKTPath stringToPathAtoms:s];
      CGRect bounds = [self computeBounds];
      if (CGRectIsEmpty(bounds)) {
        return nil;
      }
      [self setBounds:bounds];
    } else {
      return nil;
    }
  }
  return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
  SKTPath *result = [super copyWithZone:zone];
  if (_closed) {
    [result setClosed:YES];
  }
  NSMutableArray *atomsCopy = [[self atoms] mutableCopyWithZone:zone];
  NSUInteger count = [atomsCopy count];
  for (NSUInteger i = 0; i < count; ++i) {
    atomsCopy[i] = [atomsCopy[i] copyWithZone:zone];
  }
  [result setAtoms:atomsCopy];
  return result;
}

- (CGRect)computeBounds {
  CGPoint minP;
  CGPoint maxP;
  BOOL didInit = NO;
  for (SKTPathAtom *pA in _atoms) {
    if (pA.hasPointValue) {
      if ( ! didInit) {
        maxP = minP = [pA pointValue];
        didInit = YES;
      } else {
        MinMaxPt minMaxPt = [pA minMax];
        if (minMaxPt.min.x < minP.x) {
          minP.x = minMaxPt.min.x;
        }
        if (maxP.x < minMaxPt.max.x) {
          maxP.x = minMaxPt.max.x;
        }
        if (minMaxPt.min.y < minP.y) {
          minP.y = minMaxPt.min.y;
        }
        if (maxP.y < minMaxPt.max.y) {
          maxP.y = minMaxPt.max.y;
        }
      }
    }
  }
  if ( ! didInit) {
    return CGRectZero;
  }
  return CGRectMake(minP.x, minP.y, maxP.x - minP.x, maxP.y - minP.y);
}

- (NSBezierPath *)bezierPathForDrawing {
  NSBezierPath *path = nil;
  NSUInteger count = [_atoms count];
  if (2 <= count) {
		CGPoint position = CGPointZero;
    path = [NSBezierPath bezierPath];
    for (SKTPathAtom *atom in _atoms) {
      [atom appendToPath:path nowAt:&position];
    }
    if ([self isClosed]) {
      [path closePath];
    }
  }
  [path setLineWidth:[self strokeWidth]];
  return path;
}

- (void)setBounds:(CGRect)bounds {
  [super setBounds:bounds];
  if (0.001 <= bounds.size.width && 0.001 <= bounds.size.height && nil == _atoms) {
    // Assme we're creating interactively.
    CGPoint p1 = CGPointMake(bounds.origin.x, bounds.origin.y + bounds.size.height);
    CGPoint p2 = CGPointMake(bounds.origin.x + bounds.size.width/2, bounds.origin.y);
    CGPoint p3 = CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height);
    _atoms = [@[ [SKTPathAtom pathAtomWithPt:p1], [SKTPathAtom pathAtomWithPt:p2], [SKTPathAtom pathAtomWithPt:p3] ] mutableCopy];
    _closed = YES;
  }
  CGRect oldBounds = [self computeBounds];

  if ( ! CGRectEqualToRect(bounds, oldBounds)) {
    CGPoint translate = CGPointMake(bounds.origin.x - oldBounds.origin.x, bounds.origin.y - oldBounds.origin.y);
    if ( ! CGPointEqualToPoint(CGPointZero, translate)) {
      for (SKTPathAtom *atom in _atoms) {
        [atom translateBy:translate];
      }
    }
    CGSize scale = CGSizeMake(bounds.size.width / oldBounds.size.width, bounds.size.height / oldBounds.size.height);
    if ( ! CGSizeEqualToSize(CGSizeMake(1,1), scale)) {
      for (SKTPathAtom *atom in _atoms) {
        [atom scale:scale relativeToOrigin:bounds.origin];
      }
    }
  }
}

- (void)flipHorizontally {
  CGRect bounds = [self bounds];
  for (SKTPathAtom *atom in _atoms) {
    [atom flipHorizontallyRelatveToBounds:bounds];
  }
}

- (void)flipVertically {
  CGRect bounds = [self bounds];
  for (SKTPathAtom *atom in _atoms) {
    [atom flipVerticallyRelatveToBounds:bounds];
  }
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


- (BOOL)isContentsUnderPoint:(NSPoint)point {
  return [[self bezierPathForDrawing] containsPoint:point];
}

- (NSString *)asSVGString {
  return [self asSVGStringVerb:@"path"];
}

- (NSString *)svgAttributesString {
  return [NSString stringWithFormat:@"d=\"%@\" %@",
    [self atomsAsString],
    [super svgAttributesString]];
}

/*
M x,y
L x,y
V y
C x1,y1, x2,y2 x,y cubic Bezier curve to (x,y) p1, and p2 are start, end control points.
S x2,y2, x,y cubic Bezier curve to (x,y)  (x2,y2) is the end control point.
The start control point is a copy of the end control point of the previous curve command. If the previous command wasn't a cubic Bézier curve, the start control point is the same as the curve starting point (current point)
Q x1,y1 x,y quadratic Bezier curve to (x,y)
T x,y quadratic Bezier curve to (x,y). Control point is assumed to be the same as the last control point used.
A rx ry x-axis-rotation large-arc-flag sweepflag x, y
Draws arc to the point (x,y)
The values rx and ry are the radiuses of the ellipse.
The x-axis-rotation rotates the ellipse the arc is created from (without changing start/end point).
The large-arc-flag (0 or 1) determines how wide the arc is.
The sweepflag (0 or 1) determines which way the arc goes (underneath or above).
Z Closepath
 */
+ (NSMutableArray *)stringToPathAtoms:(NSString *)s {
  NSMutableArray *a = [NSMutableArray array];
  SKTPathScanner *scanner = [SKTPathScanner scannerWithString:s];
  unichar verb;
  NSUInteger argCount;
  CGFloat args[SKTScannerMaxArgCount];
  CGPoint lastPoint = CGPointZero;
  CGPoint lastControlPoint = CGPointZero;
  while ([scanner getVerb:&verb argCount:&argCount args:args]) {
    switch (verb) {
      case 'H':
      case 'h': {
        CGPoint deltaPoint = CGPointZero;
        if (verb == 'h') {
          deltaPoint = lastPoint;
        }

        lastPoint.x = args[0] + deltaPoint.x;
        SKTPathLine *at = [[SKTPathLine alloc] init];
        at.p = lastPoint;
        [a addObject:at];
        break;
        }
      case 'V':
      case 'v': {
        CGPoint deltaPoint = CGPointZero;
        if (verb == 'v') {
          deltaPoint = lastPoint;
        }
        lastPoint.y = args[0] + deltaPoint.y;
        SKTPathLine *at = [SKTPathLine pathAtomWithPt:lastPoint];
        [a addObject:at];
        break;
      }
      case 'L':
      case 'l': {
        CGPoint deltaPoint = CGPointZero;
        if (verb == 'l') {
          deltaPoint = lastPoint;
        }
        lastPoint.x = args[0] + deltaPoint.x;
        lastPoint.y = args[1] + deltaPoint.y;
        SKTPathLine *at = [SKTPathLine pathAtomWithPt:lastPoint];
        [a addObject:at];
        break;
      }
      case 'M':
      case 'm':  {
        CGPoint deltaPoint = CGPointZero;
        if (verb == 'm') {
          deltaPoint = lastPoint;
        }
        lastPoint.x = args[0] + deltaPoint.x;
        lastPoint.y = args[1] + deltaPoint.y;
        SKTPathPoint *at = [SKTPathPoint pathAtomWithPt:lastPoint];
        [a addObject:at];
        break;
      }
      case 'T':
      case 't': {
        CGPoint deltaPoint = CGPointZero;
        if (verb == 't') {
          deltaPoint = lastPoint;
        }
        CGPoint p = CGPointMake(deltaPoint.x + args[0], deltaPoint.y + args[1]);
        SKTPathQuadratic *at = [SKTPathQuadratic pathAtomWithPt:p];
        at.pControl1 = [self reflect:lastControlPoint about:lastPoint];
        lastPoint = p;
        lastControlPoint = at.pControl1;
        [a addObject:at];
        break;
      }
      case 'Z':
      case 'z': {
        SKTPathAtom *at = [[SKTPathClosed alloc] init];
        [a addObject:at];
        break;
      }
      case 'A':
      case 'a': {
        CGPoint deltaPoint = CGPointZero;
        if (verb == 'a') {
          deltaPoint = lastPoint;
        }
        CGPoint p = CGPointMake(deltaPoint.x + args[5], deltaPoint.y + args[6]);
        if (p.x == p.y) { } // for unused warning.
        SKTPathArc *at = [[SKTPathArc alloc] init];
        at.radius = args[0];
        if (at.radius == args[1]) { // circular arc.
          // lastPoint is on the circle. P is on the circle. We know the radius. Find the two centers.
          // Use the boolean parameters to pick which center and which arc.
        } else {  // elliptical arc.
         /*  https://github.com/GenerallyHelpfulSoftware/SVGgh/blob/master/SVGgh/SVG/SVGUtilities.m line 1764
            ~/Work/Playground/macSVG/macSVG/macSVG/SVG\ Functions/SVGtoCoreGraphicsConverter.m line 1523
          */
        }
        NSLog(@"arc needs work");
        break;
      }
      case 'C':
      case 'c': {
        CGPoint deltaPoint = CGPointZero;
        if (verb == 'c') {
          deltaPoint = lastPoint;
        }
        lastPoint = CGPointMake(args[4]+deltaPoint.x, args[5]+deltaPoint.y);
        SKTPathCubic *at = [SKTPathCubic pathAtomWithPt:lastPoint];
        at.pControl1 = CGPointMake(args[0]+deltaPoint.x, args[1]+deltaPoint.y);
        at.pControl2 = CGPointMake(args[2]+deltaPoint.x, args[3]+deltaPoint.y);
        lastControlPoint = at.pControl2;
        [a addObject:at];
        break;
      }
      case 'Q':
      case 'q': {
        CGPoint deltaPoint = CGPointZero;
        if (verb == 'q') {
          deltaPoint = lastPoint;
        }
        lastPoint = CGPointMake(args[2]+deltaPoint.x, args[3]+deltaPoint.y);
        SKTPathQuadratic *at = [SKTPathQuadratic pathAtomWithPt:lastPoint];
        lastControlPoint = CGPointMake(args[0]+deltaPoint.x, args[1]+deltaPoint.y);
        at.pControl1 = lastControlPoint;
        [a addObject:at];
        break;
      }
      case 'S':
      case 's': {
        CGPoint deltaPoint = CGPointZero;
        if (verb == 's') {
          deltaPoint = lastPoint;
        }
        CGPoint p = CGPointMake(args[2]+deltaPoint.x, args[3]+deltaPoint.y);
        SKTPathCubic *at = [SKTPathCubic pathAtomWithPt:p];
        at.pControl1 = [self reflect:lastControlPoint about:lastPoint];
        at.pControl2 = CGPointMake(args[0]+deltaPoint.x, args[1]+deltaPoint.y);
        lastControlPoint = at.pControl2;
        lastPoint = p;
        [a addObject:at];
        break;
      }
      default:
        [NSException raise:NSInternalInconsistencyException format:@"TODO: stringToPathAtoms"];
        break;
    }
  }
  return a;
}

// reflect point 'target' about 'center'
+ (CGPoint)reflect:(CGPoint)target about:(CGPoint)center {
  target.x -= center.x;
  target.y -= center.y;

  target.x = -target.x;
  target.y = -target.y;

  target.x += center.x;
  target.y += center.y;
  return target;
}

- (NSMutableDictionary *)properties {
  NSMutableDictionary *properties = [super properties];
  if ([self isClosed]) {
    properties[SKTGraphicClosed] = @YES;
  }
  properties[SKTPathString] = [self atomsAsString];
  return properties;
}

- (NSString *)atomsAsString {
  NSMutableArray *a = [NSMutableArray array];
  for (SKTPathAtom *pA in _atoms) {
    NSString *svg = [pA svgString];
    [a addObject:svg];
  }
  return [a componentsJoinedByString:@"  "];
}


- (NSUInteger)countOfPathAtom {
  return [_atoms count];
}

- (NSArray<SKTPathAtom *> *)pathAtomAtIndexes:(NSIndexSet *)indexes {
  NSMutableArray *result = [NSMutableArray array];
  for (NSUInteger i = [indexes firstIndex]; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) {
    SKTPathAtom *atom = _atoms[i];
    atom.index = i;
    atom.scriptingContainer = self;
    [result addObject:atom];
  }
  return result;
}

- (void)removePathAtomAtIndexes:(NSIndexSet *)indexes {
  // Make it undoable.
  NSUndoManager *undoManager = [self undoManager];
  [[undoManager prepareWithInvocationTarget:self] insertPathAtom:[self pathAtomAtIndexes:indexes] atIndexes:indexes];
  if ( ! ([undoManager isUndoing] || [undoManager isRedoing])) {
    NSString *s;
    if (1 == [indexes count]) {
      s = NSLocalizedStringFromTable(@"Delete PathAtom", @"UndoStrings", @"Action name for moving a point.");
    } else {
      s = NSLocalizedStringFromTable(@"Delete PathAtoms", @"UndoStrings", @"Action name for moving points.");
    }
    [undoManager setActionName:s];
  }

  [_atoms removeObjectsAtIndexes:indexes];
  [self updateBounds];
}

- (void)insertPathAtom:(NSArray<SKTPathAtom *> *)atoms atIndexes:(NSIndexSet *)indexes {
  // Make it undoable.
  NSUndoManager *undoManager = [self undoManager];
  [undoManager registerUndoWithTarget:self selector:@selector(removePathAtomAtIndexes:) object:indexes];
  if ( ! ([undoManager isUndoing] || [undoManager isRedoing])) {
    NSString *s;
    if (1 == [indexes count]) {
      s = NSLocalizedStringFromTable(@"Add PathAtom", @"UndoStrings", @"Action name for moving a point.");
    } else {
      s = NSLocalizedStringFromTable(@"Add PathAtoms", @"UndoStrings", @"Action name for moving points.");
    }
    [undoManager setActionName:s];
  }

  [_atoms insertObjects:atoms atIndexes:indexes];
  [self updateBounds];
}

- (void)replacePathAtomAtIndexes:(NSIndexSet *)indexes withPathAtom:(NSArray<SKTPathAtom *> *)objects {
  // Make it undoable.
  NSUndoManager *undoManager = [self undoManager];
  [[undoManager prepareWithInvocationTarget:self] replacePathAtomAtIndexes:indexes withPathAtom:[self pathAtomAtIndexes:indexes]];
  if ( ! ([undoManager isUndoing] || [undoManager isRedoing])) {
    NSString *s;
    if (1 == [indexes count]) {
      s = NSLocalizedStringFromTable(@"Move PathAtom", @"UndoStrings", @"Action name for moving a point.");
    } else {
      s = NSLocalizedStringFromTable(@"Move PathAtoms", @"UndoStrings", @"Action name for moving points.");
    }
    [undoManager setActionName:s];
  }

  for (NSUInteger k = [objects count] - 1, i = [indexes lastIndex]; NSNotFound != i; i = [indexes indexLessThanIndex:i], --k) {
    SKTPathAtom *a = objects[k];
    _atoms[i] = a;
  }
  [self updateBounds];
}

- (NSArray *)pathAtoms {
  return _atoms;
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


@end
