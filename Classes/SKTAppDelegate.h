/*
     File: SKTAppDelegate.h
 Abstract: The application delegate: This object manages display of the preferences panel, graphics inspector, and tools palette.
  Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import <Cocoa/Cocoa.h>

@interface SKTAppDelegate : NSObject
// Actions that show or hide various panels. In FloorSketch each is the target of a main menu item.
- (IBAction)showPreferencesPanel:(id)sender;
- (IBAction)showOrHideGraphicsInspector:(id)sender;
- (IBAction)showOrHideGridInspector:(id)sender;
- (IBAction)showOrHideToolPalette:(id)sender;

// The "Selection Tool" action in Sketch's Tools menu.
- (IBAction)chooseSelectionTool:(id)sender;

@end

