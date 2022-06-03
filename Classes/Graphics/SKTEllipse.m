/*
 File: SKTEllipse.m
 Abstract: A graphic object to represent a ellipse.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTEllipse.h"

@implementation SKTEllipse

- (NSBezierPath *)bezierPathForDrawing {
  NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:[self bounds]];
  [path setLineWidth:[self strokeWidth]];
  return path;
}

- (BOOL)isContentsUnderPoint:(NSPoint)point {
  return [[self bezierPathForDrawing] containsPoint:point];
}


- (NSString *)asSVGString {
  return [self asSVGStringVerb:@"ellipse"];
}

- (NSString *)svgAttributesString {
  return [NSString stringWithFormat:@"cx=\"%.5g\" cy=\"%.5g\" rx=\"%.5g\" ry=\"%.5g\" %@",
    self.bounds.origin.x + self.bounds.size.width/2, self.bounds.origin.y + self.bounds.size.height/2,
    self.bounds.size.width/2, self.bounds.size.height/2,
    [super svgAttributesString]];
}

@end
