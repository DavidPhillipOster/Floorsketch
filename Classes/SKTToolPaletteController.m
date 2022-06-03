/*
 File: SKTToolPaletteController.m
 Abstract: A controller to manage the tools palette.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTToolPaletteController.h"
#import "SKTEllipse.h"
#import "SKTLine.h"
#import "SKTPath.h"
#import "SKTPoly.h"
#import "SKTRectangle.h"
#import "SKTText.h"

enum {
  SKTArrowToolRow = 0,
  SKTNodeArrowToolRow,
  SKTPolygonToolRow,
  SKTRectToolRow,
  SKTLineToolRow,
  SKTTextToolRow,
};

NSString *SKTSelectedToolDidChangeNotification = @"SKTSelectedToolDidChange";

@interface SKTToolPaletteController ()
@property IBOutlet NSMatrix *toolButtons;
@end

@implementation SKTToolPaletteController

+ (SKTToolPaletteController*)sharedToolPaletteController {
  static SKTToolPaletteController *sharedToolPaletteController = nil;

  if (!sharedToolPaletteController) {
    sharedToolPaletteController = [[SKTToolPaletteController allocWithZone:NULL] init];
  }

  return sharedToolPaletteController;
}

- (instancetype)init {
  self = [self initWithWindowNibName:@"ToolPalette"];
  if (self) {
    [self setWindowFrameAutosaveName:@"ToolPalette"];
  }
  return self;
}

- (void)windowDidLoad {
  NSArray *cells = [_toolButtons cells];
  NSUInteger i, c = [cells count];

  [super windowDidLoad];

  for (i = 0; i < c; i++) {
    [cells[i] setRefusesFirstResponder:YES];
  }
  [(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];

  // Interface Builder (IB 2.4.1, anyway) won't let us set the window's width to less than 59 pixels, but we really only need 42.
  [[self window] setContentSize:[_toolButtons frame].size];
}

- (IBAction)selectToolAction:(id)sender {
//  NSMatrix *matrix = (NSMatrix *)sender;
//  if ([matrix respondsToSelector:@selector(cellAtRow:column:)]) {
//    NSInteger row = [matrix selectedRow];
//    for (NSInteger y = 0; y < matrix.numberOfRows; ++y) {
//        NSButtonCell *cell = [matrix cellAtRow:y column:0];
//        [cell setState:row == y ? NSOnState : NSOffState];
//    }
//  }
  [[NSNotificationCenter defaultCenter] postNotificationName:SKTSelectedToolDidChangeNotification object:self];
}

- (Class)currentGraphicClass {
  NSInteger row = [_toolButtons selectedRow];
  Class theClass = nil;
  switch (row) {
    case SKTPolygonToolRow: theClass = [SKTPoly class];       break;
    case SKTRectToolRow:    theClass = [SKTRectangle class];  break;
    case SKTLineToolRow:    theClass = [SKTLine class];       break;
    case SKTTextToolRow:    theClass = [SKTText class];       break;
    default:
      break;
  }
  return theClass;
}

- (SKTSelectionStyle)currentSelectionStyle {
  switch ([_toolButtons selectedRow]) {
    case SKTNodeArrowToolRow:   return SKTSelectionStyleNode;
    default:
    case SKTSelectionStyleObject: return SKTSelectionStyleObject;
  }
}

- (NSCursor *)nodeSelectionCursor {
  static NSCursor *nodeSelectionCursor = nil;
  if (nil == nodeSelectionCursor) {
    NSImage *arrowNodeImage = [NSImage imageNamed:@"ArrowNode"];
    nodeSelectionCursor = [[NSCursor alloc] initWithImage:arrowNodeImage
                                                  hotSpot:NSMakePoint(11, 11)];
  }
  return nodeSelectionCursor;
}

- (NSCursor *)currentSelectionCursor {
    switch ([self currentSelectionStyle]) {
    case SKTSelectionStyleNode: return [self nodeSelectionCursor];
    case SKTSelectionStyleObject: return [NSCursor arrowCursor];
    }
}

- (void)selectNodeArrowTool {
  [_toolButtons selectCellAtRow:SKTArrowToolRow column:SKTNodeArrowToolRow];
  [[NSNotificationCenter defaultCenter] postNotificationName:SKTSelectedToolDidChangeNotification object:self];
}

- (void)selectArrowTool {
  [_toolButtons selectCellAtRow:SKTArrowToolRow column:SKTArrowToolRow];
  [[NSNotificationCenter defaultCenter] postNotificationName:SKTSelectedToolDidChangeNotification object:self];
}

@end
