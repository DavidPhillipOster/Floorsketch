//  SKTParhScanner.m
//  FloorSketch
//
//  Created by david on 1/30/21.
//

#import "SKTPathScanner.h"

@interface SKTPathScanner ()
@property (readwrite, copy) NSString *string;
@property NSUInteger currentIndex;
@property char previousVerb;
@property BOOL wasLower; // most recently seen verb letter

@property (nullable, copy) NSCharacterSet *charactersToBeSkipped;
@end

static int ArgCountForVerb(char verb) {
  switch (verb) {
    case 'Z':
    case 'z':
      return 0;
    case 'H':
    case 'h':
    case 'V':
    case 'v':
      return 1;
    case 'L':
    case 'l':
    case 'M':
    case 'm':
    case 'T':
    case 't':
    default:
      return 2;
    case 'Q':
    case 'q':
    case 'S':
    case 's':
      return 4;
    case 'C':
    case 'c':
     return 6;
    case 'A':
    case 'a':
     return 7;
  }
}


@implementation SKTPathScanner

- (instancetype)init {
  return [self initWithString:@""];
}

- (instancetype)initWithString:(NSString *)string {
  self = [super init];
  if (self) {
    _string = string;
    NSMutableCharacterSet *skipChars = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    [skipChars addCharactersInString:@","];
    _charactersToBeSkipped = skipChars;
    _previousVerb = 'L';
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  return [[[self class] allocWithZone:zone] initWithString:self.string];
}


// A scanner suitable for reading a <path> d attribute.
+ (instancetype)scannerWithString:(NSString *)string {
  return [[self alloc] initWithString:string];
}

/*
M x,y
L x,y
H x
V y
C x1,y1, x2,y2 x,y cubic Bezier curve to (x,y) p1, and p2 are start, end control points.
S x2,y2, x,y cubic Bezier curve to (x,y)  (x2,y2) is the end control point.
The start control point is a copy of the end control point of the previous curve command. If the previous command wasn't a cubic Bézier curve, the start control point is the same as the curve starting point (current point)
Q x1,y1 x,y quadratic Bezier curve to (x,y)
T x,y quadratic Bezier curve to (x,y). Control point is assumed to be the same as the last control point used.
A rx ry x-axis-rotation large-arc-flag sweepflag x, y
Draws arc to the point (x,y)
The values rx and ry are the radiuses of the ellipse.
The x-axis-rotation rotates the ellipse the arc is created from (without changing start/end point).
The large-arc-flag (0 or 1) determines how wide the arc is.
The sweepflag (0 or 1) determines which way the arc goes (underneath or above).
Z Closepath
 */
// Returns true each time it successfully reads an atom from the string.
- (BOOL)getVerb:(unichar *)verbp argCount:(NSUInteger *)countp args:(CGFloat *)args {
  unichar verb = '\0';
  NSUInteger argCount = 0;
  if (self.currentIndex < self.string.length) {
    [self skipWhitespace];
    verb = [self peekCharacter];
    switch (verb) {
    case '\0':
      break;
    case 'H':
    case 'h':
    case 'V':
    case 'v':
      self.wasLower = (verb == 'h' || verb == 'v');
      argCount = 1;
      self.currentIndex += 1;
      break;
    case '-':
    case '.':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      verb = self.previousVerb; // depend on the previous explicit verb.
      // But if previous is a move, then implicit is a line.
      if ('m' == verb) {
        verb = 'l';
      } else if ('M' == verb) {
        verb = 'L';
      }
      argCount = ArgCountForVerb(verb);
      break;
    case 'L':
    case 'l':
    case 'M':
    case 'm':
    case 'T':
    case 't':
      self.wasLower = (verb == 'l' || verb == 'm'|| verb == 't');
      argCount = 2;
      self.currentIndex += 1;
      break;
    case 'Q':
    case 'q':
    case 'S':
    case 's':
      self.wasLower = (verb == 's' || verb == 'q');
      argCount = 4;
      self.currentIndex += 1;
      break;
    case 'C':
    case 'c':
      self.wasLower = (verb == 'c');
      argCount = 6;
      self.currentIndex += 1;
      break;
    case 'A':
    case 'a':
      self.wasLower = (verb == 'a');
      argCount = 7;
      self.currentIndex += 1;
      break;
    case 'Z':
    case 'z':
      self.wasLower = (verb == 'z');
      self.currentIndex += 1;
      break;
    }
    for (NSUInteger i = 0; i < argCount; ++i) {
      CGFloat f;
      if ([self scanFloat:&f]) {
        args[i] = f;
      } else {
        verb = '\0';
        break;
      }
    }
    *verbp = verb;
    self.previousVerb = verb;
    *countp = argCount;
    return '\0' != verb;
  }
  return NO;
}

- (BOOL)scanFloat:(CGFloat *)valp {
  [self skipWhitespace];
  NSUInteger startIndex = self.currentIndex;
  BOOL hasPeriod = NO;
  unichar c;
  // floats can have a leading minus.
  if (self.currentIndex < self.string.length && '\0' != (c = [self peekCharacter]) && '-' == c) {
    self.currentIndex += 1;
  }
  while (self.currentIndex < self.string.length && '\0' != (c = [self peekCharacter]) && (isdigit(c) || ( ! hasPeriod && c == '.'))) {
    if (c == '.') {
      hasPeriod = YES;
    }
    self.currentIndex += 1;
  }
  // handle optional exponent.
  if (startIndex+1 < self.currentIndex && self.currentIndex < self.string.length && '\0' != (c = [self peekCharacter]) && (c == 'e' || c == 'E')) {
    self.currentIndex += 1;
    BOOL hasMinus = NO;
    while (self.currentIndex < self.string.length && '\0' != (c = [self peekCharacter]) && (isdigit(c) || ( ! hasMinus && c == '-'))) {
      if (c == '-') {
        hasMinus = YES;
      }
      self.currentIndex += 1;
    }
  }
  if (startIndex < self.currentIndex) {
    NSString *s = [self.string substringWithRange:NSMakeRange(startIndex, self.currentIndex-startIndex)];
    *valp = [s doubleValue];
    return YES;
  }
  return NO;
}

- (void)skipWhitespace {
  while (self.currentIndex < self.string.length && [self isCurrentSkippable]) {
    self.currentIndex += 1;
  }
}

- (unichar)peekCharacter {
  if (self.currentIndex < self.string.length) {
    return [self.string characterAtIndex:self.currentIndex];
  }
  return '\0';
}

- (BOOL)isCurrentSkippable {
  unichar c = [self peekCharacter];
  return ('\0' != c) && [_charactersToBeSkipped characterIsMember:c];
}


@end
