/*
 File: SKTWindowController.h
 Abstract: A window controller to manage display of a FloorSketch window.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import <Cocoa/Cocoa.h>

@class SKTGrid;

@interface SKTWindowController : NSWindowController

/* This class is KVC and KVO compliant for this key:

 "graphicsController" (an NSArrayController; read-only) - The controller that manages the selection for the graphic view in the controlled window.

 "grid" (an SKTGrid; read-only) - An instance of SKTGrid.

 "zoomFactor" (a floating point NSNumber; read-write) - The zoom factor for the graphic view, following the meaning established by SKTZoomingScrollView's bindable "factor" property.

 In FloorSketch:

 Each SKTGraphicView's graphics and selection indexes properties are bound to the arranged objects and selection indexes properties of the containing SKTWindowController's graphics controller.

 Each SKTGraphicView's grid property is bound to the grid property of the SKTWindowController that contains it.

 Each SKTZoomingScrollView's factor property is bound to the zoom factor property of the SKTWindowController that contains it.

 Various properties of the controls of the graphics inspector are bound to properties of the selection of the graphics controller of the main window's SKTWindowController.

 Various properties of the controls of the grid inspector are bound to properties of the grid of the main window's SKTWindowController.

 Grids and zoom factors are owned by window controllers instead of the views that use them; in the future we may want to make the same grid and zoom factor apply to multiple views, or make the grid parameters and zoom factor into stored per-document preferences.

 */
@property (nonatomic) CGFloat zoomFactor;
@property (nonatomic) BOOL rulersVisible;
@property (nonatomic) SKTGrid *grid;


// An action that will create a sibling window for the same document.
- (IBAction)newDocumentWindow:(id)sender;

// Actions in the Grid menu.
- (IBAction)toggleGridConstraining:(id)sender;
- (IBAction)toggleGridShowing:(id)sender;

@end
