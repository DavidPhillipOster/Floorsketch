/*
 File: SKTImage.h
 Abstract: A graphic object to represent an image.
 Version: 1.8

  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTGraphic.h"

// The keys described down below.
extern NSString *SKTImageIsFlippedHorizontallyKey;
extern NSString *SKTImageIsFlippedVerticallyKey;
extern NSString *SKTImageFilePathKey;
extern NSString *SKTImageContentsKey;

// Represented in SVG as a url:data://;base64 of a PNG or JPEG for pasted images. otherwise, uses the filePath script command.
@interface SKTImage : SKTGraphic
/* This class is KVC and KVO compliant for these keys:

 "flippedHorizontally" and "flippedVertically" (boolean NSNumbers; read-only) - Whether or not the image is flipped relative to its natural orientation.

 "filePath" (an NSString containing a path to an image file; write-only) - the scriptable property that can specified as an alias in the record passed as the "with properties" parameter of a "make" command, so you can create images via AppleScript.

 In FloorSketch "flippedHorizontally" and "flippedVertically" are two more of the properties that SKTDocument observes so it can register undo actions when they change. Also, "imageFilePath" is scriptable.

 */

// Initialize, given the image to be presented and the location on which it should be centered.
- (instancetype)initWithPosition:(NSPoint)position contents:(NSImage *)contents;

@end
