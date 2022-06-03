/*
 File: SKTGraphicView.h
 Abstract: The view to display FloorSketch graphics objects.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import <Cocoa/Cocoa.h>

@class SKTGraphic, SKTGrid;

// The names of the bindings supported by this class, in addition to the ones whose support is inherited from NSView.
extern NSString *const SKTGraphicViewGraphicsBindingName;
extern NSString *const SKTGraphicViewSelectionIndexesBindingName;
extern NSString *const SKTGraphicViewGridBindingName;

@interface SKTGraphicView : NSView
@property (NS_NONATOMIC_IOSONLY) BOOL rulersVisible;
@property(readonly) CGFloat handleWidth;

// Action methods that are unique to SKTGraphicView, or at least are not declared by NSResponder. SKTGraphicView implements other action methods, but they're all declared by NSResponder and there's not much reason to redeclare them here. We use -showOrHideRulers: instead of -toggleRuler: because we don't want to cause accidental invocation of -[NSTextView toggleRuler:], which doesn't quite work when the text view has been added to a view that already has rulers shown in it, a situation that can arise in FloorSketch.
- (IBAction)alignBottomEdges:(id)sender;
- (IBAction)alignHorizontalCenters:(id)sender;
- (IBAction)alignLeftEdges:(id)sender;
- (IBAction)alignRightEdges:(id)sender;
- (IBAction)alignTopEdges:(id)sender;
- (IBAction)alignVerticalCenters:(id)sender;
- (IBAction)alignWithGrid:(id)sender;
- (IBAction)bringToFront:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)cut:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)deselectAll:(id)sender;
- (IBAction)group:(id)sender;
- (IBAction)lock:(id)sender;
- (IBAction)makeNaturalSize:(id)sender;
- (IBAction)makeSameHeight:(id)sender;
- (IBAction)makeSameWidth:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)sendToBack:(id)sender;
- (IBAction)showOrHideRulers:(id)sender;
- (IBAction)ungroup:(id)sender;
- (IBAction)unlock:(id)sender;

@end
/*
 <codex>
 <abstract></abstract>
 </codex>
 */

