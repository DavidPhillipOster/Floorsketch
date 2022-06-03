/*  SKTPathAtom.h
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import <Foundation/Foundation.h>

typedef struct MinMaxPt {
  CGPoint min;
  CGPoint max;
} MinMaxPt;

// spelled with a lower case 'A' to make key value coding work.
@interface SKTPathAtom : NSObject
@property(nonatomic) CGPoint p;
@property(readonly) BOOL hasPointValue;
@property(nonatomic) NSUInteger index;  // for scripting
  // The object that contains the atom (unretained), from the point of view of scriptability. This is here only for use by this class' override of scripting's -objectSpecifier method. In FloorSketch this is an SKTPoly or SKTPath.
@property(nonatomic, weak) NSObject *scriptingContainer;

@property(nonatomic, readonly) NSString *svgString;

- (MinMaxPt)minMax;

// 'at' is in-out, at the current "cursor" position. Quadratic splines need it.
- (void)appendToPath:(NSBezierPath *)path nowAt:(CGPoint *)atp;

- (void)translateBy:(CGPoint)p;
- (void)scale:(CGSize)scale relativeToOrigin:(CGPoint)origin;
- (void)flipHorizontallyRelatveToBounds:(CGRect)bounds;
- (void)flipVerticallyRelatveToBounds:(CGRect)bounds;
- (CGPoint)pointValue;

+ (instancetype)pathAtomWithPt:(CGPoint)p;

@end

// The initial point.
@interface SKTPathPoint : SKTPathAtom
@end

// Line segment from the previous point.
@interface SKTPathLine : SKTPathAtom
@end

// used during parsing to denote a closed path. Removed by the time parsing is done.
@interface SKTPathClosed : SKTPathAtom
@end

// Arc from the previous point.
@interface SKTPathArc : SKTPathAtom
@property(nonatomic) CGPoint pCenter;
@property(nonatomic) CGFloat startAngle;
@property(nonatomic) CGFloat endAngle;
@property(nonatomic) CGFloat radius;
@property(nonatomic) BOOL clockwise;
@property(nonatomic) BOOL largeArc;
@end

// Quadratic spline from the previous point.
@interface SKTPathQuadratic : SKTPathAtom
@property(nonatomic) CGPoint pControl1;
@end

@interface SKTPathCubic : SKTPathAtom
@property(nonatomic) CGPoint pControl1;
@property(nonatomic) CGPoint pControl2;
@end
