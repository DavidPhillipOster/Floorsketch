/*
     File: SKTDocument.h
 Abstract: The main document class for the application.
  Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import <Cocoa/Cocoa.h>

extern NSString *const SKTDocumentVisibleRulerKey;
extern NSString *const SKTDocumentScaleKey;
extern NSString *const SKTDocumentGridColorKey;
extern NSString *const SKTDocumentGridSpacingKey;
extern NSString *const SKTDocumentGridAlwaysShownKey;
extern NSString *const SKTDocumentGridConstrainingKey;


// The keys described down below.
extern NSString *const SKTDocumentCanvasSizeKey;
extern NSString *const SKTDocumentGraphicsKey;


@interface SKTDocument : NSDocument
/* This class is KVC and KVO compliant for these keys:

 "canvasSize" (an NSSize-containing NSValue; read-only) - The size of the document's canvas. This is derived from the currently selected paper size and document margins.

 "graphics" (an NSArray of SKTGraphics; read-write) - the graphics of the document.

 In FloorSketch the graphics property of each SKTGraphicView is bound to the graphics property of the document whose contents its presented. Also, the graphics relationship of an SKTDocument is scriptable.

 */

// Return the current value of the property.
@property (NS_NONATOMIC_IOSONLY, readonly) NSSize canvasSize;

@property NSDictionary *propertiesWhileOpening;

// For applescripting the align verb.
- (void)alignBottomEdgesOfGraphics:(NSArray *)array;
- (void)alignHorizontalCentersOfGraphics:(NSArray *)array;
- (void)alignLeftEdgesOfGraphics:(NSArray *)array;
- (void)alignRightEdgesOfGraphics:(NSArray *)array;
- (void)alignTopEdgesOfGraphics:(NSArray *)array;
- (void)alignVerticalCentersOfGraphics:(NSArray *)array;

@end
