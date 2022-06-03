/*
 File: SKTRenderingView.h
 Abstract: A view to create TIFF and PDF representations of a collection of graphic objects.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import <Cocoa/Cocoa.h>

@interface SKTRenderingView : NSView

// Return the array of graphics as a PDF image.
+ (NSData *)pdfDataWithGraphics:(NSArray *)graphics;

// Return the array of graphics as a TIFF image.
+ (NSData *)tiffDataWithGraphics:(NSArray *)graphics error:(NSError **)outError;

// Return the array of graphics as a PNG image.
+ (NSData *)pngDataWithGraphics:(NSArray *)graphics error:(NSError **)outError;


// This class' designated initializer. printJobTitle must be non-nil if the view is going to be used as the view of an NSPrintOperation.
- (instancetype)initWithFrame:(NSRect)frame graphics:(NSArray *)graphics printJobTitle:(NSString *)printJobTitle NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
@end
