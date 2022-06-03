/*
 File: SKTZoomingScrollView.h
 Abstract: A controller to manage zooming of a FloorSketch graphics view.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import <Cocoa/Cocoa.h>

// The name of the binding supported by this class, in addition to the ones whose support is inherited from NSScrollView.
extern NSString *SKTZoomingScrollViewFactor;

@interface SKTZoomingScrollView : NSScrollView
  // The current zoom factor. This instance variable isn't actually read by any SKTZoomingScrollView code and wouldn't be necessary if it weren't for an oddity in the default implementation of key-value binding (KVB): -[NSObject(NSKeyValueBindingCreation) bind:toObject:withKeyPath:options:] sends the receiver a -valueForKeyPath: message, even though the returned value is typically not interesting. With this here key-value coding (KVC) direct instance variable access makes -valueForKeyPath: happy.
// but it will be saved and restored in the document.
@property(nonatomic) CGFloat factor;

- (IBAction)zoomActualSize:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;

@end
