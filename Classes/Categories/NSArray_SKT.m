/*  NSArray_SKT.m
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "NSArray_SKT.h"

#import <objc/objc-runtime.h>

@implementation NSArray(SVG)

- (instancetype)arrayByFilteringWithClass:(Class)theClass {
  NSMutableArray *result = [NSMutableArray array];
  NSUInteger count = [self count];
  for (NSUInteger i = 0; i < count; i++) {
    id curItem = self[i];
    if ([curItem isKindOfClass:theClass]) {
      [result addObject:curItem];
    }
  }
  return result;
}

// Rather than making an array then counting it, just count it.
- (NSUInteger)countByFilteringWithClass:(Class)theClass {
  NSUInteger count = [self count];
  NSUInteger result = 0;
  for (NSUInteger i = 0; i < count; i++) {
    id curItem = self[i];
    if ([curItem isKindOfClass:theClass]) {
      result++;
    }
  }
  return result;
}


// Given a selector that returns a BOOL value, give the count for those where it is true.
- (NSUInteger)countByFilteringWithSelector:(SEL)predicate {
  NSUInteger count = [self count];
  NSUInteger result = 0;
  for (NSUInteger i = 0; i < count; i++) {
    id curItem = self[i];
    if (((BOOL (*)(id, SEL))objc_msgSend)(curItem, predicate)) {
      result++;
    }
  }
  return result;
}


- (NSUInteger)countByFilteringWithInverseSelector:(SEL)predicate {
  return [self count] - [self countByFilteringWithSelector:predicate];
}


@end

@implementation NSMutableArray(SVG)
- (void)s_reverse {
  if (1 < [self count]) {
    NSUInteger lo = 0;
    NSUInteger hi = [self count] - 1;
    for (; lo < hi; ++lo, --hi) {
      [self exchangeObjectAtIndex:lo withObjectAtIndex:hi];
    }
  }
}

@end
