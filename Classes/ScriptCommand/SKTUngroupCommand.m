#import <Cocoa/Cocoa.h>

#import "SKTGroup.h"

// use 'make group with ' to make a new group
@interface SKTUngroupCommand : NSScriptCommand
@end

// TODO is this needed?
@implementation SKTUngroupCommand

- (BOOL)isWellFormed {
  BOOL isArray = [[self directParameter] respondsToSelector:@selector(indexOfObject:)];
  BOOL isObjectSpec = [[self directParameter] isKindOfClass:[NSScriptObjectSpecifier class]];
  return (isArray && 0 < [[self directParameter] count]) || isObjectSpec;
}

// Note: experiment shows that naming this method performDefaultImplementation does not work.
// We must parse the arguments out of the command. It might be an explicit array like:
//
// tell document 1
//   ungroup [group 1, group 2, group 3] to top edges
//
// or an implicit one like
//
// align groups of document 1 to left edges
//
- (nullable id) executeCommand {
  NSMutableArray *receivers = [NSMutableArray array];
  BOOL isArray = [[self directParameter] respondsToSelector:@selector(indexOfObject:)];
  if (isArray) {
    for (NSScriptObjectSpecifier *spec in [self directParameter]) {
      SKTGroup *group = (SKTGroup *)[spec objectsByEvaluatingSpecifier];
      if ([group isKindOfClass:[SKTGroup class]]) {
        [receivers addObject:group];
      }
    }
  } else {
    NSScriptObjectSpecifier *spec = (NSScriptObjectSpecifier *)[self directParameter];
    SKTGroup *group = (SKTGroup *)[spec objectsByEvaluatingSpecifier];
    if ([group isKindOfClass:[SKTGroup class]]) {
      [receivers addObject:group];
    }
  }
  NSMutableArray *result = [NSMutableArray array];
  for (SKTGroup *group in receivers) {
    NSArray *parts = [group ungroupInsertedContents];
    if ([parts count]) {
      [result addObjectsFromArray:parts];
    }
  }
  return result;
}

@end
