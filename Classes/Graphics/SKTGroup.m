/*  SKTGroup.h
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTGroup.h"

#import "SKTDocument.h"
#import "SKTGraphic.h"
#import "SKTGraphicsOwner.h"

// Most of the scripting support is in SKTGraphicsOwner.h


@interface SKTGroup()<SKTGraphicsOwner>
@end

@implementation SKTGroup
@synthesize graphics = _graphics;

- (instancetype)initWithProperties:(NSDictionary *)properties {
  self = [super initWithProperties:properties];
  if (self) {
    NSMutableArray *graphics = nil;
    NSArray *graphicPropertiesArray = properties[SKTDocumentGraphicsKey];
    if ([graphicPropertiesArray isKindOfClass:[NSArray class]]) {
      graphics = [[SKTGraphic graphicsWithProperties:graphicPropertiesArray] mutableCopy];
    }
    if (nil == graphics) {
      graphics = [[NSMutableArray alloc] init];
    }
    _graphics = graphics;
  }
  return self;
}

- (CGFloat)handleWidth {
  return 0;
}

+ (instancetype)groupWithGraphics:(NSArray *)graphics {
// TODO
  NSLog(@"SKTGraphicsOwner");
  return nil;
}

- (NSArray *)ungroupInsertedContents {
// TODO
  NSLog(@"ungroupInsertedContents");
  return nil;
}

- (NSMutableDictionary *)properties {
  NSMutableDictionary *properties = [super properties];
  properties[SKTDocumentGraphicsKey] = [SKTGraphic propertiesWithGraphics:_graphics];
  return properties;
}


- (instancetype)copyWithZone:(NSZone *)zone {
  SKTGroup *result = [super copyWithZone:zone];
  NSMutableArray *graphicsCopy = [[self graphics] mutableCopyWithZone:zone];
  NSUInteger count = [graphicsCopy count];
  for (NSUInteger i = 0; i < count; ++i) {
    graphicsCopy[i] = [graphicsCopy[i] copyWithZone:zone];
  }
  [result setGraphics:graphicsCopy];
  return result;
}


// Empty groups are legal if there is file i/o.
- (void)setGraphics:(NSMutableArray *)graphics {
  if (nil == graphics && _graphics) {
    NSLog(@"attempt to set graphics to nil");
    return;
  }
  for (SKTGraphic *graphic in _graphics) {
    graphic.scriptingContainer = nil;
  }
  _graphics = graphics;
  for (SKTGraphic *graphic in _graphics) {
    graphic.scriptingContainer = self;
  }
  [self updateBounds];
}

- (NSRect)drawingBounds {
  CGRect result = CGRectZero;
  if (0 < [_graphics count]) {
    result = [[_graphics firstObject] drawingBounds];
  }
  NSUInteger count = [_graphics count];
  for (NSUInteger i = 1; i < count; ++i) {
    SKTGraphic *graphic = _graphics[i];
    result = CGRectUnion(result, [graphic drawingBounds]);
  }
  return result;
}

- (CGRect)computeBounds {
  CGRect result = CGRectZero;
  if (0 < [_graphics count]) {
    result = [[_graphics firstObject] bounds];
  }
  NSUInteger count = [_graphics count];
  for (NSUInteger i = 1; i < count; ++i) {
    SKTGraphic *graphic = _graphics[i];
    result = CGRectUnion(result, [graphic bounds]);
  }
  return result;
}

// Call this after modifying the points array to trigger drawing by changing bounds.
// self setbounds would try to translate/scale to new bounds, so we call super to skup that.
// Incrementing the update count before and after the change triggers a redraw of the old and new positions.
- (void)updateBounds {
  [self setUpdateCount:1 + [self updateCount]];
  CGRect newBounds = [self computeBounds];
  [super setBounds:newBounds];
  [self setUpdateCount:1 + [self updateCount]];
}

- (void)setBounds:(NSRect)bounds {
  CGRect oldBounds = [self computeBounds];
  [super setBounds:bounds];
  if ( ! CGRectEqualToRect(bounds, oldBounds)) {
    CGPoint translate = CGPointMake(bounds.origin.x - oldBounds.origin.x, bounds.origin.y - oldBounds.origin.y);
    CGFloat sx;
    if (oldBounds.size.width == 0) {
      sx = 1;
    } else {
      sx = bounds.size.width / oldBounds.size.width;
    }
    CGFloat sy;
    if (oldBounds.size.height == 0) {
      sy = 1;
    } else {
      sy = bounds.size.height / oldBounds.size.height;
    }
    CGSize scale = CGSizeMake(sx, sy);
    if ( ! (CGPointEqualToPoint(CGPointZero, translate) && CGSizeEqualToSize(CGSizeMake(1,1), scale))) {
      for (SKTGraphic *graphic in _graphics) {
        CGRect itemBounds = [graphic bounds];
        CGFloat tl = itemBounds.origin.x - bounds.origin.x;
        CGFloat tr = tl + itemBounds.size.width;

        CGFloat bl = itemBounds.origin.y - bounds.origin.y ;
        CGFloat br = bl + itemBounds.size.height;

        tl = (tl + translate.x) * scale.width;
        tr = (tr + translate.x) * scale.width;

        bl = (bl + translate.y) * scale.height;
        br = (br + translate.y) * scale.height;

        CGRect newItemBounds = CGRectMake(tl + bounds.origin.x, bl + bounds.origin.y, tr - tl, br - bl);
        [graphic setBounds:newItemBounds];
      }
    }
  }
}

- (void)drawContentsInView:(NSView *)view rect:(NSRect)rect isBeingCreateOrEdited:(BOOL)isBeingCreateOrEdited {
  [self drawGraphics:[self graphics] view:view rect:rect];
}


- (NSString *)asSVGString {
  NSMutableArray *a = [NSMutableArray array];
  [a addObject:[NSString stringWithFormat:@"<g %@>", [self svgAttributesString]]];
  for (int i = ((int)[_graphics count]) - 1; 0 <= i; --i) {
    SKTGraphic *graphic = _graphics[i];
    [a addObject:[graphic asSVGString]];
  }
  [a addObject:@"</g>"];
  return [a componentsJoinedByString:@"\n"];
}


- (NSUndoManager *)undoManager {
  NSUndoManager *result = nil;
  if ([self.scriptingContainer respondsToSelector:@selector(undoManager)]) {
    result = [self.scriptingContainer performSelector:@selector(undoManager)];
  }
  return result;
}

- (void)addObjectsFromArrayToUndoGroupInsertedGraphics:(NSArray *)graphic {
  NSLog(@"addObjectsFromArrayToUndoGroupInsertedGraphics - what should this do? Add them to the document's set?");
}

- (void)startObservingGraphics:(NSArray *)graphics {
  NSLog(@"startObservingGraphics - what should this do? delegate to the document?");
}

- (void)stopObservingGraphics:(NSArray *)graphics {
  NSLog(@"startObservingGraphics - what should this do? delegate to the document?");
}

@end
