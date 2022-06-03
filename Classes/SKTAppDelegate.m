/*
 File: SKTAppDelegate.m
 Abstract: The application delegate: This object manages display of the preferences panel, graphics inspector, and tools palette.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTAppDelegate.h"
#import "SKTToolPaletteController.h"


// Keys that are used in Sketch's user defaults.
static NSString *SKTAppAutosavesPreferenceKey = @"autosaves";
static NSString *SKTAppAutosavingDelayPreferenceKey = @"autosavingDelay";


#pragma mark - NSWindowController Conveniences


@interface NSWindowController(SKTConvenience)
@property (NS_NONATOMIC_IOSONLY, getter = isWindowShown, readonly) BOOL windowShown;
- (void)showOrHideWindow;
@end
@implementation NSWindowController(SKTConvenience)


- (BOOL)isWindowShown {

  // Simple.
  return [[self window] isVisible];

}


- (void)showOrHideWindow {

  // Simple.
  NSWindow *window = [self window];
  if ([window isVisible]) {
    [window orderOut:self];
  } else {
    [self showWindow:self];
  }

}


@end

@interface SKTAppDelegate() {
  NSWindowController *_preferencesPanelController;
  NSWindowController *_graphicsInspectorController;
  NSWindowController *_gridInspectorController;

  // Values that come from the user defaults, via the key-value bindings that we set up in -applicationWillFinishLaunching:. It might be a little more natural to put this functionality in a subclass of NSDocumentController, but it doesn't make a big difference. At the time these were added FloorSketch had no subclass of SKTDocumentController. Now that it has one it's not worthwhile to move this stuff.
  BOOL _autosaves;
  NSTimeInterval _autosavingDelay;

}
@end


@implementation SKTAppDelegate


#pragma mark - Launching


// Conformance to the NSObject(NSApplicationNotifications) informal protocol.
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // The tool palette should always show up right away.
  [self showOrHideToolPalette:self];
}


#pragma mark - Preferences


// Conformance to the NSObject(NSApplicationNotifications) informal protocol.
- (void)applicationWillFinishLaunching:(NSNotification *)notification {

  // Set up the default values of our autosaving preferences very early, before there's any chance of a binding using them. The default is for autosaving to be off, but 60 seconds if the user turns it on.
  NSUserDefaultsController *userDefaultsController = [NSUserDefaultsController sharedUserDefaultsController];
  [userDefaultsController setInitialValues:@{SKTAppAutosavesPreferenceKey: @NO, SKTAppAutosavingDelayPreferenceKey: @60.0}];

  // Bind this object's "autosaves" and "autosavingDelay" properties to the user defaults of the same name. We don't bother with ivars for these values. This is just the quick way to get our -setAutosaves: and -setAutosavingDelay: methods invoked.
  [self bind:SKTAppAutosavesPreferenceKey toObject:userDefaultsController withKeyPath:[@"values." stringByAppendingString:SKTAppAutosavesPreferenceKey] options:nil];
  [self bind:SKTAppAutosavingDelayPreferenceKey toObject:userDefaultsController withKeyPath:[@"values." stringByAppendingString:SKTAppAutosavingDelayPreferenceKey] options:nil];

}


- (void)setAutosaves:(BOOL)autosaves {

  // The user has toggled the "autosave documents" checkbox in the preferences panel.
  if (autosaves) {

    // Get the autosaving delay and set it in the NSDocumentController.
    [[NSDocumentController sharedDocumentController] setAutosavingDelay:_autosavingDelay];

  } else {

    // Set a zero autosaving delay in the NSDocumentController. This tells it to turn off autosaving.
    [[NSDocumentController sharedDocumentController] setAutosavingDelay:0.0];

  }
  _autosaves = autosaves;

}


- (void)setAutosavingDelay:(NSTimeInterval)autosaveDelay {

  // Is autosaving even turned on right now?
  if (_autosaves) {

    // Set the new autosaving delay in the document controller, but only if autosaving is being done right now.
    [[NSDocumentController sharedDocumentController] setAutosavingDelay:autosaveDelay];

  }
  _autosavingDelay = autosaveDelay;

}


- (IBAction)showPreferencesPanel:(id)sender {

  // We always show the same preferences panel. Its controller doesn't get deallocated when the user closes it.
  if (!_preferencesPanelController) {
    _preferencesPanelController = [[NSWindowController alloc] initWithWindowNibName:@"Preferences"];

    // Make the panel appear in a good default location.
    [[_preferencesPanelController window] center];

  }
  [_preferencesPanelController showWindow:sender];

}


#pragma mark - Other Actions


- (IBAction)showOrHideGraphicsInspector:(id)sender {

  // We always show the same inspector panel. Its controller doesn't get deallocated when the user closes it.
  if (!_graphicsInspectorController) {
    _graphicsInspectorController = [[NSWindowController alloc] initWithWindowNibName:@"Inspector"];

    // Make the panel appear in the same place when the user quits and relaunches the application.
    [_graphicsInspectorController setShouldCascadeWindows:NO];
    [_graphicsInspectorController setWindowFrameAutosaveName:@"Inspector"];

  }
  [_graphicsInspectorController showOrHideWindow];

}


- (IBAction)showOrHideGridInspector:(id)sender {

  // We always show the same grid inspector panel. Its controller doesn't get deallocated when the user closes it.
  if (!_gridInspectorController) {
    _gridInspectorController = [[NSWindowController alloc] initWithWindowNibName:@"GridPanel"];

    // Make the panel appear in the same place when the user quits and relaunches the application.
    [_graphicsInspectorController setShouldCascadeWindows:NO];
    [_gridInspectorController setWindowFrameAutosaveName:@"Grid"];

  }
  [_gridInspectorController showOrHideWindow];

}


- (IBAction)showOrHideToolPalette:(id)sender {

  // We always show the same tool palette panel. Its controller doesn't get deallocated when the user closes it.
  [[SKTToolPaletteController sharedToolPaletteController] showOrHideWindow];

}


- (IBAction)chooseSelectionTool:(id)sender {

  // Simple.
  [[SKTToolPaletteController sharedToolPaletteController] selectArrowTool];

}

- (IBAction)chooseNodeSelectionTool:(id)sender {

  // Simple.
  [[SKTToolPaletteController sharedToolPaletteController] selectNodeArrowTool];

}



// Conformance to the NSObject(NSMenuValidation) informal protocol.
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {

  // A few menu item's names change between starting with "Show" and "Hide."
  SEL action = [menuItem action];
  if (action == @selector(showOrHideGraphicsInspector:)) {
    [menuItem setTitle:([_graphicsInspectorController isWindowShown] ? NSLocalizedStringFromTable(@"Hide Inspector", @"MenuItems", @"A main menu item title.") : NSLocalizedStringFromTable(@"Show Inspector", @"MenuItems", @"A main menu item title."))];
  } else if (action == @selector(showOrHideGridInspector:)) {
    [menuItem setTitle:([_gridInspectorController isWindowShown] ? NSLocalizedStringFromTable(@"Hide Grid Options", @"MenuItems", @"A main menu item title.") : NSLocalizedStringFromTable(@"Show Grid Options", @"MenuItems", @"A main menu item title."))];
  } else if (action == @selector(showOrHideToolPalette:)) {
    [menuItem setTitle:([[SKTToolPaletteController sharedToolPaletteController] isWindowShown] ? NSLocalizedStringFromTable(@"Hide Tools", @"MenuItems", @"A main menu item title.") : NSLocalizedStringFromTable(@"Show Tools", @"MenuItems", @"A main menu item title."))];
  }
  return YES;

}


@end
