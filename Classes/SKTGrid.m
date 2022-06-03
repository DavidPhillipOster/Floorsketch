/*
 File: SKTGrid.m
 Abstract: An object to represent a grid drawn on a FloorSketch canvas.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTGrid.h"


// A string constant declared in the header. We haven't bother declaring string constants for the other keys mentioned in the header yet because no one would be using them. Those keys are all typed directly into Interface Builder's bindings inspector.
NSString *const SKTGridAnyKey = @"any";


// The number of seconds that we wait after temporarily showing the grid before we hide it again. This number has never been reviewed by an actual user interface designer, but it seems nice to at least one engineer at Apple.
static NSTimeInterval SKTGridTemporaryShowingTime = 1.0;

@interface SKTGrid() {
  // The values underlying the key-value coding (KVC) and observing (KVO) compliance described below. There isn't a full complement of corresponding getter or setter methods. KVC's direct instance variable access, KVO's autonotifying, and KVO's property dependency mechanism make them unnecessary. If in the future we decide that we need to do more complicated things when these values are gotten or set we can add getter and setter methods then, and no bound object will know the difference (so don't let me hear any more guff about direct ivar access "breaking encapsulation").



  // Sometimes we temporarily show the grid to provide feedback for user changes to the grid spacing. When we do that we use a timer to turn it off again.
  NSTimer *_hidingTimer;
}

@end

@implementation SKTGrid
@synthesize alwaysShown = _alwaysShown;
@synthesize constraining = _constraining;

// An override of the superclass' designated initializer.
- (instancetype)init {
  self = [super init];
  if (self) {
    // Establish reasonable defaults. 36 points is a half of an inch, which is a reasonable default.
    _color = [NSColor lightGrayColor];
    _spacing = 36.0f;
  }
  return self;
}


- (void)dealloc {
  // If we've set a timer to hide the grid invalidate it so it doesn't send a message to this object's zombie.
  [_hidingTimer invalidate];
}


#pragma mark - Private KVC and KVO-Compliance for Public Properties


// Specify that a KVO-compliant change for any of this class' non-derived properties should result in a KVO change notification for the "any" virtual property. Views that want to use this grid can observe "any" for notification of the need to redraw the grid.
+ (NSSet *)keyPathsForValuesAffectingAny {
  return [NSSet setWithObjects:@"color", @"spacing", @"alwaysShown", @"constraining", nil];
}


- (void)stopShowingGridForTimer:(NSTimer *)timer {

  // The timer is now invalid and will be releasing itself.
  _hidingTimer = nil;

  // Tell observing views to redraw. By the way, it is virtually always a mistake to put willChange/didChange invocations together with nothing in between. Doing so can result in bugs that are hard to track down. You should always invoke -willChangeValueForKey:theKey before the result of -valueForKey:theKey would change, and then invoke -didChangeValueForKey:theKey after the result of -valueForKey:theKey would have changed. We can get away with this here because there is no value for the "any" key.
  [self willChangeValueForKey:SKTGridAnyKey];
  [self didChangeValueForKey:SKTGridAnyKey];

}


- (void)setSpacing:(CGFloat)spacing {

  // Weed out redundant invocations.
  if (spacing != _spacing) {
    _spacing = spacing;

    // If the grid is drawable, make sure the user gets visual feedback of the change. We don't have to do anything special if the grid is being shown right now.  Observers of "any" will get notified of this change because of what we did in +initialize. They're expected to invoke -drawRect:inView:.
    if (_spacing > 0 && ! _alwaysShown) {

      // Are we already showing the grid temporarily?
      if (_hidingTimer) {

        // Yes, and now the user's changed the grid spacing again, so put off the hiding of the grid.
        [_hidingTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:SKTGridTemporaryShowingTime]];

      } else {

        // No, so show it the next time -drawRect:inView: is invoked, and then hide it again in one second.
        _hidingTimer = [NSTimer scheduledTimerWithTimeInterval:SKTGridTemporaryShowingTime target:self selector:@selector(stopShowingGridForTimer:) userInfo:nil repeats:NO];

        // Don't bother with a separate _showsGridTemporarily instance variable. -drawRect: can just check to see if _hidingTimer is non-nil.

      }

    }

  }

}


+ (NSSet *)keyPathsForValuesAffectingCanSetColor {
  return [NSSet setWithObjects:@"alwaysShown", @"usable", nil];
}

// Don't let the user change the color of the grid when that would be useless.
- (BOOL)canSetColor {
  return _alwaysShown && [self isUsable];
}


+ (NSSet *)keyPathsForValuesAffectingCanSetSpacing {
  return [NSSet setWithObjects:@"alwaysShown", @"constraining", nil];
}

- (BOOL)canSetSpacing {
  // Don't let the user change the spacing of the grid when that would be useless.
  return _alwaysShown || _constraining;

}


#pragma mark - Public Methods


// Boilerplate.
- (BOOL)isAlwaysShown {
  return _alwaysShown;
}

- (BOOL)isConstraining {
  return _constraining;
}

- (void)setConstraining:(BOOL)isConstraining {
  _constraining = isConstraining;
}


+ (NSSet *)keyPathsForValuesAffectingUsable {
  return [NSSet setWithObject:@"spacing"];
}
- (BOOL)isUsable {

  // The grid isn't usable if the spacing is set to zero. The header comments explain why we don't validate away zero spacing.
  return _spacing > 0;

}


- (void)setAlwaysShown:(BOOL)isAlwaysShown {

  // Weed out redundant invocations.
  if (isAlwaysShown != _alwaysShown) {
    _alwaysShown = isAlwaysShown;

    // If we're temporarily showing the grid then there's a timer that's going to hide it. If we're supposed to show the grid right now then we don't want the timer to undo that. If we're supposed to hide the grid right now then the hiding that the timer would do is redundant.
    if (_hidingTimer) {
      [_hidingTimer invalidate];
      _hidingTimer = nil;
    }

  }

}

// The grid might not be usable right now, or constraining might be turned off.
- (NSPoint)constrainedPoint:(NSPoint)point {
  if ([self isUsable] && _constraining) {
    point.x = floor((point.x / _spacing) + 0.5) * _spacing;
    point.y = floor((point.y / _spacing) + 0.5) * _spacing;
  }
  return point;
}


// You can invoke alignedRect: any time the spacing is valid.
- (BOOL)canAlign {
  return [self isUsable];
}


- (NSRect)alignedRect:(NSRect)rect {
  // Aligning is done even when constraining is not.
  NSPoint upperRight = NSMakePoint(NSMaxX(rect), NSMaxY(rect));
  rect.origin.x = floor((rect.origin.x / _spacing) + 0.5) * _spacing;
  rect.origin.y = floor((rect.origin.y / _spacing) + 0.5) * _spacing;
  upperRight.x = floor((upperRight.x / _spacing) + 0.5) * _spacing;
  upperRight.y = floor((upperRight.y / _spacing) + 0.5) * _spacing;
  rect.size.width = upperRight.x - rect.origin.x;
  rect.size.height = upperRight.y - rect.origin.y;
  return rect;
}


- (void)drawRect:(NSRect)rect inView:(NSView *)view {

  // The grid might not be usable right now. It might be shown, but only temporarily.
  if ([self isUsable] && (_alwaysShown || _hidingTimer)) {

    // Figure out a big bezier path that corresponds to the entire grid. It will consist of the vertical lines and then the horizontal lines.
    NSBezierPath *gridPath = [NSBezierPath bezierPath];
    NSInteger lastVerticalLineNumber = floor(NSMaxX(rect) / _spacing);
    for (NSInteger lineNumber = ceil(NSMinX(rect) / _spacing); lineNumber <= lastVerticalLineNumber; lineNumber++) {
      [gridPath moveToPoint:NSMakePoint((lineNumber * _spacing), NSMinY(rect))];
      [gridPath lineToPoint:NSMakePoint((lineNumber * _spacing), NSMaxY(rect))];
    }
    NSInteger lastHorizontalLineNumber = floor(NSMaxY(rect) / _spacing);
    for (NSInteger lineNumber = ceil(NSMinY(rect) / _spacing); lineNumber <= lastHorizontalLineNumber; lineNumber++) {
      [gridPath moveToPoint:NSMakePoint(NSMinX(rect), (lineNumber * _spacing))];
      [gridPath lineToPoint:NSMakePoint(NSMaxX(rect), (lineNumber * _spacing))];
    }

    // Draw the grid as one-pixel-wide lines of a specific color.
    [_color set];
    [gridPath setLineWidth:0.0];
    [gridPath stroke];

  }

}


@end
