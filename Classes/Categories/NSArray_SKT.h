/*  NSArray_SKT.h
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import <Foundation/Foundation.h>

@interface NSArray(SVG)
// Returns a new array. just a subset of the input that has all members of class class.
- (NSArray *)arrayByFilteringWithClass:(Class)theClass;

// Rather than making an array then counting it, just count it.
- (NSUInteger)countByFilteringWithClass:(Class)theClass;

// Given a selector that returns a BOOL value, give the count for those where it is true.
- (NSUInteger)countByFilteringWithSelector:(SEL)predicate;

// Given a selector that returns a BOOL value, give the count for those where it is false.
- (NSUInteger)countByFilteringWithInverseSelector:(SEL)predicate;

@end

@interface NSMutableArray(SVG)
// Reverse the array. prefix to prevent colliding with Apple.
- (void)s_reverse;
@end
