/*
 File: SKTToolPaletteController.h
 Abstract: A controller to manage the tools palette.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import <Cocoa/Cocoa.h>

typedef enum {
  SKTSelectionStyleObject,
  SKTSelectionStyleNode,
} SKTSelectionStyle;

@interface SKTToolPaletteController : NSWindowController
@property (NS_NONATOMIC_IOSONLY, readonly) Class currentGraphicClass;
// If the class is nil, then check the currentSelectionStyle.
@property (NS_NONATOMIC_IOSONLY, readonly) SKTSelectionStyle currentSelectionStyle;
@property (NS_NONATOMIC_IOSONLY, readonly) NSCursor *currentSelectionCursor;


+ (SKTToolPaletteController*)sharedToolPaletteController;

- (IBAction)selectToolAction:(id)sender;

- (void)selectArrowTool;

- (void)selectNodeArrowTool;

@end

extern NSString *SKTSelectedToolDidChangeNotification;
