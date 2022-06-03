/*  SKTVertex.m
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTVertex.h"

#import "SKTPoly.h"

static NSString *const kXPosition = @"xPosition";
static NSString *const kYPosition = @"yPosition";
static NSString *const kKind = @"kind";

@implementation SKTVertex

#pragma mark - Undo

- (NSSet *)keysForValuesToObserveForUndo {
  return [NSSet setWithObjects:kXPosition, kYPosition, kKind, nil];
}

+ (NSString *)presentablePropertyNameForKey:(NSString *)key {
  static NSDictionary *presentablePropertyNamesByKey = nil;
  if (!presentablePropertyNamesByKey) {
    presentablePropertyNamesByKey = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
      NSLocalizedStringFromTable(@"kind", @"UndoStrings", @"Action noun part for yPosition."), kKind,
      NSLocalizedStringFromTable(@"x", @"UndoStrings", @"Action noun part for xPosition."), kXPosition,
      NSLocalizedStringFromTable(@"y", @"UndoStrings", @"Action noun part for yPosition."), kYPosition,
      nil];
  }
  return presentablePropertyNamesByKey[key];
}

- (void)setXPosition:(CGFloat)xPosition {
  if (_xPosition != xPosition) {
    _xPosition = xPosition;
    if ([_scriptingContainer respondsToSelector:@selector(replacePtAtIndex:withPt:)]) {
      SKTPoly *poly = (SKTPoly *)_scriptingContainer;
      CGPoint p = [poly ptAtIndex:_index];
      p.x = _xPosition;
      [poly replacePtAtIndex:_index withPt:p];
    }
  }
}

- (void)setYPosition:(CGFloat)yPosition {
  if (_yPosition != yPosition) {
    _yPosition = yPosition;
    if ([_scriptingContainer respondsToSelector:@selector(replacePtAtIndex:withPt:)]) {
      SKTPoly *poly = (SKTPoly *)_scriptingContainer;
      CGPoint p = [poly ptAtIndex:_index];
      p.y = _yPosition;
      [poly replacePtAtIndex:_index withPt:p];
    }
  }
}

- (void)setKind:(SKTVertexKind)kind {
  if (_kind != kind) {
    _kind = kind;
    NSLog(@"setKind: More here! TODO");
  }
}

#pragma mark - Scripting

// Conformance to the NSObject(NSScriptObjectSpecifiers) informal protocol.
- (NSScriptObjectSpecifier *)objectSpecifier {

  // This object can't create an object specifier for itself, so ask its scriptable container to do it.
  NSScriptObjectSpecifier *objectSpecifier = [_scriptingContainer objectSpecifierForVertex:self];
  if (!objectSpecifier) {
    [NSException raise:NSInternalInconsistencyException format:@"A scriptable vertex has no scriptable container, or one that doesn't implement -objectSpecifierForVertex: correctly."];
  }
  return objectSpecifier;
}

@end
