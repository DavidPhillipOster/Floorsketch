/*
 File: SKTRectangle.m
 Abstract: A graphic object to represent a rectangle.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTRectangle.h"
#import "SKTPoly.h"

@implementation SKTRectangle

- (BOOL)canOpenPolygon {
  return YES;
}

- (BOOL)canClosePolygon {
  return NO;
}

- (SKTGraphic *)graphicByOpening {
  NSMutableDictionary *properties = [[self properties] mutableCopy];
  CGRect r = [self bounds];
  NSString *s = [NSString stringWithFormat:@"%.5g,%.5g %.5g,%.5g %.5g,%.5g %.5g,%.5g",
    r.origin.x + r.size.width, r.origin.y + r.size.height,
    r.origin.x + r.size.width, r.origin.y,
    r.origin.x,r.origin.y,
    r.origin.x, r.origin.y + r.size.height];
  properties[SKTPolyPoints] = s;
  SKTPoly *poly = [[SKTPoly alloc] initWithProperties:properties];
  return poly;
}


- (NSBezierPath *)bezierPathForDrawing {
  NSBezierPath *path = [NSBezierPath bezierPathWithRect:[self bounds]];
  [path setLineWidth:[self strokeWidth]];
  return path;
}

- (NSString *)asSVGString {
  return [self asSVGStringVerb:@"rect"];
}

- (NSString *)svgAttributesString {
  return [NSString stringWithFormat:@"x=\"%.5g\" y=\"%.5g\" width=\"%.5g\" height=\"%.5g\" %@",
    self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height,
    [super svgAttributesString]];
}

@end
