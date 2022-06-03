/*
 File: NSColor_SKTScripting.m
 Abstract: Scripting support for colors.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import <Cocoa/Cocoa.h>


// The Apple event descriptor <-> Objective-C object conversion methods for the "RGB color" value type declared in FloorSketch.sdef. Cocoa Scripting starts with the type name, condenses it by capitalizing the first letter of each word and removing the spaces, and uses the result to find a class method whose name matches the pattern +scripting <CondensedTypeName> WithDescriptor: and an instance method whose name matches the pattern -scripting <CondensedTypeName> Descriptor.
@implementation NSColor(SKTScripting)


// We're expected to handle everything that can be coerced to RGB colors, not just RGB colors.
+ (NSColor *)scriptingRGBColorWithDescriptor:(NSAppleEventDescriptor *)inDescriptor {
  NSColor *color = nil;
  NSAppleEventDescriptor *rgbColorDescriptor = [inDescriptor coerceToDescriptorType:typeRGBColor];
  if (rgbColorDescriptor) {

    // RGBColors contain 16-bit red, green, and blue components. Don't trust structures found in Apple event descriptors though.
    NSData *descriptorData = [rgbColorDescriptor data];
    if ([descriptorData length] == sizeof(RGBColor)) {
      const RGBColor *qdColor = (const RGBColor *)[descriptorData bytes];
      color = [NSColor colorWithCalibratedRed:((CGFloat)qdColor->red / 65535.0f) green:((CGFloat)qdColor->green / 65535.0f) blue:((CGFloat)qdColor->blue / 65535.0f) alpha:1.0];
    }

  }
  return color;

}


// RGBColors contain 16-bit red, green, and blue components.
- (NSAppleEventDescriptor *)scriptingRGBColorDescriptor {
  NSColor *colorAsCalibratedRGB = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  RGBColor qdColor;
  qdColor.red = (unsigned short)([colorAsCalibratedRGB redComponent] * 65535.0f);
  qdColor.green = (unsigned short)([colorAsCalibratedRGB greenComponent] * 65535.0f);
  qdColor.blue = (unsigned short)([colorAsCalibratedRGB blueComponent] * 65535.0f);
  return [NSAppleEventDescriptor descriptorWithDescriptorType:typeRGBColor bytes:&qdColor length:sizeof(RGBColor)];

}


@end
