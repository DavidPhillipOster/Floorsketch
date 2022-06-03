/*
 File: SKTImage.m
 Abstract: A graphic object to represent an image.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTImage.h"


// String constants declared in the header. They may not be used by any other class in the project, but it's a good idea to provide and use them, if only to help prevent typos in source code.
NSString *SKTImageIsFlippedHorizontallyKey = @"flippedHorizontally";
NSString *SKTImageIsFlippedVerticallyKey = @"flippedVertically";
NSString *SKTImageFilePathKey = @"filePath";

// Another key, which is just used in persistent property dictionaries.
NSString *SKTImageContentsKey = @"contents";

@interface SKTImage() {
  // The image that's being presented.
  NSImage *_contents;

  // The values underlying some of the key-value coding (KVC) and observing (KVO) compliance described below.
  BOOL _isFlippedHorizontally;
  BOOL _isFlippedVertically;
}

@end

@implementation SKTImage


- (id)copyWithZone:(NSZone *)zone {
  SKTImage *copy = [super copyWithZone:zone];
  copy->_contents = [_contents copy];
  return copy;
}




#pragma mark - Private KVC-Compliance for Public Properties


- (void)setFlippedHorizontally:(BOOL)isFlippedHorizontally {

  // Record the value and flush the transformed contents cache.
  _isFlippedHorizontally = isFlippedHorizontally;
}

- (void)setFlippedVertically:(BOOL)isFlippedVertically {
  // Record the value and flush the transformed contents cache.
  _isFlippedVertically = isFlippedVertically;

}

- (void)setFilePath:(NSString *)filePath {
  // If there's a transformed version of the contents being held as a cache, it's invalid now.
  NSImage *newContents = [[NSImage alloc] initWithContentsOfFile:[filePath stringByStandardizingPath]];
  _contents = newContents;

}

#pragma mark - Public Methods

- (instancetype)initWithPosition:(NSPoint)position contents:(NSImage *)contents {
  self = [self init];
  if (self) {
    _contents = contents;
    // Leave the image centered on the mouse pointer.
    NSSize contentsSize = [_contents size];
    [self setBounds:NSMakeRect((position.x - (contentsSize.width / 2.0f)), (position.y - (contentsSize.height / 2.0f)), contentsSize.width, contentsSize.height)];
  }
  return self;
}

#pragma mark - Overrides of SKTGraphic Methods


- (instancetype)initWithProperties:(NSDictionary *)properties {
  // Let SKTGraphic do its job and then handle the additional properties defined by this subclass.
  self = [super initWithProperties:properties];
  if (self) {
    CGFloat width = [properties[SKTGraphicWidthKey] floatValue];
    CGFloat height = [properties[SKTGraphicHeightKey] floatValue];
    if (0 < width && 0 < height) {
      CGRect bounds = self.bounds;
      bounds.size = NSMakeSize(width, height);
      self.bounds = bounds;
    }

    // The dictionary entries are all instances of the classes that can be written in property lists. Don't trust the type of something you get out of a property list unless you know your process created it or it was read from your application or framework's resources. We don't have to worry about KVO-compliance in initializers like this by the way; no one should be observing an unitialized object.
    NSData *contentsData = properties[SKTImageContentsKey];
    if ([contentsData isKindOfClass:[NSData class]]) {
      NSImage *contents = [NSUnarchiver unarchiveObjectWithData:contentsData];
      if ([contents isKindOfClass:[NSImage class]]) {
        _contents = contents;
      }
    }
    NSNumber *isFlippedHorizontallyNumber = properties[SKTImageIsFlippedHorizontallyKey];
    if ([isFlippedHorizontallyNumber isKindOfClass:[NSNumber class]]) {
      _isFlippedHorizontally = [isFlippedHorizontallyNumber boolValue];
    }
    NSNumber *isFlippedVerticallyNumber = properties[SKTImageIsFlippedVerticallyKey];
    if ([isFlippedVerticallyNumber isKindOfClass:[NSNumber class]]) {
      _isFlippedVertically = [isFlippedVerticallyNumber boolValue];
    }

  }
  return self;

}


- (NSMutableDictionary *)properties {

  // Let SKTGraphic do its job and then handle the one additional property defined by this subclass. The dictionary must contain nothing but values that can be written in old-style property lists.
  NSMutableDictionary *properties = [super properties];
  properties[SKTImageContentsKey] = [NSArchiver archivedDataWithRootObject:_contents];
  properties[SKTImageIsFlippedHorizontallyKey] = @(_isFlippedHorizontally);
  properties[SKTImageIsFlippedVerticallyKey] = @(_isFlippedVertically);
  return properties;

}

- (NSString *)imageAsBase64 {
    [_contents lockFocus];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, _contents.size.width, _contents.size.height)];
    [_contents unlockFocus];
    NSData *data = [bitmapRep representationUsingType:NSPNGFileType properties:@{}];
    return [data base64EncodedStringWithOptions:NSDataBase64Encoding76CharacterLineLength | NSDataBase64EncodingEndLineWithLineFeed];
}

- (NSString *)imageAsXlink {
  if (_contents) {
    NSString *imageAsBase64 = [self imageAsBase64];
    if (imageAsBase64) {
      return [NSString stringWithFormat:@"xlink:href=\"data:image/png;base64,%@\"", imageAsBase64];
    }
  }
  return @"";
}

- (NSString *)asSVGString {
  return [self asSVGStringVerb:@"image"];
}

- (NSString *)svgAttributesString {
  return [NSString stringWithFormat:@"x=\"%.5g\" y=\"%.5g\" width=\"%.5g\" height=\"%.5g\" %@ %@",
    self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height,
    [self imageAsXlink],
    [super svgAttributesString]];
}


- (BOOL)isDrawingFill {

  // We never fill an image with color.
  return NO;

}


- (BOOL)isDrawingStroke {

  // We never draw a stroke on an image.
  return NO;

}


+ (NSSet *)keyPathsForValuesAffectingDrawingContents {

  // Flipping affects drawing but not the drawing bounds. So of course do the properties managed by the superclass.
  NSMutableSet *keys = [[super keyPathsForValuesAffectingDrawingContents] mutableCopy];
  [keys addObject:SKTImageIsFlippedHorizontallyKey];
  [keys addObject:SKTImageIsFlippedVerticallyKey];
  return keys;

}


- (void)drawContentsInView:(NSView *)view rect:(NSRect)rect isBeingCreateOrEdited:(BOOL)isBeingCreatedOrEditing {

  // Fill the background with the fill color. Maybe it will show, if the image has an alpha channel.
  NSRect bounds = [self bounds];
  if ([self isDrawingFill]) {
    [[self fillColor] set];
    NSRectFill(bounds);
  }

  // Surprisingly, NSImage's -draw... methods don't take into account whether or not the view is flipped. In FloorSketch, SKTGraphicViews are flipped (and this model class is not supposed to have dependencies on the oddities of any particular view class anyway). So, just do our own transformation matrix manipulation.
  NSAffineTransform *transform = [NSAffineTransform transform];

  // Translating to actually place the image (as opposed to translating as part of flipping).
  [transform translateXBy:bounds.origin.x yBy:bounds.origin.y];

  // Flipping according to the user's wishes.
  [transform translateXBy:(_isFlippedHorizontally ? bounds.size.width : 0.0f) yBy:(_isFlippedVertically ? bounds.size.height : 0.0f)];
  [transform scaleXBy:(_isFlippedHorizontally ? -1.0f : 1.0f) yBy:(_isFlippedVertically ? -1.0f : 1.0f)];

  // Scaling to actually size the image (as opposed to scaling as part of flipping).
  NSSize contentsSize = [_contents size];
  [transform scaleXBy:(bounds.size.width / contentsSize.width) yBy:(bounds.size.height / contentsSize.height)];

  // Flipping to accomodate -[NSImage drawAtPoint:fromRect:operation:fraction:]'s odd behavior.
  if ([view isFlipped]) {
    [transform translateXBy:0.0f yBy:contentsSize.height];
    [transform scaleXBy:1.0f yBy:-1.0f];
  }

  // Do the actual drawing, saving and restoring the graphics state so as not to interfere with the drawing of selection handles or anything else in the same view.
  [[NSGraphicsContext currentContext] saveGraphicsState];
  [transform concat];
  [_contents drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0.0f, 0.0f, contentsSize.width, contentsSize.height) operation:NSCompositeSourceOver fraction:1.0f];
  [[NSGraphicsContext currentContext] restoreGraphicsState];

}


- (BOOL)canSetDrawingFill {

  // Don't let the user think we would even try to fill an image with color.
  return NO;

}


- (BOOL)canSetDrawingStroke {

  // Don't let the user think we would even try to draw a stroke on image.
  return NO;

}


- (void)flipHorizontally {

  // Simple.
  [self setFlippedHorizontally:(_isFlippedHorizontally ? NO : YES)];

}

- (void)flipVertically {

  // Simple.
  [self setFlippedVertically:(_isFlippedVertically ? NO : YES)];

}


- (void)makeNaturalSize {

  // Return the image to its natural size and stop flipping it.
  NSRect bounds = [self bounds];
  bounds.size = [_contents size];
  [self setBounds:bounds];
  [self setFlippedHorizontally:NO];
  [self setFlippedVertically:NO];

}


- (void)setBounds:(NSRect)bounds {

  // Flush the transformed contents cache and then do the regular SKTGraphic thing.
  [super setBounds:bounds];

}


- (NSSet *)keysForValuesToObserveForUndo {

  // This class defines a few properties for which changes are undoable, in addition to the ones inherited from SKTGraphic.
  NSMutableSet *keys = [[super keysForValuesToObserveForUndo] mutableCopy];
  [keys addObject:SKTImageIsFlippedHorizontallyKey];
  [keys addObject:SKTImageIsFlippedVerticallyKey];
  return keys;

}


+ (NSString *)presentablePropertyNameForKey:(NSString *)key {

  // Pretty simple. As is usually the case when a key is passed into a method like this, we have to invoke super if we don't recognize the key.
  static NSDictionary *presentablePropertyNamesByKey = nil;
  if (!presentablePropertyNamesByKey) {
    presentablePropertyNamesByKey = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                     NSLocalizedStringFromTable(@"Horizontal Flipping", @"UndoStrings", @"Action name part for SKTImageIsFlippedHorizontallyKey."), SKTImageIsFlippedHorizontallyKey,
                                     NSLocalizedStringFromTable(@"Vertical Flipping", @"UndoStrings",@"Action name part for SKTImageIsFlippedVerticallyKey."), SKTImageIsFlippedVerticallyKey,
                                     nil];
  }
  NSString *presentablePropertyName = presentablePropertyNamesByKey[key];
  if (!presentablePropertyName) {
    presentablePropertyName = [super presentablePropertyNameForKey:key];
  }
  return presentablePropertyName;

}


@end
