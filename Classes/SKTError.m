/*
 File: SKTError.m
 Abstract: Custom error domain and constants for FloorSketch, and a function to create a new error object.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTError.h"


// A string constant declared in the header.
NSString *SKTErrorDomain = @"SketchErrorDomain";


NSError *SKTErrorWithCode(NSInteger code) {
  // An NSError has a bunch of parameters that determine how it's presented to the user. We specify two of them here. They're localized strings that we look up in SKTError.strings, whose keys are derived from the error code and an indicator of which kind of localized string we're looking up. The value: strings are specified so that at least something is shown if there's a problem with the strings file, but really they should never ever be shown to the user. When testing an app like FloorSketch you really have to make sure that you've seen every call of SKTErrorWithCode() executed since the last time you did things like change the set of available error codes or edit the strings files.
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *localizedDescription = [mainBundle localizedStringForKey:[NSString stringWithFormat:@"description%ld", (long)code] value:@"FloorSketch could not complete the operation because an unknown error occurred." table:@"SKTError"];
  NSString *localizedFailureReason = [mainBundle localizedStringForKey:[NSString stringWithFormat:@"failureReason%ld", (long)code] value:@"An unknown error occurred." table:@"SKTError"];
  NSDictionary *errorUserInfo = @{NSLocalizedDescriptionKey: localizedDescription, NSLocalizedFailureReasonErrorKey: localizedFailureReason};

  // In FloorSketch we know that no one's going to be paying attention to the domain and code that we use here, but still we don't specify junk values. Certainly we don't just use NSCocoaErrorDomain and some random error code.
  return [NSError errorWithDomain:SKTErrorDomain code:code userInfo:errorUserInfo];
}
