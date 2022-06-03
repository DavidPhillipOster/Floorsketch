/*
 File: SKTGraphic.m
 Abstract: The base class for FloorSketch graphics objects.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTGraphic.h"

#import "NSColor_SKT.h"
#import "SKTError.h"

@interface NSColor(SKTGraphic)
- (NSString *)svgSpecifier:(CGFloat *)outAlpha;
@end

@implementation NSColor(SKTGraphic)
- (NSString *)svgSpecifier:(CGFloat *)outAlpha {
  NSColor *c = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  CGFloat red;
  CGFloat blue;
  CGFloat green;
  CGFloat alpha;
  [c getRed:&red green:&green blue:&blue alpha:&alpha];
  *outAlpha = alpha;
  return [NSString stringWithFormat:@"#%02x%02x%02x", (int)(255*red), (int)(255*green), (int)(255*blue)];
}
@end

static NSUInteger sUpdateCount;

// String constants declared in the header. A lot of them aren't used by any other class in the project, but it's a good idea to provide and use them, if only to help prevent typos in source code.
// Why are there @"drawingFill" and @"drawingStroke" keys here when @"isDrawingFill" and @"isDrawingStroke" would be a little more consistent with Cocoa convention for boolean values? Because we might want to add setter methods for these properties some day, and key-value coding isn't smart enough to ignore "is" when looking for setter methods, and having to give methods ugly names -setIsDrawingFill: and -setIsDrawingStroke: would be irritating. In general it's best to leave the "is" off the front of keys that identify boolean values.
NSString *const SKTGraphicCanSetDrawingFillKey = @"canSetDrawingFill";
NSString *const SKTGraphicCanSetDrawingStrokeKey = @"canSetDrawingStroke";
NSString *const SKTGraphicIsDrawingFillKey = @"drawingFill";
NSString *const SKTGraphicFillColorKey = @"fillColor";
NSString *const SKTGraphicIsDrawingStrokeKey = @"drawingStroke";
NSString *const SKTGraphicLockedKey = @"locked";
NSString *const SKTGraphicStrokeColorKey = @"strokeColor";
NSString *const SKTGraphicStrokeWidthKey = @"strokeWidth";
NSString *const SKTGraphicTransformKey = @"transform";
NSString *const SKTGraphicXPositionKey = @"xPosition";
NSString *const SKTGraphicYPositionKey = @"yPosition";
NSString *const SKTGraphicUpateCountKey = @"updateCount";
NSString *const SKTGraphicWidthKey = @"width";
NSString *const SKTGraphicHeightKey = @"height";
NSString *const SKTGraphicBoundsKey = @"bounds";
NSString *const SKTGraphicDrawingBoundsKey = @"drawingBounds";
NSString *const SKTGraphicDrawingContentsKey = @"drawingContents";
NSString *const SKTGraphicKeysForValuesToObserveForUndoKey = @"keysForValuesToObserveForUndo";
NSString *const SKTGraphicClosed = @"closed";

// Another constant that's declared in the header.
const NSInteger SKTGraphicNoHandle = 0;

// A key that's used in Sketch's property-list-based file and pasteboard formats.
NSString *const SKTGraphicClassNameKey = @"className";

// The values that might be returned by -[SKTGraphic creationSizingHandle] and -[SKTGraphic handleUnderPoint:], and that are understood by -[SKTGraphic resizeByMovingHandle:toPoint:]. We provide specific indexes in this enumeration so make sure none of them are zero (that's SKTGraphicNoHandle) and to make sure the flipping arrays in -[SKTGraphic resizeByMovingHandle:toPoint:] work.
enum {
  SKTGraphicUpperLeftHandle = 1,
  SKTGraphicUpperMiddleHandle = 2,
  SKTGraphicUpperRightHandle = 3,
  SKTGraphicMiddleLeftHandle = 4,
  SKTGraphicMiddleRightHandle = 5,
  SKTGraphicLowerLeftHandle = 6,
  SKTGraphicLowerMiddleHandle = 7,
  SKTGraphicLowerRightHandle = 8,
};

@interface SKTGraphic(){
  // The values underlying some of the key-value coding (KVC) and observing (KVO) compliance described below. Any corresponding getter or setter methods are there for invocation by code in subclasses, not for KVC or KVO compliance. KVC's direct instance variable access, KVO's autonotifying, and KVO's property dependency mechanism makes them unnecessary for the latter purpose.
  // If you look closely, you'll notice that SKTGraphic itself never touches these instance variables directly except in initializers, -copyWithZone:, and public accessors. SKTGraphic is following a good rule: if a class publishes getters and setters it should itself invoke them, because people who override methods to customize behavior are right to expect their overrides to actually be invoked.
  NSRect _bounds;
  BOOL _isDrawingFill;
  NSColor *_fillColor;
  BOOL _isDrawingStroke;
  NSColor *_strokeColor;
  CGFloat _strokeWidth;
}

@end

@implementation SKTGraphic


// An override of the superclass' designated initializer.
- (instancetype)init {
  self = [super init];
  if (self) {
    // Set up decent defaults for a new graphic.
    _bounds = NSZeroRect;
    _isDrawingFill = NO;
    _fillColor = [NSColor whiteColor];
    _isDrawingStroke = YES;
    _strokeColor = [NSColor blackColor];
    _strokeWidth = 1.0f;
  }
  return self;
}


// Conformance to the NSCopying protocol. SKTGraphics are copyable for the sake of scriptability.
- (id)copyWithZone:(NSZone *)zone {
  // Pretty simple, but there's plenty of opportunity for mistakes. We use [self class] instead of SKTGraphic so that overrides of this method can invoke super. We copy instead of retaining the fill and stroke color even though it probably doesn't make a difference because that's the correct thing to do for attributes (to-one relationships, that's another story). We don't copy _scriptingContainer because the copy doesn't have any scripting container until it's added to one.
  SKTGraphic *copy = [[[self class] alloc] init];
  copy->_bounds = _bounds;
  copy->_isDrawingFill = _isDrawingFill;
  copy->_fillColor = [_fillColor copy];
  copy->_isDrawingStroke = _isDrawingStroke;
  copy->_strokeColor = [_strokeColor copy];
  copy->_strokeWidth = _strokeWidth;
  return copy;
}


#pragma mark - Private KVC-Compliance for Public Properties


// An override of the NSObject(NSKeyValueObservingCustomization) method.
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {

  // We don't want KVO autonotification for these properties. Because the setters for all of them invoke -setBounds:, and this class is KVO-compliant for "bounds," and we declared that the values of these properties depend on "bounds," we would up end up with double notifications for them. That would probably be unnoticable, but it's a little wasteful. Something you have to think about with codependent mutable properties like these (regardless of what notification mechanism you're using).
  BOOL automaticallyNotifies;
  if ([[NSSet setWithObjects:SKTGraphicXPositionKey, SKTGraphicYPositionKey, SKTGraphicWidthKey, SKTGraphicHeightKey, nil] containsObject:key]) {
    automaticallyNotifies = NO;
  } else {
    automaticallyNotifies = [super automaticallyNotifiesObserversForKey:key];
  }
  return automaticallyNotifies;

}


// In Mac OS 10.5 and newer KVO's dependency mechanism invokes class methods to find out what properties affect properties being observed, like these.
+ (NSSet *)keyPathsForValuesAffectingXPosition {
  return [NSSet setWithObject:SKTGraphicBoundsKey];
}
+ (NSSet *)keyPathsForValuesAffectingYPosition {
  return [NSSet setWithObject:SKTGraphicBoundsKey];
}
+ (NSSet *)keyPathsForValuesAffectingWidth {
  return [NSSet setWithObject:SKTGraphicBoundsKey];
}
+ (NSSet *)keyPathsForValuesAffectingHeight {
  return [NSSet setWithObject:SKTGraphicBoundsKey];
}
- (CGFloat)xPosition {
  return [self bounds].origin.x;
}
- (CGFloat)yPosition {
  return [self bounds].origin.y;
}
- (CGFloat)width {
  return [self bounds].size.width;
}
- (CGFloat)height {
  return [self bounds].size.height;
}
- (void)setXPosition:(CGFloat)xPosition {
  NSRect bounds = [self bounds];
  bounds.origin.x = xPosition;
  [self setBounds:bounds];
}
- (void)setYPosition:(CGFloat)yPosition {
  NSRect bounds = [self bounds];
  bounds.origin.y = yPosition;
  [self setBounds:bounds];
}
- (void)setWidth:(CGFloat)width {
  NSRect bounds = [self bounds];
  bounds.size.width = width;
  [self setBounds:bounds];
}
- (void)setHeight:(CGFloat)height {
  NSRect bounds = [self bounds];
  bounds.size.height = height;
  [self setBounds:bounds];
}

- (void)setLockedValue:(NSNumber *)boolN {
  [self setLocked:[boolN boolValue]];
}

- (BOOL)canOpenPolygon {
  return NO; // subclasses may override
}

- (BOOL)canClosePolygon {
  return NO; // subclasses may override
}

- (SKTGraphic *)graphicByOpening {
  return self;
}

- (SKTGraphic *)graphicByClosing {
  return self;
}


- (NSString *)asSVGString {
  return @""; // subclasses should override!
}

- (NSString *)asSVGStringVerb:(NSString *)verb {
  return [NSString stringWithFormat:@"<%@ %@/>", verb, [self svgAttributesString]];
}

- (NSString *)svgFillSpecifier {
  if ([self isDrawingFill]) {
    if (nil == self.fillColor) {
      return nil;
    }
    CGFloat alpha;
    NSString *s = [self.fillColor svgSpecifier:&alpha];
    if (1.0 != alpha) {
      s = [NSString stringWithFormat:@"%@;fill-opacity: %.5g", s, alpha];
    }
    return s;
  } else {
    return @"none";
  }
}

- (NSString *)svgStrokeSpecifier {
  if ([self isDrawingStroke]) {
    if (nil == self.strokeColor) {
      return nil;
    }
    CGFloat alpha;
    NSString *s = [NSString stringWithFormat:@"%@; stroke-width:%.5g ",
        [self.strokeColor svgSpecifier:&alpha], self.strokeWidth];
    if (1.0 != alpha) {
      s = [NSString stringWithFormat:@"%@;stroke-opacity: %.5g", s, alpha];
    }
    return s;
  } else {
    return @"none";
  }
}

- (NSString *)svgAttributesString {
  NSString *fillSpec = [self svgFillSpecifier];
  NSString *strokeSpec = [self svgStrokeSpecifier];
  NSString *s = @"";
  if (nil != fillSpec && nil != strokeSpec) {
    s = [NSString stringWithFormat:@"style=\"fill: %@; stroke: %@\"", fillSpec, strokeSpec];
  } else if (nil != fillSpec) {
    s = [NSString stringWithFormat:@"style=\"fill: %@\"", fillSpec];
  } else if (nil != strokeSpec) {
    s = [NSString stringWithFormat:@"style=\"stroke: %@\"", strokeSpec];
  }
  return s;
}

#pragma mark - Convenience


+ (NSRect)boundsOfGraphics:(NSArray *)graphics {
  // The bounds of an array of graphics is the union of all of their bounds.
  NSRect bounds = NSZeroRect;
  NSUInteger graphicCount = [graphics count];
  if (graphicCount > 0) {
    bounds = [graphics[0] bounds];
    for (NSUInteger index = 1; index < graphicCount; index++) {
      bounds = NSUnionRect(bounds, [graphics[index] bounds]);
    }
  }
  return bounds;

}

+ (void)translateGraphics:(NSArray *)graphics byX:(CGFloat)deltaX y:(CGFloat)deltaY {
  // Pretty simple.
  NSUInteger graphicCount = [graphics count];
  for (NSUInteger index = 0; index < graphicCount; index++) {
    SKTGraphic *graphic = graphics[index];
    [graphic setBounds:NSOffsetRect([graphic bounds], deltaX, deltaY)];
  }

}


#pragma mark - Persistence


+ (NSArray *)graphicsWithPasteboardData:(NSData *)data error:(NSError **)outError {

  // Because this data may have come from outside this process, don't assume that any property list object we get back is the right type.
  NSArray *graphics = nil;
  NSArray *propertiesArray = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
  if (![propertiesArray isKindOfClass:[NSArray class]]) {
    propertiesArray = nil;
  }
  if (propertiesArray) {

    // Convert the array of graphic property dictionaries into an array of graphics.
    graphics = [self graphicsWithProperties:propertiesArray];

  } else if (outError) {

    // If property list parsing fails we have no choice but to admit that we don't know what went wrong. The error description returned by +[NSPropertyListSerialization propertyListFromData:mutabilityOption:format:errorDescription:] would be pretty technical, and not the sort of thing that we should show to a user.
    *outError = SKTErrorWithCode(SKTUnknownPasteboardReadError);

  }
  return graphics;

}


+ (NSArray *)graphicsWithProperties:(NSArray *)propertiesArray {

  // Convert the array of graphic property dictionaries into an array of graphics. Again, don't assume that property list objects are the right type.
  NSUInteger graphicCount = [propertiesArray count];
  NSMutableArray *graphics = [[NSMutableArray alloc] initWithCapacity:graphicCount];
  for (NSUInteger index = 0; index < graphicCount; index++) {
    NSDictionary *properties = propertiesArray[index];
    if ([properties isKindOfClass:[NSDictionary class]]) {

      // Figure out the class of graphic to instantiate. The value of the SKTGraphicClassNameKey entry must be an Objective-C class name. Don't trust the type of something you get out of a property list unless you know your process created it or it was read from your application or framework's resources.
      NSString *className = properties[SKTGraphicClassNameKey];
      if ([className isKindOfClass:[NSString class]]) {
        Class class = NSClassFromString(className);
        if (class) {

          // Create a new graphic. If it doesn't work then just do nothing. We could return an NSError, but doing things this way 1) means that a user might be able to rescue graphics from a partially corrupted document, and 2) is easier.
          SKTGraphic *graphic = [[class alloc] initWithProperties:properties];
          if (graphic) {
            [graphics addObject:graphic];
          }

        }

      }

    }
  }
  return graphics;
}


+ (NSData *)pasteboardDataWithGraphics:(NSArray *)graphics {

  // Convert the contents of the document to a property list and then flatten the property list.
  return [NSPropertyListSerialization dataFromPropertyList:[self propertiesWithGraphics:graphics] format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];

}


+ (NSArray *)propertiesWithGraphics:(NSArray *)graphics {

  // Convert the array of graphics dictionaries into an array of graphic property dictionaries.
  NSUInteger graphicCount = [graphics count];
  NSMutableArray *propertiesArray = [[NSMutableArray alloc] initWithCapacity:graphicCount];
  for (NSUInteger index = 0; index < graphicCount; index++) {
    SKTGraphic *graphic = graphics[index];

    // Get the properties of the graphic, add the class name that can be used by +graphicsWithProperties: to it, and add the properties to the array we're building.
    NSMutableDictionary *properties = [graphic properties];
    properties[SKTGraphicClassNameKey] = NSStringFromClass([graphic class]);
    [propertiesArray addObject:properties];

  }
  return propertiesArray;

}


- (instancetype)initWithProperties:(NSDictionary *)properties {
  self = [self init];
  if (self) {
    // The dictionary entries are all instances of the classes that can be written in property lists. Don't trust the type of something you get out of a property list unless you know your process created it or it was read from your application or framework's resources. We don't have to worry about KVO-compliance in initializers like this by the way; no one should be observing an unitialized object.
    Class numberClass = [NSNumber class];
    Class stringClass = [NSString class];
    NSString *boundsString = properties[SKTGraphicBoundsKey];
    if ([boundsString isKindOfClass:stringClass]) {
      _bounds = NSRectFromString(boundsString);
    }
    NSNumber *isDrawingFillNumber = properties[SKTGraphicIsDrawingFillKey];
    if ([isDrawingFillNumber isKindOfClass:numberClass]) {
      _isDrawingFill = [isDrawingFillNumber boolValue];
    }
    _fillColor = [NSColor colorWithArchiveData:properties[SKTGraphicFillColorKey]];
    NSNumber *isDrawingStrokeNumber = properties[SKTGraphicIsDrawingStrokeKey];
    if ([isDrawingStrokeNumber isKindOfClass:numberClass]) {
      _isDrawingStroke = [isDrawingStrokeNumber boolValue];
    }
    _strokeColor = [NSColor colorWithArchiveData:properties[SKTGraphicStrokeColorKey]];
    NSNumber *strokeWidthNumber = properties[SKTGraphicStrokeWidthKey];
    if ([strokeWidthNumber isKindOfClass:numberClass]) {
      _strokeWidth = [strokeWidthNumber doubleValue];
    }
  }
  return self;
}


// Return a dictionary that contains nothing but values that can be written in property lists.
- (NSMutableDictionary *)properties {
  NSMutableDictionary *properties = [NSMutableDictionary dictionary];
  properties[SKTGraphicBoundsKey] = NSStringFromRect([self bounds]);
  properties[SKTGraphicIsDrawingFillKey] = @([self isDrawingFill]);
  properties[SKTGraphicFillColorKey] = [[self fillColor] asArchiveData];
  properties[SKTGraphicIsDrawingStrokeKey] = @([self isDrawingStroke]);
  properties[SKTGraphicStrokeColorKey] = [[self strokeColor] asArchiveData];
  properties[SKTGraphicStrokeWidthKey] = @([self strokeWidth]);
  return properties;

}

- (NSMutableDictionary *)debugProperties {
  NSMutableDictionary *result = [self properties];
  NSColor *fillColor = [self fillColor];
  if (fillColor) {
    result[SKTGraphicFillColorKey] = fillColor;
  }
  NSColor *strokeColor = [self strokeColor];
  if (strokeColor) {
    result[SKTGraphicStrokeColorKey] = strokeColor;
  }
  return result;
}

#pragma mark - Simple Property Getting


- (BOOL)isDrawingFill {
  return _isDrawingFill;
}

- (void)setDrawingFill:(BOOL)drawingFill {
  if ( ! _locked) {
    _isDrawingFill = drawingFill;
  }
}

- (NSColor *)fillColor {
  return _fillColor;
}

- (void)setFillColor:(NSColor *)fillColor {
  if ( ! _locked) {
    _fillColor = fillColor;
  }
}

- (BOOL)isDrawingStroke {
  return _isDrawingStroke;
}

- (void)setDrawingStroke:(BOOL)drawingStroke {
  if ( ! _locked) {
    _isDrawingStroke = drawingStroke;
  }
}

- (NSColor *)strokeColor {
  return _strokeColor;
}

- (void)setStrokeColor:(NSColor *)strokeColor {
  if ( ! _locked) {
    _strokeColor = strokeColor;
  }
}


- (CGFloat)strokeWidth {
  return _strokeWidth;
}

- (void)setStrokeWidth:(CGFloat)strokeWidth {
  if ( ! _locked) {
    _strokeWidth = strokeWidth;
  }
}



#pragma mark - Drawing

// The only properties managed by SKTGraphic that affect the drawing bounds are the bounds and the the stroke width.
+ (NSSet *)keyPathsForValuesAffectingDrawingBounds {
  return [NSSet setWithObjects:SKTGraphicBoundsKey, SKTGraphicStrokeWidthKey, SKTGraphicLockedKey, SKTGraphicUpateCountKey, nil];
}


+ (NSSet *)keyPathsForValuesAffectingDrawingContents {
  // The only properties managed by SKTGraphic that affect drawing but not the drawing bounds are the fill and stroke parameters.
  return [NSSet setWithObjects:SKTGraphicIsDrawingFillKey, SKTGraphicFillColorKey, SKTGraphicIsDrawingStrokeKey, SKTGraphicStrokeColorKey, nil];
}


- (NSRect)drawingBounds {
  // Assume that -[SKTGraphic drawContentsInView:] and -[SKTGraphic drawHandlesInView:] will be doing the drawing. Start with the plain bounds of the graphic, then take drawing of handles at the corners of the bounds into account, then optional stroke drawing.
  CGFloat outset = 0;
  if ([self isDrawingStroke]) {
    outset = [self strokeWidth] / 2.0f;
  }
  CGFloat inset = 0.0f - outset;
  NSRect drawingBounds = NSInsetRect([self bounds], inset, inset);

  // -drawHandleInView:atPoint: draws a one-unit drop shadow too.
  drawingBounds.size.width += 1.0f;
  drawingBounds.size.height += 1.0f;
  return drawingBounds;

}

- (NSUInteger)updateCount {
  return sUpdateCount;
}

- (void)setUpdateCount:(NSUInteger)updateCount {
  sUpdateCount = updateCount;
}


- (void)drawContentsInView:(NSView *)view rect:(NSRect)rect isBeingCreateOrEdited:(BOOL)isBeingCreatedOrEditing {

  // If the graphic is so so simple that it can be boiled down to a bezier path then just draw a bezier path. It's -bezierPathForDrawing's responsibility to return a path with the current stroke width.
  NSBezierPath *path = [self bezierPathForDrawing];
  if (path) {
    if ([self isDrawingFill]) {
      [[self fillColor] set];
      [path fill];
    }
    if ([self isDrawingStroke]) {
      [[self strokeColor] set];
      [path stroke];
    }
  }

}

- (NSBezierPath *)bezierPathForDrawing {

  // Live to be overriden.
  [NSException raise:NSInternalInconsistencyException format:@"Neither -drawContentsInView: nor -bezierPathForDrawing has been overridden."];
  return nil;

}


- (void)drawHandlesInView:(NSView *)view {

  // Draw handles at the corners and on the sides.
  NSRect bounds = [self bounds];
  [self drawHandleInView:view atPoint:NSMakePoint(NSMinX(bounds), NSMinY(bounds))];
  [self drawHandleInView:view atPoint:NSMakePoint(NSMidX(bounds), NSMinY(bounds))];
  [self drawHandleInView:view atPoint:NSMakePoint(NSMaxX(bounds), NSMinY(bounds))];
  [self drawHandleInView:view atPoint:NSMakePoint(NSMinX(bounds), NSMidY(bounds))];
  [self drawHandleInView:view atPoint:NSMakePoint(NSMaxX(bounds), NSMidY(bounds))];
  [self drawHandleInView:view atPoint:NSMakePoint(NSMinX(bounds), NSMaxY(bounds))];
  [self drawHandleInView:view atPoint:NSMakePoint(NSMidX(bounds), NSMaxY(bounds))];
  [self drawHandleInView:view atPoint:NSMakePoint(NSMaxX(bounds), NSMaxY(bounds))];

}


- (void)drawHandleInView:(NSView<SKTHasHandles> *)view atPoint:(NSPoint)point {

  // Figure out a rectangle that's centered on the point but lined up with device pixels.
  NSRect handleBounds;
  CGFloat handleWidth = view.handleWidth;
  handleBounds.origin.x = point.x - handleWidth / 2.0f;
  handleBounds.origin.y = point.y - handleWidth / 2.0f;
  handleBounds.size.width = handleWidth;
  handleBounds.size.height = handleWidth;
  handleBounds = [view centerScanRect:handleBounds];

  // Draw the shadow of the handle.
  NSRect handleShadowBounds = NSOffsetRect(handleBounds, 1.0f, 1.0f);
  [[NSColor controlDarkShadowColor] set];
  NSRectFill(handleShadowBounds);

  // Draw the handle itself.
  [_locked ? [NSColor selectedKnobColor] : [NSColor knobColor] set];
  NSRectFill(handleBounds);

}


#pragma mark - Editing


+ (NSCursor *)creationCursor {

  // By default we use the crosshairs cursor.
  static NSCursor *crosshairsCursor = nil;
  if (!crosshairsCursor) {
    NSImage *crosshairsImage = [NSImage imageNamed:@"Cross"];
    NSSize crosshairsImageSize = [crosshairsImage size];
    crosshairsCursor = [[NSCursor alloc] initWithImage:crosshairsImage hotSpot:NSMakePoint((crosshairsImageSize.width / 2.0), (crosshairsImageSize.height / 2.0))];
  }
  return crosshairsCursor;

}


+ (NSInteger)creationSizingHandle {

  // Return the number of the handle for the lower-right corner. If the user drags it so that it's no longer in the lower-right, -resizeByMovingHandle:toPoint: will deal with it.
  return SKTGraphicLowerRightHandle;

}


- (BOOL)canSetDrawingFill {
  // The default implementation of -drawContentsInView: can draw fills.
  return ! _locked;

}


- (BOOL)canSetDrawingStroke {
  // The default implementation of -drawContentsInView: can draw strokes.
  return ! _locked;

}


- (BOOL)canMakeNaturalSize {
  // Only return YES if -makeNaturalSize would actually do something.
  NSRect bounds = [self bounds];
  return ! _locked && bounds.size.width != bounds.size.height;

}


- (BOOL)isContentsUnderPoint:(NSPoint)point {

  // Just check against the graphic's bounds.
  return NSPointInRect(point, [self bounds]);

}


- (NSInteger)handleUnderPoint:(NSPoint)point  inView:(NSView<SKTHasHandles> *)view {

  // Check handles at the corners and on the sides.
  NSInteger handle = SKTGraphicNoHandle;
  NSRect bounds = [self bounds];
  if ([self isHandleAtPoint:NSMakePoint(NSMinX(bounds), NSMinY(bounds)) underPoint:point inView:view]) {
    handle = SKTGraphicUpperLeftHandle;
  } else if ([self isHandleAtPoint:NSMakePoint(NSMidX(bounds), NSMinY(bounds)) underPoint:point inView:view]) {
    handle = SKTGraphicUpperMiddleHandle;
  } else if ([self isHandleAtPoint:NSMakePoint(NSMaxX(bounds), NSMinY(bounds)) underPoint:point inView:view]) {
    handle = SKTGraphicUpperRightHandle;
  } else if ([self isHandleAtPoint:NSMakePoint(NSMinX(bounds), NSMidY(bounds)) underPoint:point inView:view]) {
    handle = SKTGraphicMiddleLeftHandle;
  } else if ([self isHandleAtPoint:NSMakePoint(NSMaxX(bounds), NSMidY(bounds)) underPoint:point inView:view]) {
    handle = SKTGraphicMiddleRightHandle;
  } else if ([self isHandleAtPoint:NSMakePoint(NSMinX(bounds), NSMaxY(bounds)) underPoint:point inView:view]) {
    handle = SKTGraphicLowerLeftHandle;
  } else if ([self isHandleAtPoint:NSMakePoint(NSMidX(bounds), NSMaxY(bounds)) underPoint:point inView:view]) {
    handle = SKTGraphicLowerMiddleHandle;
  } else if ([self isHandleAtPoint:NSMakePoint(NSMaxX(bounds), NSMaxY(bounds)) underPoint:point inView:view]) {
    handle = SKTGraphicLowerRightHandle;
  }
  return handle;

}


- (BOOL)isHandleAtPoint:(NSPoint)handlePoint underPoint:(NSPoint)point inView:(NSView<SKTHasHandles> *)view {
  // Check a handle-sized rectangle that's centered on the handle point.
  NSRect handleBounds;
  CGFloat handleWidth = view.handleWidth;
  handleBounds.origin.x = handlePoint.x - handleWidth / 2.0f;
  handleBounds.origin.y = handlePoint.y - handleWidth / 2.0f;
  handleBounds.size.width = handleWidth;
  handleBounds.size.height = handleWidth;
  return NSPointInRect(point, handleBounds);

}


- (NSInteger)resizeByMovingHandle:(NSInteger)handle toPoint:(NSPoint)point {

  // Start with the original bounds.
  NSRect bounds = [self bounds];

  // Is the user changing the width of the graphic?
  if (handle == SKTGraphicUpperLeftHandle || handle == SKTGraphicMiddleLeftHandle || handle == SKTGraphicLowerLeftHandle) {

    // Change the left edge of the graphic.
    bounds.size.width = NSMaxX(bounds) - point.x;
    bounds.origin.x = point.x;

  } else if (handle == SKTGraphicUpperRightHandle || handle == SKTGraphicMiddleRightHandle || handle == SKTGraphicLowerRightHandle) {

    // Change the right edge of the graphic.
    bounds.size.width = point.x - bounds.origin.x;

  }

  // Did the user actually flip the graphic over?
  if (bounds.size.width < 0.0f) {

    // The handle is now playing a different role relative to the graphic.
    static NSInteger flippings[9];
    static BOOL flippingsInitialized = NO;
    if (!flippingsInitialized) {
      flippings[SKTGraphicUpperLeftHandle] = SKTGraphicUpperRightHandle;
      flippings[SKTGraphicUpperMiddleHandle] = SKTGraphicUpperMiddleHandle;
      flippings[SKTGraphicUpperRightHandle] = SKTGraphicUpperLeftHandle;
      flippings[SKTGraphicMiddleLeftHandle] = SKTGraphicMiddleRightHandle;
      flippings[SKTGraphicMiddleRightHandle] = SKTGraphicMiddleLeftHandle;
      flippings[SKTGraphicLowerLeftHandle] = SKTGraphicLowerRightHandle;
      flippings[SKTGraphicLowerMiddleHandle] = SKTGraphicLowerMiddleHandle;
      flippings[SKTGraphicLowerRightHandle] = SKTGraphicLowerLeftHandle;
      flippingsInitialized = YES;
    }
    handle = flippings[handle];

    // Make the graphic's width positive again.
    bounds.size.width = 0.0f - bounds.size.width;
    bounds.origin.x -= bounds.size.width;

    // Tell interested subclass code what just happened.
    [self flipHorizontally];

  }

  // Is the user changing the height of the graphic?
  if (handle == SKTGraphicUpperLeftHandle || handle == SKTGraphicUpperMiddleHandle || handle == SKTGraphicUpperRightHandle) {

    // Change the top edge of the graphic.
    bounds.size.height = NSMaxY(bounds) - point.y;
    bounds.origin.y = point.y;

  } else if (handle == SKTGraphicLowerLeftHandle || handle == SKTGraphicLowerMiddleHandle || handle == SKTGraphicLowerRightHandle) {

    // Change the bottom edge of the graphic.
    bounds.size.height = point.y - bounds.origin.y;

  }

  // Did the user actually flip the graphic upside down?
  if (bounds.size.height < 0.0f) {

    // The handle is now playing a different role relative to the graphic.
    static NSInteger flippings[9];
    static BOOL flippingsInitialized = NO;
    if (!flippingsInitialized) {
      flippings[SKTGraphicUpperLeftHandle] = SKTGraphicLowerLeftHandle;
      flippings[SKTGraphicUpperMiddleHandle] = SKTGraphicLowerMiddleHandle;
      flippings[SKTGraphicUpperRightHandle] = SKTGraphicLowerRightHandle;
      flippings[SKTGraphicMiddleLeftHandle] = SKTGraphicMiddleLeftHandle;
      flippings[SKTGraphicMiddleRightHandle] = SKTGraphicMiddleRightHandle;
      flippings[SKTGraphicLowerLeftHandle] = SKTGraphicUpperLeftHandle;
      flippings[SKTGraphicLowerMiddleHandle] = SKTGraphicUpperMiddleHandle;
      flippings[SKTGraphicLowerRightHandle] = SKTGraphicUpperRightHandle;
      flippingsInitialized = YES;
    }
    handle = flippings[handle];

    // Make the graphic's height positive again.
    bounds.size.height = 0.0f - bounds.size.height;
    bounds.origin.y -= bounds.size.height;

    // Tell interested subclass code what just happened.
    [self flipVertically];

  }

  // Done.
  [self setBounds:bounds];
  return handle;

}


- (void)flipHorizontally {

  // Live to be overridden.

}


- (void)flipVertically {

  // Live to be overridden.

}


- (void)makeNaturalSize {

  // Just make the graphic square.
  NSRect bounds = [self bounds];
  if (bounds.size.width < bounds.size.height) {
    bounds.size.height = bounds.size.width;
    [self setBounds:bounds];
  } else if (bounds.size.width > bounds.size.height) {
    bounds.size.width = bounds.size.height;
    [self setBounds:bounds];
  }

}

- (NSRect)bounds {
  return _bounds;
}

- (void)setBounds:(NSRect)bounds {
  if ( ! _locked) {
    _bounds = bounds;
  }
}


- (void)setColor:(NSColor *)color {
  if ( ! _locked) {

  // This method demonstrates something interesting: we haven't bothered to provide setter methods for the properties we want to change, but we can still change them using KVC. KVO autonotification will make sure observers hear about the change (it works with -setValue:forKey: as well as -set<Key>:). Of course, if we found ourselves doing this a little more often we would go ahead and just add the setter methods. The point is that KVC direct instance variable access very often makes boilerplate accessors unnecessary but if you want to just put them in right away, eh, go ahead.

    // Can we fill the graphic?
    if ([self canSetDrawingFill]) {
      // Are we filling it? If not, start, using the new color.
      if (![self isDrawingFill]) {
        [self setValue:@YES forKey:SKTGraphicIsDrawingFillKey];
      }
      [self setValue:color forKey:SKTGraphicFillColorKey];
    }
  }
}


- (NSView *)newEditingViewWithSuperviewBounds:(NSRect)superviewBounds {
  // Live to be overridden.
  return nil;
}


- (void)finalizeEditingView:(NSView *)editingView {

  // Live to be overridden.

}

#pragma mark - Undo

// Of the properties managed by SKTGraphic, "drawingingBounds," "drawingContents," "canSetDrawingFill," and "canSetDrawingStroke" aren't anything that the user changes, so changes of their values aren't registered undo operations. "xPosition," "yPosition," "width," and "height" are all derived from "bounds," so we don't need to register those either. Changes of any other property are undoable.
- (NSSet *)keysForValuesToObserveForUndo {
  return [NSSet setWithObjects:SKTGraphicIsDrawingFillKey, SKTGraphicFillColorKey, SKTGraphicIsDrawingStrokeKey, SKTGraphicStrokeColorKey, SKTGraphicStrokeWidthKey, SKTGraphicBoundsKey, SKTGraphicLockedKey, nil];
}

// Pretty simple. Don't be surprised if you never see "Bounds" appear in an undo action name in FloorSketch. SKTGraphicView invokes -[NSUndoManager setActionName:] for things like moving, resizing, and aligning, thereby overwriting whatever SKTDocument sets with something more specific.
+ (NSString *)presentablePropertyNameForKey:(NSString *)key {
  static NSDictionary *presentablePropertyNamesByKey = nil;
  if (!presentablePropertyNamesByKey) {
    presentablePropertyNamesByKey = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                     NSLocalizedStringFromTable(@"Filling", @"UndoStrings", @"Action name part for SKTGraphicIsDrawingFillKey."), SKTGraphicIsDrawingFillKey,
                                     NSLocalizedStringFromTable(@"Fill Color", @"UndoStrings",@"Action name part for SKTGraphicFillColorKey."), SKTGraphicFillColorKey,
                                     NSLocalizedStringFromTable(@"Lock", @"UndoStrings",@"Action name part for SKTGraphicLockedKey."), SKTGraphicLockedKey,
                                     NSLocalizedStringFromTable(@"Stroking", @"UndoStrings", @"Action name part for SKTGraphicIsDrawingStrokeKey."), SKTGraphicIsDrawingStrokeKey,
                                     NSLocalizedStringFromTable(@"Stroke Color", @"UndoStrings", @"Action name part for SKTGraphicStrokeColorKey."), SKTGraphicStrokeColorKey,
                                     NSLocalizedStringFromTable(@"Stroke Width", @"UndoStrings", @"Action name part for SKTGraphicStrokeWidthKey."), SKTGraphicStrokeWidthKey,
                                     NSLocalizedStringFromTable(@"Bounds", @"UndoStrings", @"Action name part for SKTGraphicBoundsKey."), SKTGraphicBoundsKey,
                                     nil];
  }
  return presentablePropertyNamesByKey[key];
}


#pragma mark - Scripting

// Conformance to the NSObject(NSScriptObjectSpecifiers) informal protocol.
- (NSScriptObjectSpecifier *)objectSpecifier {

  // This object can't create an object specifier for itself, so ask its scriptable container to do it.
  NSScriptObjectSpecifier *objectSpecifier = [_scriptingContainer objectSpecifierForGraphic:self];
  if (!objectSpecifier) {
    [NSException raise:NSInternalInconsistencyException format:@"A scriptable graphic has no scriptable container, or one that doesn't implement -objectSpecifierForGraphic: correctly."];
  }
  return objectSpecifier;
}

// Return nil if the graphic is not filled. The scripter will see that as "missing value."
- (NSColor *)scriptingFillColor {
  return [self isDrawingFill] ? [self fillColor] : nil;
}


// Return nil if the graphic is not stroked. The scripter will see that as "missing value."
- (NSColor *)scriptingStrokeColor {
  return [self isDrawingStroke] ? [self strokeColor] : nil;
}


// Return nil if the graphic is not stroked. The scripter will see that as "missing value."
- (NSNumber *)scriptingStrokeWidth {
  return [self isDrawingStroke] ? @([self strokeWidth]) : nil;
}

// See the comment in -setColor: about using KVC like we do here.
- (void)setScriptingFillColor:(NSColor *)fillColor {


  // For the convenience of scripters, turn filling on or off if necessary, if that's allowed. Don't forget that -isDrawingFill can return YES or NO regardless of what -canSetDrawingFill is returning.
  if (fillColor) {
    BOOL canSetFillColor = YES;
    if (![self isDrawingFill]) {
      if ([self canSetDrawingFill]) {
        [self setValue:@YES forKey:SKTGraphicIsDrawingFillKey];
      } else {

        // Not allowed. Tell the scripter what happened.
        NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
        [currentScriptCommand setScriptErrorNumber:errAEEventFailed];
        [currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't set the fill color of this kind of graphic.", @"SKTError", @"A scripting error message.")];
        canSetFillColor = NO;

      }
    }
    if (canSetFillColor) {
      [self setValue:fillColor forKey:SKTGraphicFillColorKey];
    }
  } else {
    if ([self isDrawingFill]) {
      if ([self canSetDrawingFill]) {
        [self setValue:@NO forKey:SKTGraphicIsDrawingFillKey];
      } else {

        // Not allowed. Tell the scripter what happened.
        NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
        [currentScriptCommand setScriptErrorNumber:errAEEventFailed];
        [currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't remove the fill from this kind of graphic.", @"SKTError", @"A scripting error message.")];

      }
    }
  }

}


// The same as above, but for stroke color instead of fill color.
- (void)setScriptingStrokeColor:(NSColor *)strokeColor {
  if (strokeColor) {
    BOOL canSetStrokeColor = YES;
    if (![self isDrawingStroke]) {
      if ([self canSetDrawingStroke]) {
        [self setValue:@YES forKey:SKTGraphicIsDrawingStrokeKey];
      } else {
        NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
        [currentScriptCommand setScriptErrorNumber:errAEEventFailed];
        [currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't set the stroke color of this kind of graphic.", @"SKTError", @"A scripting error message.")];
        canSetStrokeColor = NO;
      }
    }
    if (canSetStrokeColor) {
      [self setValue:strokeColor forKey:SKTGraphicStrokeColorKey];
    }
  } else {
    if ([self isDrawingStroke]) {
      if ([self canSetDrawingStroke]) {
        [self setValue:@NO forKey:SKTGraphicIsDrawingStrokeKey];
      } else {
        NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
        [currentScriptCommand setScriptErrorNumber:errAEEventFailed];
        [currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't remove the stroke from this kind of graphic.", @"SKTError", @"A scripting error message.")];
      }
    }
  }
}


- (void)setScriptingStrokeWidth:(NSNumber *)strokeWidth {
  // See the comment in -setColor: about using KVC like we do here.

  // For the convenience of scripters, turn stroking on or off if necessary, if that's allowed. Don't forget that -isDrawingStroke can return YES or NO regardless of what -canSetDrawingStroke is returning.
  if (strokeWidth) {
    BOOL canSetStrokeWidth = YES;
    if (![self isDrawingStroke]) {
      if ([self canSetDrawingStroke]) {
        [self setValue:@YES forKey:SKTGraphicIsDrawingStrokeKey];
      } else {

        // Not allowed. Tell the scripter what happened.
        NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
        [currentScriptCommand setScriptErrorNumber:errAEEventFailed];
        [currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't set the stroke thickness of this kind of graphic.", @"SKTError", @"A scripting error message.")];
        canSetStrokeWidth = NO;

      }
    }
    if (canSetStrokeWidth) {
      [self setValue:strokeWidth forKey:SKTGraphicStrokeWidthKey];
    }
  } else {
    if ([self isDrawingStroke]) {
      if ([self canSetDrawingStroke]) {
        [self setValue:@NO forKey:SKTGraphicIsDrawingStrokeKey];
      } else {
        // Not allowed. Tell the scripter what happened.
        NSScriptCommand *currentScriptCommand = [NSScriptCommand currentCommand];
        [currentScriptCommand setScriptErrorNumber:errAEEventFailed];
        [currentScriptCommand setScriptErrorString:NSLocalizedStringFromTable(@"You can't remove the stroke from this kind of graphic.", @"SKTError", @"A scripting error message.")];
      }
    }
  }
}

#pragma mark - Debugging

// An override of the NSObject method. Make 'po aGraphic' do something useful in gdb.
- (NSString *)description {
  return [[self debugProperties] description];
}

@end
