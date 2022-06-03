/*
 File: SKTRenderingView.m
 Abstract: A view to create TIFF and PDF representations of a collection of graphic objects.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTRenderingView.h"
#import "SKTError.h"
#import "SKTGraphic.h"

@interface SKTRenderingView() {
  // The graphics and print job title that were specified at initialization time.
  NSArray *_graphics;
  NSString *_printJobTitle;
}

@end


@implementation SKTRenderingView

+ (NSRect)drawingBoundsOfGraphics:(NSArray *)graphics {
  // The drawing bounds of an array of graphics is the union of all of their drawing bounds.
  NSRect drawingBounds = NSZeroRect;
  NSUInteger graphicCount = [graphics count];
  if (graphicCount > 0) {
    drawingBounds = [graphics[0] drawingBounds];
    for (NSUInteger index = 1; index < graphicCount; index++) {
      drawingBounds = NSUnionRect(drawingBounds, [graphics[index] drawingBounds]);
    }
  }
  return drawingBounds;

}


+ (NSData *)pdfDataWithGraphics:(NSArray *)graphics {

  // Create a view that will be used just for making PDF.
  NSRect bounds = [self drawingBoundsOfGraphics:graphics];
  SKTRenderingView *view = [[SKTRenderingView alloc] initWithFrame:bounds graphics:graphics printJobTitle:nil];
  NSData *pdfData = [view dataWithPDFInsideRect:bounds];
  return pdfData;
}


+ (NSImage *)imageWithGraphics:(NSArray *)graphics error:(NSError **)outError {
  NSImage *image = nil;
  NSRect bounds = [self drawingBoundsOfGraphics:graphics];
  bounds.size.width += bounds.origin.x;
  bounds.size.height += bounds.origin.y;
  bounds.origin = CGPointZero;
  if (! NSIsEmptyRect(bounds)) {
    // Create a new image and prepare to draw in it. Get the graphics context for it after we lock focus, not before.
    image = [NSImage imageWithSize:bounds.size flipped:YES drawingHandler:^(NSRect dstRect){
      NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];

      // We're not drawing a page image here, just the rectangle that contains the graphics being drawn, so make sure they get drawn in the right place.
      NSAffineTransform *transform = [NSAffineTransform transform];
      [transform translateXBy:(0.0f - dstRect.origin.x) yBy:(0.0f - dstRect.origin.y)];
      [transform concat];

      // Draw the graphics back to front.

      for (int graphicIndex = ((int)[graphics count]) - 1;0 <= graphicIndex; --graphicIndex) {
        SKTGraphic *graphic = graphics[graphicIndex];
        [currentContext saveGraphicsState];
        [NSBezierPath clipRect:[graphic drawingBounds]];
        [graphic drawContentsInView:nil rect:bounds isBeingCreateOrEdited:NO];
        [currentContext restoreGraphicsState];
      }
      return YES;
    }];
  }
  return image;
}

+ (NSData *)pngDataWithGraphics:(NSArray *)graphics error:(NSError **)outError {
  NSData *result = nil;
  NSImage *image = [self imageWithGraphics:graphics error:outError];
  NSRect bounds = [self drawingBoundsOfGraphics:graphics];
  bounds.size.width += bounds.origin.x;
  bounds.size.height += bounds.origin.y;
  bounds.origin = CGPointZero;
  NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
  CGImageRef cgImage = [image CGImageForProposedRect:&bounds context:currentContext hints:nil];
  if (cgImage) {
    NSBitmapImageRep *bitmapImage = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    result = [bitmapImage representationUsingType:NSPNGFileType properties:@{}];
  }
  return result;
}

+ (NSData *)tiffDataWithGraphics:(NSArray *)graphics error:(NSError **)outError {
  // How big of a TIFF are we going to make? Regardless of what NSImage supports, FloorSketch doesn't support the creation of TIFFs that are 0 by 0 pixels. (We have to demonstrate a custom saving error somewhere, and this is an easy place to do it...)
  NSImage *image = [self imageWithGraphics:graphics error:outError];
  NSData *tiffData = [image TIFFRepresentation];
  if (nil == tiffData && outError) {
    // In FloorSketch there are lots of places to catch this situation earlier. For example, we could have overridden -writableTypesForSaveOperation: and made it not return NSTIFFPboardType, but then the user would have no idea why TIFF isn't showing up in the save panel's File Format popup. This way we can present a nice descriptive errror message.
    *outError = SKTErrorWithCode(SKTWriteCouldntMakeTIFFError);
  }
  return tiffData;
}

- (instancetype)initWithFrame:(NSRect)frame graphics:(NSArray *)graphics printJobTitle:(NSString *)printJobTitle {
  self = [super initWithFrame:frame];
  if (self) {
    _graphics = [graphics copy];
    _printJobTitle = [printJobTitle copy];
  }
  return self;
}

// An override of the NSView method.
- (void)drawRect:(NSRect)rect {
  // Draw the background color.
  [[NSColor whiteColor] set];
  NSRectFill(rect);

  // Draw every graphic that intersects the rectangle to be drawn. In FloorSketch the frontmost graphics have the lowest indexes.
  NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
  NSInteger graphicCount = [_graphics count];
  for (NSInteger index = graphicCount - 1; index >= 0; index--) {
    SKTGraphic *graphic = _graphics[index];
    NSRect graphicDrawingBounds = [graphic drawingBounds];
    if (NSIntersectsRect(rect, graphicDrawingBounds)) {

      // Draw the graphic.
      [currentContext saveGraphicsState];
      [NSBezierPath clipRect:graphicDrawingBounds];
      [graphic drawContentsInView:self rect:rect isBeingCreateOrEdited:NO];
      [currentContext restoreGraphicsState];

    }
  }

}


// An override of the NSView method.
- (BOOL)isFlipped {
  // Put (0, 0) at the top-left of the view.
  return YES;

}


// An override of the NSView method.
- (BOOL)isOpaque {
  // Our override of -drawRect: always draws a background.
  return YES;

}

// An override of the NSView method.
- (NSString *)printJobTitle {
  return _printJobTitle;

}
@end
