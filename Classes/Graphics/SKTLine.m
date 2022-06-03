/*
 File: SKTLine.m
 Abstract: A graphic object to represent a line.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTLine.h"


// String constants declared in the header. They may not be used by any other class in the project, but it's a good idea to provide and use them, if only to help prevent typos in source code.
NSString *SKTLineBeginPointKey = @"beginPoint";
NSString *SKTLineEndPointKey = @"endPoint";

// SKTGraphic's default selection handle machinery draws more handles than we need, so this class implements its own.
enum {
  SKTLineBeginHandle = 1,
  SKTLineEndHandle = 2
};

@interface SKTLine() {
  // YES if the line's ending is to the right or below, respectively, it's beginning, NO otherwise. Because we reuse SKTGraphic's "bounds" property, we have to keep track of the corners of the bounds at which the line begins and ends. A more natural thing to do would be to just record two points, but then we'd be wasting an NSRect's worth of ivar space per instance, and have to override more SKTGraphic methods to boot. This of course raises the question of why SKTGraphic has a bounds property when it's not readily applicable to every conceivable subclass. Perhaps in the future it won't, but right now in FloorSketch it's the handy thing to do for four out of five subclasses.
  BOOL _pointsRight;
  BOOL _pointsDown;
}

@end

@implementation SKTLine

- (id)copyWithZone:(NSZone *)zone {
  SKTLine *copy = [super copyWithZone:zone];
  copy->_pointsRight = _pointsRight;
  copy->_pointsDown = _pointsDown;
  return copy;
}

- (NSString *)asSVGString {
  return [self asSVGStringVerb:@"line"];
}

- (NSString *)svgAttributesString {
  return [NSString stringWithFormat:@"x1=\"%.5g\" y1=\"%.5g\" x2=\"%.5g\" y2=\"%.5g\" %@",
    self.beginPoint.x, self.beginPoint.y,
    self.endPoint.x, self.endPoint.y,
    [super svgAttributesString]];
}


#pragma mark - Private KVC and KVO-Compliance for Public Properties


// The only reason we have to have this many methods for simple KVC and KVO compliance for "beginPoint" and "endPoint" is because reusing SKTGraphic's "bounds" property is so complicated (see the instance variable comments in the header). If we just had _beginPoint and _endPoint we wouldn't need any of these methods because KVC's direct instance variable access and KVO's autonotification would just take care of everything for us (though maybe then we'd have to override -setBounds: and -bounds to fulfill the KVC and KVO compliance obligation for "bounds" that this class inherits from its superclass).


+ (NSSet *)keyPathsForValuesAffectingBeginPoint {
  return [NSSet setWithObject:SKTGraphicBoundsKey];
}
- (NSPoint)beginPoint {

  // Convert from our odd storage format to something natural.
  NSPoint beginPoint;
  NSRect bounds = [self bounds];
  beginPoint.x = _pointsRight ? NSMinX(bounds) : NSMaxX(bounds);
  beginPoint.y = _pointsDown ? NSMinY(bounds) : NSMaxY(bounds);
  return beginPoint;

}


+ (NSSet *)keyPathsForValuesAffectingEndPoint {
  return [NSSet setWithObject:SKTGraphicBoundsKey];
}
- (NSPoint)endPoint {

  // Convert from our odd storage format to something natural.
  NSPoint endPoint;
  NSRect bounds = [self bounds];
  endPoint.x = _pointsRight ? NSMaxX(bounds) : NSMinX(bounds);
  endPoint.y = _pointsDown ? NSMaxY(bounds) : NSMinY(bounds);
  return endPoint;

}


+ (NSRect)boundsWithBeginPoint:(NSPoint)beginPoint endPoint:(NSPoint)endPoint pointsRight:(BOOL *)outPointsRight down:(BOOL *)outPointsDown {

  // Convert the begin and end points of the line to its bounds and flags specifying the direction in which it points.
  BOOL pointsRight = beginPoint.x < endPoint.x;
  BOOL pointsDown = beginPoint.y < endPoint.y;
  CGFloat xPosition = pointsRight ? beginPoint.x : endPoint.x;
  CGFloat yPosition = pointsDown ? beginPoint.y : endPoint.y;
  CGFloat width = fabs(endPoint.x - beginPoint.x);
  CGFloat height = fabs(endPoint.y - beginPoint.y);
  if (outPointsRight) {
    *outPointsRight = pointsRight;
  }
  if (outPointsDown) {
    *outPointsDown = pointsDown;
  }
  return NSMakeRect(xPosition, yPosition, width, height);

}


- (void)setBeginPoint:(NSPoint)beginPoint {

  // It's easiest to compute the results of setting these points together.
  [self setBounds:[[self class] boundsWithBeginPoint:beginPoint endPoint:[self endPoint] pointsRight:&_pointsRight down:&_pointsDown]];

}


- (void)setEndPoint:(NSPoint)endPoint {

  // It's easiest to compute the results of setting these points together.
  [self setBounds:[[self class] boundsWithBeginPoint:[self beginPoint] endPoint:endPoint pointsRight:&_pointsRight down:&_pointsDown]];

}


#pragma mark - Overrides of SKTGraphic Methods


- (instancetype)initWithProperties:(NSDictionary *)properties {

  // Let SKTGraphic do its job and then handle the additional properties defined by this subclass.
  self = [super initWithProperties:properties];
  if (self) {

    // This object still doesn't have a bounds (because of what we do in our override of -properties), so set one and record the other information we need to place the begin and end points. The dictionary entries are all instances of the classes that can be written in property lists. Don't trust the type of something you get out of a property list unless you know your process created it or it was read from your application or framework's resources. We don't have to worry about KVO-compliance in initializers like this by the way; no one should be observing an unitialized object.
    Class stringClass = [NSString class];
    NSString *beginPointString = properties[SKTLineBeginPointKey];
    NSPoint beginPoint = [beginPointString isKindOfClass:stringClass] ? NSPointFromString(beginPointString) : NSZeroPoint;
    NSString *endPointString = properties[SKTLineEndPointKey];
    NSPoint endPoint = [endPointString isKindOfClass:stringClass] ? NSPointFromString(endPointString) : NSZeroPoint;
    [self setBounds:[[self class] boundsWithBeginPoint:beginPoint endPoint:endPoint pointsRight:&_pointsRight down:&_pointsDown]];

  }
  return self;

}


- (NSMutableDictionary *)properties {

  // Let SKTGraphic do its job but throw out the bounds entry in the dictionary it returned and add begin and end point entries insteads. We do this instead of simply recording the current value of _pointsRight and _pointsDown because bounds+pointsRight+pointsDown is just too unnatural to immortalize in a file format. The dictionary must contain nothing but values that can be written in old-style property lists.
  NSMutableDictionary *properties = [super properties];
  [properties removeObjectForKey:SKTGraphicBoundsKey];
  properties[SKTLineBeginPointKey] = NSStringFromPoint([self beginPoint]);
  properties[SKTLineEndPointKey] = NSStringFromPoint([self endPoint]);
  return properties;

}


// We don't bother overriding +[SKTGraphic keyPathsForValuesAffectingDrawingBounds] because we don't need to take advantage of the KVO dependency mechanism enabled by that method. We fulfill our KVO compliance obligations (inherited from SKTGraphic) for SKTGraphicDrawingBoundsKey by just always invoking -setBounds: in -setBeginPoint: and -setEndPoint:. "bounds" is always in the set returned by +[SKTGraphic keyPathsForValuesAffectingDrawingBounds]. Now, there's nothing in SKTGraphic.h that actually guarantees that, so we're taking advantage of "undefined" behavior. If we didn't have the source to SKTGraphic right next to the source for this class it would probably be prudent to override +keyPathsForValuesAffectingDrawingBounds, and make sure.

// We don't bother overriding +[SKTGraphic keyPathsForValuesAffectingDrawingContents] because this class doesn't define any properties that affect drawing without affecting the bounds.


- (BOOL)isDrawingFill {
  // You can't fill a line.
  return NO;
}


- (BOOL)isDrawingStroke {
  // You can't not stroke a line.
  return YES;
}


- (NSBezierPath *)bezierPathForDrawing {
  // Simple.
  NSBezierPath *path = [NSBezierPath bezierPath];
  [path moveToPoint:[self beginPoint]];
  [path lineToPoint:[self endPoint]];
  [path setLineWidth:[self strokeWidth]];
  return path;
}


- (void)drawHandlesInView:(NSView *)view {
  // A line only has two handles.
  [self drawHandleInView:view atPoint:[self beginPoint]];
  [self drawHandleInView:view atPoint:[self endPoint]];
}


+ (NSInteger)creationSizingHandle {
  // When the user creates a line and is dragging around a handle to size it they're dragging the end of the line.
  return SKTLineEndHandle;
}


- (BOOL)canSetDrawingFill {
  // Don't let the user think we can fill a line.
  return NO;
}


- (BOOL)canSetDrawingStroke {
  // Don't let the user think can ever not stroke a line.
  return NO;
}


- (BOOL)canMakeNaturalSize {
  // What would the "natural size" of a line be?
  return NO;
}


- (BOOL)isContentsUnderPoint:(NSPoint)point {
  // Do a gross check against the bounds.
  BOOL isContentsUnderPoint = NO;
  if (NSPointInRect(point, [self bounds])) {

    // Let the user click within the stroke width plus some slop.
    CGFloat acceptableDistance = ([self strokeWidth] / 2.0f) + 2.0f;

    // Before doing anything avoid a divide by zero error.
    NSPoint beginPoint = [self beginPoint];
    NSPoint endPoint = [self endPoint];
    CGFloat xDelta = endPoint.x - beginPoint.x;
    if (xDelta == 0.0f && fabs(point.x - beginPoint.x)<=acceptableDistance) {
      isContentsUnderPoint = YES;
    } else {

      // Do a weak approximation of distance to the line segment.
      CGFloat slope = (endPoint.y - beginPoint.y) / xDelta;
      if (fabs(((point.x - beginPoint.x) * slope) - (point.y - beginPoint.y))<=acceptableDistance) {
        isContentsUnderPoint = YES;
      }
    }
  }
  return isContentsUnderPoint;
}


- (NSInteger)handleUnderPoint:(NSPoint)point inView:(NSView<SKTHasHandles> *)view {
  // A line just has handles at its ends.
  NSInteger handle = SKTGraphicNoHandle;
  if ([self isHandleAtPoint:[self beginPoint] underPoint:point inView:view]) {
    handle = SKTLineBeginHandle;
  } else if ([self isHandleAtPoint:[self endPoint] underPoint:point inView:view]) {
    handle = SKTLineEndHandle;
  }
  return handle;
}


- (NSInteger)resizeByMovingHandle:(NSInteger)handle toPoint:(NSPoint)point {
  // A line just has handles at its ends.
  if (handle == SKTLineBeginHandle) {
    [self setBeginPoint:point];
  } else if (handle == SKTLineEndHandle) {
    [self setEndPoint:point];
  } // else a cataclysm occurred.

  // We don't have to do the kind of handle flipping that SKTGraphic does.
  return handle;
}


- (void)setColor:(NSColor *)color {
  // Because lines aren't filled we'll consider the stroke's color to be the one.
  [self setValue:color forKey:SKTGraphicStrokeColorKey];
}


- (NSSet *)keysForValuesToObserveForUndo {
  // When the user drags one of the handles of a line we don't want to just have changes to "bounds" registered in the undo group. That would be:
  // 1) Insufficient. We would also have to register changes of "pointsRight" and "pointsDown," but we already decided to keep those properties private (see the comments in the header).
  // 2) Not very user-friendly. We don't want the user to see an "Undo Change of Bounds" item in the Edit menu. We want them to see "Undo Change of Endpoint."
  // So, tell the observer of undoable properties (SKTDocument, in FloorSketch) to observe "beginPoint" and "endPoint" instead of "bounds."
  NSMutableSet *keys = [[super keysForValuesToObserveForUndo] mutableCopy];
  [keys removeObject:SKTGraphicBoundsKey];
  [keys addObject:SKTLineBeginPointKey];
  [keys addObject:SKTLineEndPointKey];
  return keys;
}


+ (NSString *)presentablePropertyNameForKey:(NSString *)key {
  // Pretty simple. As is usually the case when a key is passed into a method like this, we have to invoke super if we don't recognize the key. As far as the user is concerned both points that define a line are "endpoints."
  static NSDictionary *presentablePropertyNamesByKey = nil;
  if (!presentablePropertyNamesByKey) {
    presentablePropertyNamesByKey = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                     NSLocalizedStringFromTable(@"Beginpoint", @"UndoStrings", @"Action name part for SKTLineBeginPointKey."), SKTLineBeginPointKey,
                                     NSLocalizedStringFromTable(@"Endpoint", @"UndoStrings",@"Action name part for SKTLineEndPointKey."), SKTLineEndPointKey,
                                     nil];
  }
  NSString *presentablePropertyName = presentablePropertyNamesByKey[key];
  if (!presentablePropertyName) {
    presentablePropertyName = [super presentablePropertyNameForKey:key];
  }
  return presentablePropertyName;
}


@end
