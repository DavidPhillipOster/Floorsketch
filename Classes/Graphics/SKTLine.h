/*
 File: SKTLine.h
 Abstract: A graphic object to represent a line.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTGraphic.h"

// The keys described down below.
extern NSString *SKTLineBeginPointKey;
extern NSString *SKTLineEndPointKey;

@interface SKTLine : SKTGraphic
/* This class is KVC and KVO compliant for these keys:

 "beginPoint" and "endPoint" (NSPoint-containing NSValues; read-only) - The two points that define the line segment.

 In FloorSketch "beginPoint" and "endPoint" are two more of the properties that SKTDocument observes so it can register undo actions when they change.

 Notice that we don't guarantee KVC or KVO compliance for "pointsRight" and "pointsDown." Those aren't just private instance variables, they're private properties, concepts that no code outside of SKTLine should care about.

 */

@end
