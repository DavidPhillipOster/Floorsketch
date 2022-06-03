#import <Cocoa/Cocoa.h>

#import "SKTGraphic.h"
#import "SKTDocument.h"

@interface SKTAlignCommand : NSScriptCommand
@end

@implementation SKTAlignCommand

- (BOOL)isWellFormed {
  BOOL isArray = [[self directParameter] respondsToSelector:@selector(indexOfObject:)];
  BOOL isObjectSpec = [[self directParameter] isKindOfClass:[NSScriptObjectSpecifier class]];
  if (isObjectSpec) {
    NSArray *args = [[self directParameter] objectsByEvaluatingSpecifier];
    isArray = [args respondsToSelector:@selector(indexOfObject:)];
  }
  return (isArray && 1 < [[self directParameter] count]) && nil != [[self arguments] objectForKey:@"toEdge"];
}

// Note: experiment shows that naming this method performDefaultImplementation does not work.
// We must parse the arguments out of the command. It might be an explicit array like:
//
// tell document 1
//   align [box 1, box 2, box 3] to top edges
// end tell
//
// or an implicit one like
//
// align graphics of document 1  to left edges
//
- (nullable id)executeCommand {
  NSMutableArray *receivers = [NSMutableArray array];
  BOOL isArray = [[self directParameter] respondsToSelector:@selector(indexOfObject:)];
  if (isArray) {
    for (NSScriptObjectSpecifier *spec in [self directParameter]) {
      SKTGraphic *graphic = (SKTGraphic *)[spec objectsByEvaluatingSpecifier];
      if ([graphic isKindOfClass:[SKTGraphic class]]) {
        [receivers addObject:graphic];
      }
    }
  } else {
    NSArray *args = [[self directParameter] objectsByEvaluatingSpecifier];
    if ([args respondsToSelector:@selector(indexOfObject:)]) {
      [receivers addObjectsFromArray:args];
    }
  }
  if (1 < [receivers count]) {
    SKTGraphic *graphic0 = receivers[0];
    SKTDocument *document = (SKTDocument *)[graphic0 scriptingContainer];
    for (SKTGraphic *graphic in receivers) {
      if ([graphic scriptingContainer] != document) {
        return nil;
      }
    }
    if ( ! [document isKindOfClass:[SKTDocument class]]) {
      return nil;
    }

    NSNumber *enumeration = [[self arguments] objectForKey:@"toEdge"];
    NSUInteger code = [enumeration unsignedIntegerValue];
    switch (code) {
    case 'left':  [document alignLeftEdgesOfGraphics:receivers]; break;
    case 'righ':  [document alignRightEdgesOfGraphics:receivers]; break;
    case 'horc':  [document alignHorizontalCentersOfGraphics:receivers]; break;
    case 'top ':  [document alignTopEdgesOfGraphics:receivers]; break;
    case 'bott':  [document alignBottomEdgesOfGraphics:receivers]; break;
    case 'verc':  [document alignVerticalCentersOfGraphics:receivers]; break;
    default:
      return nil;
    }
    [self setScriptErrorNumber:0];
  }
  return nil;
}
@end
