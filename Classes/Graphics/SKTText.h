/*
 File: SKTText.h
 Abstract: A graphic object to represent a text area.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTGraphic.h"

// The keys described down below.
extern NSString *const SKTTextScriptingContentsKey;
extern NSString *const SKTTextUndoContentsKey;
extern NSString *const SKTTextContentsKey;

@interface SKTText : SKTGraphic<NSTextStorageDelegate>

/* This class is KVC but not KVO compliant for this key:

 "scriptingContents" (an NSTextStorage; read-write; coercible from NSString) -  The text being presented by this object. This is a to-one relationship, so it's meaningful to get an SKTText's "scriptingContents" and mutate it, which is exactly what Cocoa's built-in support for text scripting does.

 This class is KVC and KVO (kind of) compliant for this key:

 "undoContents" (an NSAttributedString; read-write) - Also the text being presented by this object. This is an attribute, and no one should be surprised if each invocation of -valueForKey:@"undoContents" returns a different object. One _should_ be surprised if the object returned by an invocation of -valueForKey:@"undoContents" changes after it's returned. (In an ideal world, this is true of pretty much all getting of attribute values and to-many relationships, regardless of whether the getting is done via KVC or via a directly-invoked accessor method). This class is only KVO-compliant for this key while -keysForValuesToObserveForUndo would return a set containing the key. That (and, in FloorSketch, SKTDocument's observing of "keysForValuesToObserveForUndo") are all the KVO-compliance that's necessary to make scripted changes of the contents undoable. More complete KVO-compliance is very difficult to implement because NSTextView's undo mechanism changes NSTextStorages directly, and listening in on that conversation is a lot of work.

 In FloorSketch, "scriptingContents" is scriptable. "undoContents" is another of the properties that SKTDocument observes so it can register undo actions when the value changes. Why are there two properties to represent the same thing? Why can't there just be one "contents" property that SKTDocument observes? Because SKTDocument implements undo by observing properties of SKTGraphics and registering undo actions using their old values when they change. Scripting operations don't actually change the value of the contents property, they just mutate the object that is the value.

 */
- (CGSize)naturalSize;
@end
