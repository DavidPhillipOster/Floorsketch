/*  SKTGraphicsOwner.m
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTGraphicsOwner.h"

#import "NSArray_SKT.h"
#import "SKTGraphic.h"
#import "SKTGroup.h"
#import "SKTEllipse.h"
#import "SKTImage.h"
#import "SKTLine.h"
#import "SKTPath.h"
#import "SKTPoly.h"
#import "SKTRectangle.h"
#import "SKTText.h"

@implementation NSObject(SKTGraphicsOwner)


- (NSArray *)graphicsWithClass:(Class)theClass {
  return [[(id<SKTGraphicsOwner>)self graphics] arrayByFilteringWithClass:theClass];
}

- (NSArray *)ellipses {
  return [self graphicsWithClass:[SKTEllipse class]];
}

- (NSArray *)images {
  return [self graphicsWithClass:[SKTImage class]];
}

- (NSArray *)lines {
  return [self graphicsWithClass:[SKTLine class]];
}

- (NSArray *)groups {
  return [self graphicsWithClass:[SKTGroup class]];
}

- (NSArray *)paths {
  return [self graphicsWithClass:[SKTPath class]];
}

- (NSArray *)polygons {
  return [self graphicsWithClass:[SKTPoly class]];
}

- (NSArray *)rectangles {
  return [self graphicsWithClass:[SKTRectangle class]];
}

- (NSArray *)textAreas {
  return [self graphicsWithClass:[SKTText class]];
}

// The GraphicView overrides these GraphicOwner methods.
- (BOOL)isInSelectionSet:(NSUInteger)index {
  return NO;
}

// The GraphicView overrides these GraphicOwner methods.
- (BOOL)isBeingCreateOrEdited:(SKTGraphic *)graphic {
  return NO;
}

// GraphicView overrides this.
- (BOOL)isHidingHandles {
  return NO;
}

// GraphicView overrides this.
- (CGFloat)handleWidth {
  return 0;
}

// GraphicView overrides this.
- (CGRect)handleDrawingBoundsOfGraphic:(SKTGraphic *)graphic {
  CGRect result = [graphic drawingBounds];
  return result;
}

- (void)drawGraphics:(NSArray<SKTGraphic *> *)graphics view:(NSView *)view rect:(NSRect)rect {
  NSInteger graphicCount = [graphics count];
  for (NSInteger index = graphicCount - 1; index >= 0; index--) {
    SKTGraphic *graphic = graphics[index];
    NSRect graphicDrawingBounds = [self handleDrawingBoundsOfGraphic:graphic];
    if (NSIntersectsRect(rect, graphicDrawingBounds)) {
      NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
      [currentContext saveGraphicsState];
      [self drawGraphic:graphic view:view rect:rect index:index];
      [currentContext restoreGraphicsState];
    }
  }
}

- (void)drawGraphic:(SKTGraphic *)graphic
               view:(NSView *)view
               rect:(NSRect)rect
              index:(NSInteger)index {
  NSRect graphicDrawingBounds = [self handleDrawingBoundsOfGraphic:graphic];
  if (NSIntersectsRect(rect, graphicDrawingBounds)) {

    // Figure out whether or not to draw selection handles on the graphic. Selection handles are drawn for all selected objects except:
    // - While the selected objects are being moved.
    // - For the object actually being created or edited, if there is one.
    BOOL drawSelectionHandles = NO;
    BOOL isBeingCreateOrEdited = [self isBeingCreateOrEdited:graphic];
    if (![self isHidingHandles] && ! isBeingCreateOrEdited) {
      drawSelectionHandles = [self isInSelectionSet:index];
    }

    // Draw the graphic, possibly with selection handles.
    NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
    [currentContext saveGraphicsState];
    [NSBezierPath clipRect:rect];
    [graphic drawContentsInView:view rect:rect isBeingCreateOrEdited:isBeingCreateOrEdited];
    if (drawSelectionHandles) {
      [graphic drawHandlesInView:view];
    }
    [currentContext restoreGraphicsState];
  }
}


// Conformance to the NSObject(SKTGraphicScriptingContainer) informal protocol.
- (NSScriptObjectSpecifier *)objectSpecifierForGraphic:(SKTGraphic *)graphic {

  // Graphics don't have unique IDs or names, so just return an index specifier.
  NSScriptObjectSpecifier *graphicObjectSpecifier = nil;
  NSUInteger graphicIndex = [[(id<SKTGraphicsOwner>)self graphics] indexOfObjectIdenticalTo:graphic];
  if (graphicIndex != NSNotFound) {
    NSScriptObjectSpecifier *objectSpecifier = [self objectSpecifier];
    graphicObjectSpecifier = [[NSIndexSpecifier alloc] initWithContainerClassDescription:[objectSpecifier keyClassDescription] containerSpecifier:objectSpecifier key:@"graphics" index:graphicIndex];
  }
  return graphicObjectSpecifier;
}

- (void)insertGraphics:(NSArray *)graphics atIndexes:(NSIndexSet *)indexes {
  // Do the actual insertion. Instantiate the graphics array lazily.
  [[(id<SKTGraphicsOwner>)self graphics] insertObjects:graphics atIndexes:indexes];

  // For the purposes of scripting, every graphic has to point back to the document that contains it.
  [graphics makeObjectsPerformSelector:@selector(setScriptingContainer:) withObject:self];

  // Register an action that will undo the insertion.
  NSUndoManager *undoManager = [(id<SKTGraphicsOwner>)self undoManager];
  [undoManager registerUndoWithTarget:self selector:@selector(removeGraphicsAtIndexes:) object:indexes];

  // Record the inserted graphics so we can filter out observer notifications from them. This way we don't waste memory registering undo operations for changes that wouldn't have any effect because the graphics are going to be removed anyway. In FloorSketch this makes a difference when you create a graphic and then drag the mouse to set its initial size right away. Why don't we do this if undo registration is disabled? Because we don't want to add to this set during document reading. (See what -readFromData:ofType:error: does with the undo manager.) That would ruin the undoability of the first graphic editing you do after reading a document.
  if ([undoManager isUndoRegistrationEnabled]) {
    [(id<SKTGraphicsOwner>)self addObjectsFromArrayToUndoGroupInsertedGraphics:graphics];
  }

  // Start observing the just-inserted graphics so that, when they're changed, we can record undo operations.
  [(id<SKTGraphicsOwner>)self startObservingGraphics:graphics];

}


- (void)removeGraphicsAtIndexes:(NSIndexSet *)indexes {
  // Find out what graphics are being removed.
  NSArray *graphics = [[(id<SKTGraphicsOwner>)self graphics] objectsAtIndexes:indexes];

  // Stop observing the just-removed graphics to balance what was done in -insertGraphics:atIndexes:.
  [(id<SKTGraphicsOwner>)self stopObservingGraphics:graphics];

  // Register an action that will undo the removal. Do this before the actual removal so we don't have to worry about the releasing of the graphics that will be done.
  [[[(id<SKTGraphicsOwner>)self undoManager] prepareWithInvocationTarget:self] insertGraphics:graphics atIndexes:indexes];

  // For the purposes of scripting, every graphic had to point back to the document that contains it. Now they should stop that.
  [graphics makeObjectsPerformSelector:@selector(setScriptingContainer:) withObject:nil];

  // Do the actual removal.
  [[(id<SKTGraphicsOwner>)self graphics] removeObjectsAtIndexes:indexes];

}

// These are methods that wouldn't be here if this class weren't scriptable for relationships like "ellipses," "rectangles," etc. The first two methods are redundant with the -insertGraphics:atIndexes: and -removeGraphicsAtIndexes: methods up above, except they're a little more convenient for invoking in all of the code down below. They don't have KVO-compliant names (-insertObject:inGraphicsAtIndex: and -removeObjectFromGraphicsAtIndex:) on purpose. If they did then extra, incorrect, KVO autonotification would be done.


- (void)insertGraphic:(SKTGraphic *)graphic atIndex:(NSUInteger)index {

  // Just invoke the regular method up above.
  NSArray *graphics = @[graphic];
  NSIndexSet *indexes = [[NSIndexSet alloc] initWithIndex:index];
  [self insertGraphics:graphics atIndexes:indexes];
}

// Just invoke the regular method up above.
- (void)removeGraphicAtIndex:(NSUInteger)index {
  NSIndexSet *indexes = [[NSIndexSet alloc] initWithIndex:index];
  [self removeGraphicsAtIndexes:indexes];

}

- (void)addInGraphics:(SKTGraphic *)graphic {
  // Just a convenience for invoking by some of the methods down below.
  [self insertGraphic:graphic atIndex:[[(id<SKTGraphicsOwner>)self graphics] count]];
}

- (void)insertObject:(SKTGraphic *)graphic inRectanglesAtIndex:(NSUInteger)index {
  // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInRectangles:atIndex:3...
  NSArray *rects = [self rectangles];
  if (index == [rects count]) {
    [self addInGraphics:graphic];
  } else {
    NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
    NSInteger newIndex = [graphics indexOfObjectIdenticalTo:rects[index]];
    if (newIndex != NSNotFound) {
      [self insertGraphic:graphic atIndex:newIndex];
    } else {
      // Shouldn't happen.
      [NSException raise:NSRangeException format:@"Could not find the given rectangle in the graphics."];
    }
  }
}

- (void)removeObjectFromRectanglesAtIndex:(NSUInteger)index {
  NSArray *rects = [self rectangles];
  NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
  NSInteger newIndex = [graphics indexOfObjectIdenticalTo:rects[index]];
  if (newIndex != NSNotFound) {
    [self removeGraphicAtIndex:newIndex];
  } else {
    // Shouldn't happen.
    [NSException raise:NSRangeException format:@"Could not find the given rectangle in the graphics."];
  }
}

- (void)insertObject:(SKTGraphic *)graphic inEllipsesAtIndex:(NSUInteger)index {
  // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInEllipses:atIndex:3...
  NSArray *ellipses = [self ellipses];
  if (index == [ellipses count]) {
    [self addInGraphics:graphic];
  } else {
    NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
    NSInteger newIndex = [graphics indexOfObjectIdenticalTo:ellipses[index]];
    if (newIndex != NSNotFound) {
      [self insertGraphic:graphic atIndex:newIndex];
    } else {
      // Shouldn't happen.
      [NSException raise:NSRangeException format:@"Could not find the given ellipse in the graphics."];
    }
  }
}

- (void)removeObjectFromEllipsesAtIndex:(NSUInteger)index {
  NSArray *ellipses = [self ellipses];
  NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
  NSInteger newIndex = [graphics indexOfObjectIdenticalTo:ellipses[index]];
  if (newIndex != NSNotFound) {
    [self removeGraphicAtIndex:newIndex];
  } else {
    // Shouldn't happen.
    [NSException raise:NSRangeException format:@"Could not find the given ellipse in the graphics."];
  }
}

- (void)insertObject:(SKTGraphic *)graphic inLinesAtIndex:(NSUInteger)index {
  // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInLines:atIndex:3...
  NSArray *lines = [self lines];
  if (index == [lines count]) {
    [self addInGraphics:graphic];
  } else {
    NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
    NSInteger newIndex = [graphics indexOfObjectIdenticalTo:lines[index]];
    if (newIndex != NSNotFound) {
      [self insertGraphic:graphic atIndex:newIndex];
    } else {
      // Shouldn't happen.
      [NSException raise:NSRangeException format:@"Could not find the given line in the graphics."];
    }
  }
}

- (void)removeObjectFromLinesAtIndex:(NSUInteger)index {
  NSArray *lines = [self lines];
  NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
  NSInteger newIndex = [graphics indexOfObjectIdenticalTo:lines[index]];
  if (newIndex != NSNotFound) {
    [self removeGraphicAtIndex:newIndex];
  } else {
    // Shouldn't happen.
    [NSException raise:NSRangeException format:@"Could not find the given line in the graphics."];
  }
}

- (void)insertObject:(SKTGraphic *)graphic inTextAreasAtIndex:(NSUInteger)index {
  // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInTextAreas:atIndex:3...
  NSArray *textAreas = [self textAreas];
  if (index == [textAreas count]) {
    [self addInGraphics:graphic];
  } else {
    NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
    NSInteger newIndex = [graphics indexOfObjectIdenticalTo:textAreas[index]];
    if (newIndex != NSNotFound) {
      [self insertGraphic:graphic atIndex:newIndex];
    } else {
      // Shouldn't happen.
      [NSException raise:NSRangeException format:@"Could not find the given text area in the graphics."];
    }
  }
}

- (void)removeObjectFromTextAreasAtIndex:(NSUInteger)index {
  NSArray *textAreas = [self textAreas];
  NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
  NSInteger newIndex = [graphics indexOfObjectIdenticalTo:textAreas[index]];
  if (newIndex != NSNotFound) {
    [self removeGraphicAtIndex:newIndex];
  } else {
    // Shouldn't happen.
    [NSException raise:NSRangeException format:@"Could not find the given text area in the graphics."];
  }
}

- (void)insertObject:(SKTGraphic *)graphic inImagesAtIndex:(NSUInteger)index {
  // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInImages:atIndex:3...
  NSArray *images = [self images];
  if (index == [images count]) {
    [self addInGraphics:graphic];
  } else {
    NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
    NSInteger newIndex = [graphics indexOfObjectIdenticalTo:images[index]];
    if (newIndex != NSNotFound) {
      [self insertGraphic:graphic atIndex:newIndex];
    } else {
      // Shouldn't happen.
      [NSException raise:NSRangeException format:@"Could not find the given image in the graphics."];
    }
  }
}

- (void)removeObjectFromImagesAtIndex:(NSUInteger)index {
  NSArray *images = [self images];
  NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
  NSInteger newIndex = [graphics indexOfObjectIdenticalTo:images[index]];
  if (newIndex != NSNotFound) {
    [self removeGraphicAtIndex:newIndex];
  } else {
    // Shouldn't happen.
    [NSException raise:NSRangeException format:@"Could not find the given image in the graphics."];
  }
}

// The following "indicesOf..." methods are in support of scripting.  They allow more flexible range and relative specifiers to be used with the different graphic keys of a SKTDocument.
// The scripting engine does not know about the fact that the "rectangles" key is really just a subset of the "graphics" key, so script code like "rectangles from ellipse 1 to line 4" don't make sense to it.  But FloorSketch does know and can answer such questions itself, with a little work.
- (NSArray *)indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)rangeSpec {
  NSString *key = [rangeSpec key];

  if ([key isEqual:@"graphics"] || [key isEqual:@"rectangles"] || [key isEqual:@"ellipses"] || [key isEqual:@"lines"] || [key isEqual:@"polygons"] || [key isEqual:@"textAreas"] || [key isEqual:@"images"]) {
    // This is one of the keys we might want to deal with.
    NSScriptObjectSpecifier *startSpec = [rangeSpec startSpecifier];
    NSScriptObjectSpecifier *endSpec = [rangeSpec endSpecifier];
    NSString *startKey = [startSpec key];
    NSString *endKey = [endSpec key];
    NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];

    if ((startSpec == nil) && (endSpec == nil)) {
      // We need to have at least one of these...
      return nil;
    }
    if ([graphics count] == 0) {
      // If there are no graphics, there can be no match.  Just return now.
      return @[];
    }

    if ((!startSpec || [startKey isEqual:@"graphics"] || [startKey isEqual:@"rectangles"] || [startKey isEqual:@"ellipses"] || [startKey isEqual:@"lines"] || [startKey isEqual:@"polygons"] || [startKey isEqual:@"textAreas"] || [startKey isEqual:@"images"]) && (!endSpec || [endKey isEqual:@"graphics"] || [endKey isEqual:@"rectangles"] || [endKey isEqual:@"ellipses"] || [endKey isEqual:@"lines"] || [endKey isEqual:@"polygons"] || [endKey isEqual:@"textAreas"] || [endKey isEqual:@"images"])) {
      NSInteger startIndex;
      NSInteger endIndex;

      // The start and end keys are also ones we want to handle.

      // The strategy here is going to be to find the index of the start and stop object in the full graphics array, regardless of what its key is.  Then we can find what we're looking for in that range of the graphics key (weeding out objects we don't want, if necessary).

      // First find the index of the first start object in the graphics array
      if (startSpec) {
        id startObject = [startSpec objectsByEvaluatingWithContainers:self];
        if ([startObject isKindOfClass:[NSArray class]]) {
          if ([startObject count] == 0) {
            startObject = nil;
          } else {
            startObject = startObject[0];
          }
        }
        if (!startObject) {
          // Oops.  We could not find the start object.
          return nil;
        }
        startIndex = [graphics indexOfObjectIdenticalTo:startObject];
        if (startIndex == NSNotFound) {
          // Oops.  We couldn't find the start object in the graphics array.  This should not happen.
          return nil;
        }
      } else {
        startIndex = 0;
      }

      // Now find the index of the last end object in the graphics array
      if (endSpec) {
        id endObject = [endSpec objectsByEvaluatingWithContainers:self];
        if ([endObject isKindOfClass:[NSArray class]]) {
          NSUInteger endObjectsCount = [endObject count];
          if (endObjectsCount == 0) {
            endObject = nil;
          } else {
            endObject = endObject[(endObjectsCount-1)];
          }
        }
        if (!endObject) {
          // Oops.  We could not find the end object.
          return nil;
        }
        endIndex = [graphics indexOfObjectIdenticalTo:endObject];
        if (endIndex == NSNotFound) {
          // Oops.  We couldn't find the end object in the graphics array.  This should not happen.
          return nil;
        }
      } else {
        endIndex = [graphics count] - 1;
      }

      if (endIndex < startIndex) {
        // Accept backwards ranges gracefully
        NSInteger temp = endIndex;
        endIndex = startIndex;
        startIndex = temp;
      }

      {
        // Now startIndex and endIndex specify the end points of the range we want within the graphics array.
        // We will traverse the range and pick the objects we want.
        // We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
        NSMutableArray *result = [NSMutableArray array];
        BOOL keyIsGraphics = [key isEqual:@"graphics"];
        NSArray *rangeKeyObjects = (keyIsGraphics ? nil : [self valueForKey:key]);
        id curObj;
        NSUInteger curKeyIndex, i;

        for (i = startIndex; i <= endIndex; i++) {
          if (keyIsGraphics) {
            [result addObject:@(i)];
          } else {
            curObj = graphics[i];
            curKeyIndex = [rangeKeyObjects indexOfObjectIdenticalTo:curObj];
            if (curKeyIndex != NSNotFound) {
              [result addObject:@(curKeyIndex)];
            }
          }
        }
        return result;
      }
    }
  }
  return nil;
}

- (NSArray *)indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)relSpec {
  NSString *key = [relSpec key];

  if ([key isEqual:@"graphics"] || [key isEqual:@"rectangles"] || [key isEqual:@"ellipses"] || [key isEqual:@"lines"] || [key isEqual:@"polygons"] || [key isEqual:@"textAreas"] || [key isEqual:@"images"]) {
    // This is one of the keys we might want to deal with.
    NSScriptObjectSpecifier *baseSpec = [relSpec baseSpecifier];
    NSString *baseKey = [baseSpec key];
    NSArray *graphics = [(id<SKTGraphicsOwner>)self graphics];
    NSRelativePosition relPos = [relSpec relativePosition];

    if (baseSpec == nil) {
      // We need to have one of these...
      return nil;
    }
    if ([graphics count] == 0) {
      // If there are no graphics, there can be no match.  Just return now.
      return @[];
    }

    if ([baseKey isEqual:@"graphics"] || [baseKey isEqual:@"rectangles"] || [baseKey isEqual:@"ellipses"] || [baseKey isEqual:@"lines"] || [baseKey isEqual:@"polygons"] || [baseKey isEqual:@"textAreas"] || [baseKey isEqual:@"images"]) {
      NSInteger baseIndex;

      // The base key is also one we want to handle.

      // The strategy here is going to be to find the index of the base object in the full graphics array, regardless of what its key is.  Then we can find what we're looking for before or after it.

      // First find the index of the first or last base object in the graphics array
      // Base specifiers are to be evaluated within the same container as the relative specifier they are the base of.  That's this document.
      id baseObject = [baseSpec objectsByEvaluatingWithContainers:self];
      if ([baseObject isKindOfClass:[NSArray class]]) {
        NSInteger baseCount = [baseObject count];
        if (baseCount == 0) {
          baseObject = nil;
        } else {
          if (relPos == NSRelativeBefore) {
            baseObject = baseObject[0];
          } else {
            baseObject = baseObject[(baseCount-1)];
          }
        }
      }
      if (!baseObject) {
        // Oops.  We could not find the base object.
        return nil;
      }

      baseIndex = [graphics indexOfObjectIdenticalTo:baseObject];
      if (baseIndex == NSNotFound) {
        // Oops.  We couldn't find the base object in the graphics array.  This should not happen.
        return nil;
      }

      {
        // Now baseIndex specifies the base object for the relative spec in the graphics array.
        // We will start either right before or right after and look for an object that matches the type we want.
        // We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
        NSMutableArray *result = [NSMutableArray array];
        BOOL keyIsGraphics = [key isEqual:@"graphics"];
        NSArray *relKeyObjects = (keyIsGraphics ? nil : [self valueForKey:key]);
        id curObj;
        NSUInteger curKeyIndex, graphicCount = [graphics count];

        if (relPos == NSRelativeBefore) {
          baseIndex--;
        } else {
          baseIndex++;
        }
        while ((baseIndex >= 0) && (baseIndex < graphicCount)) {
          if (keyIsGraphics) {
            [result addObject:@(baseIndex)];
            break;
          } else {
            curObj = graphics[baseIndex];
            curKeyIndex = [relKeyObjects indexOfObjectIdenticalTo:curObj];
            if (curKeyIndex != NSNotFound) {
              [result addObject:@(curKeyIndex)];
              break;
            }
          }
          if (relPos == NSRelativeBefore) {
            baseIndex--;
          } else {
            baseIndex++;
          }
        }

        return result;
      }
    }
  }
  return nil;
}

- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier {
  // We want to handle some range and relative specifiers ourselves in order to support such things as "graphics from ellipse 3 to ellipse 5" or "ellipses from graphic 1 to graphic 10" or "ellipse before rectangle 3".
  // Returning nil from this method will cause the specifier to try to evaluate itself using its default evaluation strategy.

  if ([specifier isKindOfClass:[NSRangeSpecifier class]]) {
    return [self indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)specifier];
  } else if ([specifier isKindOfClass:[NSRelativeSpecifier class]]) {
    return [self indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)specifier];
  }


  // If we didn't handle it, return nil so that the default object specifier evaluation will do it.
  return nil;
}


@end
