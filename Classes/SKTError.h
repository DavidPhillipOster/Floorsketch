/*
 File: SKTError.h
 Abstract: Custom error domain and constants for FloorSketch, and a function to create a new error object.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import <Cocoa/Cocoa.h>

// FloorSketch establishes its own error domain, and some errors in that domain.
extern NSString *SKTErrorDomain;
enum {
  SKTUnknownFileReadError = 1,
  SKTUnknownPasteboardReadError = 2,
  SKTWriteCouldntMakeTIFFError = 3,
  SKTWriteCouldntMakePNGError = 4,
};

// Given one of the error codes declared above, return an NSError whose user info is set up to match.
NSError *SKTErrorWithCode(NSInteger code);
