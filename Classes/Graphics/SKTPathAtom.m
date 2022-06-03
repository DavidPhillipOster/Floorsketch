/*  SKTPathAtom.m
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTPathAtom.h"

#import "SKTGraphic.h"

static NSString *const SKTPathAtomPtKey = @"p";
static NSString *const SKTPathAtomPtToKey = @"pTo";
static NSString *const SKTPathAtomPtFromKey = @"pFrom";
static NSString *const SKTPathAtomPtControl1Key = @"pControl1";
static NSString *const SKTPathAtomPtControl2Key = @"pControl2";
static NSString *const SKTPathAtomRadiusKey = @"radius";

@implementation SKTPathAtom

- (BOOL)hasPointValue {
  return YES;
}

- (CGPoint)pointValue {
  return _p;
}

- (MinMaxPt)minMax {
  MinMaxPt result;
  result.min = _p;
  result.max = _p;
  return result;
}

- (void)appendToPath:(NSBezierPath *)path nowAt:(CGPoint *)atp {
  [path moveToPoint:self.p];
  *atp = self.p;
}

- (void)translateBy:(CGPoint)p {
  _p.x += p.x;
  _p.y += p.y;
}

- (void)scale:(CGSize)scale relativeToOrigin:(CGPoint)origin {
  _p.x = ((_p.x - origin.x) * scale.width) + origin.x;
  _p.y = ((_p.y - origin.y) * scale.height) + origin.y;
}

- (void)flipHorizontallyRelatveToBounds:(CGRect)bounds {
   _p.x = (bounds.origin.x + bounds.size.width) - (_p.x - bounds.origin.x);
}

- (void)flipVerticallyRelatveToBounds:(CGRect)bounds {
   _p.y = (bounds.origin.y + bounds.size.height) - (_p.y - bounds.origin.y);
}


+ (instancetype)pathAtomWithPt:(CGPoint)p {
  SKTPathAtom *result = [[self alloc] init];
  result.p = p;
  return result;
}

- (NSMutableDictionary *)properties {
  NSMutableDictionary *properties = [NSMutableDictionary dictionary];
  properties[SKTPathAtomPtKey] = NSStringFromPoint(_p);
  properties[SKTGraphicClassNameKey] = NSStringFromClass([self class]);
  return properties;
}

- (NSString *)svgString {
  // Subcalsses must override.
  [NSException raise:NSInternalInconsistencyException format:@"TODO: svgString"];
  return @"";
}

@end

@implementation SKTPathClosed

- (BOOL)hasPointValue {
  return NO;
}

- (void)appendToPath:(NSBezierPath *)path nowAt:(CGPoint *)atp {
  [path closePath];
}

- (NSString *)svgString {
  return @"Z";
}
@end

@implementation SKTPathPoint
- (void)appendToPath:(NSBezierPath *)path nowAt:(CGPoint *)atp {
  [path moveToPoint:self.p];
	*atp = self.p;
}

- (NSString *)svgString {
  return [NSString stringWithFormat:@"M%.5g,%.5g", self.p.x, self.p.y];
}
@end

@implementation SKTPathLine
- (void)appendToPath:(NSBezierPath *)path nowAt:(CGPoint *)atp {
  [path lineToPoint:self.p];
	*atp = self.p;
}
- (NSString *)svgString {
  return [NSString stringWithFormat:@"L%.5g,%.5g", self.p.x, self.p.y];
}

@end

// Given two points on a circle, and a radius, solve for the center point.


// Given a center, and a point, solve for the angle.
//static CGFloat AngleFromCenterPoint(CGPoint center, CGPoint p) {
//  return atan2(p.x - center.x, p.y - center.y);
//}

static CGPoint PointOfCenterRadiusAngle(CGPoint center, CGFloat radius, CGFloat angle) {
  return CGPointMake(center.x + radius*sin(angle), center.y + radius*cos(angle));
}

/*
A rx ry x-axis-rotation large-arc-flag sweepflag x, y
Draws arc to the point (x,y)
The values rx and ry are the radiuses of the ellipse.
The x-axis-rotation rotates the ellipse the arc is created from (without changing start/end point).
The large-arc-flag (0 or 1) determines how wide the arc is.
The sweepflag (0 or 1) determines which way the arc goes (underneath or above).
 */
@implementation SKTPathArc

- (CGPoint)endPoint {
  return PointOfCenterRadiusAngle(_pCenter, _radius, _endAngle);
}

- (NSString *)svgString {
  CGPoint endPoint = [self endPoint];
  return [NSString stringWithFormat:@"A%.5g %.5g 0 %@ %@ %.5g %.5g", _radius, _radius, _largeArc ? @"1":@"0", _clockwise  ? @"1":@"0", endPoint.x, endPoint.y ];
}

- (void)appendToPath:(NSBezierPath *)path nowAt:(CGPoint *)atp {
//  [path appendBezierPathWithArcFromPoint:_pFrom toPoint:_pTo radius:_radius];
  [path appendBezierPathWithArcWithCenter:_pCenter
                                   radius:_radius
                               startAngle:_startAngle
                                 endAngle:_endAngle
                                clockwise:_clockwise];
	*atp = PointOfCenterRadiusAngle(_pCenter, _radius, _endAngle);
}

- (void)translateBy:(CGPoint)p {
  [super translateBy:p];
  _pCenter.x += p.x;
  _pCenter.y += p.y;
}

- (void)scale:(CGSize)scale relativeToOrigin:(CGPoint)origin {
  [super scale:scale relativeToOrigin:origin];
  _radius = (scale.width + scale.height) / 2; // is this right?
}

- (void)flipHorizontallyRelatveToBounds:(CGRect)bounds {
  [super flipHorizontallyRelatveToBounds:bounds];
}

- (void)flipVerticallyRelatveToBounds:(CGRect)bounds {
  [super flipVerticallyRelatveToBounds:bounds];
}

- (NSMutableDictionary *)properties {
  NSMutableDictionary *properties = [super properties];
  properties[SKTPathAtomRadiusKey] = [NSNumber numberWithFloat:_radius];
  return properties;
}

@end

static CGPoint PointAdd(CGPoint p1, CGPoint p2) {
	return CGPointMake(p1.x + p2.x, p1.y + p2.y);
}

static CGPoint PointDiff(CGPoint p1, CGPoint p2) {
	return CGPointMake(p1.x - p2.x, p1.y - p2.y);
}

static CGPoint PointMult(CGPoint p, CGFloat c){
	return CGPointMake(p.x*c, p.y*c);
}



@implementation SKTPathQuadratic

- (void)appendToPath:(NSBezierPath *)path nowAt:(CGPoint *)atp {
	//	https://www.iro.umontreal.ca/~boyer/typophile/doc/bezier.html says:
	// CP1 = QP0 + 2/3 *(QP1-QP0)
	// CP2 = CP1 + 1/3 *(QP2-QP0)
	CGPoint cp1 = PointAdd(*atp, PointMult(PointDiff(_pControl1, *atp), 2.0/3.0));
	CGPoint cp2 = PointAdd(cp1, PointMult(PointDiff(self.p, *atp), 1.0/3.0));
  [path curveToPoint:self.p
        controlPoint1:cp1
        controlPoint2:cp2];
	*atp = self.p;
}

- (NSString *)svgString {
  return [NSString stringWithFormat:@"Q%.5g,%.5g %.5g,%.5g", _pControl1.x, _pControl1.y, self.p.x, self.p.y];
}


- (MinMaxPt)minMax {
  MinMaxPt result;
  result.min.x = MIN(self.p.x, _pControl1.x);
  result.min.y = MIN(self.p.y, _pControl1.y);
  result.max.x = MAX(self.p.x, _pControl1.x);
  result.max.y = MAX(self.p.y, _pControl1.y);
  return result;
}


- (NSMutableDictionary *)properties {
  NSMutableDictionary *properties = [super properties];
  properties[SKTPathAtomPtControl1Key] = NSStringFromPoint(_pControl1);
  return properties;
}


- (void)translateBy:(CGPoint)p {
  [super translateBy:p];
  _pControl1.x += p.x;
  _pControl1.y += p.y;
}

- (void)scale:(CGSize)scale relativeToOrigin:(CGPoint)origin {
  [super scale:scale relativeToOrigin:origin];
  _pControl1.x = ((_pControl1.x - origin.x) * scale.width) + origin.x;
  _pControl1.y = ((_pControl1.y - origin.y) * scale.height) + origin.y;
}

- (void)flipHorizontallyRelatveToBounds:(CGRect)bounds {
  [super flipHorizontallyRelatveToBounds:bounds];
   _pControl1.x = (bounds.origin.x + bounds.size.width) - (_pControl1.x - bounds.origin.x);
}

- (void)flipVerticallyRelatveToBounds:(CGRect)bounds {
  [super flipVerticallyRelatveToBounds:bounds];
   _pControl1.y = (bounds.origin.y + bounds.size.height) - (_pControl1.y - bounds.origin.y);
}


@end

@implementation SKTPathCubic

- (void)appendToPath:(NSBezierPath *)path nowAt:(CGPoint *)atp {
  [path curveToPoint:self.p
        controlPoint1:_pControl1
        controlPoint2:_pControl2];
	*atp = self.p;
}

- (NSString *)svgString {
  return [NSString stringWithFormat:@"C%.5g,%.5g %.5g,%.5g %.5g,%.5g", _pControl1.x, _pControl1.y, _pControl2.x, _pControl2.y, self.p.x, self.p.y];
}


- (MinMaxPt)minMax {
  MinMaxPt result;
  result.min.x = MIN(MIN(self.p.x, _pControl1.x), _pControl2.x);
  result.min.y = MIN(MIN(self.p.y, _pControl1.y), _pControl2.y);
  result.max.x = MAX(MAX(self.p.x, _pControl1.x), _pControl2.x);
  result.max.y = MAX(MAX(self.p.y, _pControl1.y), _pControl2.y);
  return result;
}


- (NSMutableDictionary *)properties {
  NSMutableDictionary *properties = [super properties];
  properties[SKTPathAtomPtControl1Key] = NSStringFromPoint(_pControl1);
  properties[SKTPathAtomPtControl2Key] = NSStringFromPoint(_pControl1);
  return properties;
}

- (void)translateBy:(CGPoint)p {
  [super translateBy:p];
  _pControl1.x += p.x;
  _pControl1.y += p.y;
  _pControl2.x += p.x;
  _pControl2.y += p.y;
}

- (void)scale:(CGSize)scale relativeToOrigin:(CGPoint)origin {
  [super scale:scale relativeToOrigin:origin];
  _pControl1.x = ((_pControl1.x - origin.x) * scale.width) + origin.x;
  _pControl1.y = ((_pControl1.y - origin.y) * scale.height) + origin.y;
  _pControl2.x = ((_pControl2.x - origin.x) * scale.width) + origin.x;
  _pControl2.y = ((_pControl2.y - origin.y) * scale.height) + origin.y;
}

- (void)flipHorizontallyRelatveToBounds:(CGRect)bounds {
  [super flipHorizontallyRelatveToBounds:bounds];
   _pControl1.x = (bounds.origin.x + bounds.size.width) - (_pControl1.x - bounds.origin.x);
   _pControl2.x = (bounds.origin.x + bounds.size.width) - (_pControl2.x - bounds.origin.x);
}

- (void)flipVerticallyRelatveToBounds:(CGRect)bounds {
  [super flipVerticallyRelatveToBounds:bounds];
   _pControl1.y = (bounds.origin.y + bounds.size.height) - (_pControl1.y - bounds.origin.y);
   _pControl2.y = (bounds.origin.y + bounds.size.height) - (_pControl2.y - bounds.origin.y);
}


@end
