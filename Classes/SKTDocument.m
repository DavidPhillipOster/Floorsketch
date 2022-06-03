/*
 File: SKTDocument.m
 Abstract: The main document class for the application.
 Version: 1.8


  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.

 */

#import "SKTDocument.h"

#import "NSArray_SKT.h"
#import "NSColor_SKT.h"
#import "SKTDocumentSVG.h"
#import "SKTError.h"
#import "SKTGraphic.h"
#import "SKTGraphicsOwner.h"
#import "SKTGraphicView.h"
#import "SKTGrid.h"
#import "SKTGroup.h"
#import "SKTRenderingView.h"
#import "SKTEllipse.h"
#import "SKTImage.h"
#import "SKTLine.h"
#import "SKTPath.h"
#import "SKTPoly.h"
#import "SKTRectangle.h"
#import "SKTText.h"
#import "SKTWindowController.h"

// Most of the scripting support is in SKTGraphicsOwner.h

@interface SKTDocument()<SKTGraphicsOwner> {
  // The value underlying the key-value coding (KVC) and observing (KVO) compliance described below.
  NSMutableArray *_graphics;

  // State that's used by the undo machinery. It all gets cleared out each time the undo manager sends a checkpoint notification. _undoGroupInsertedGraphics is the set of graphics that have been inserted, if any have been inserted. _undoGroupOldPropertiesPerGraphic is a dictionary whose keys are graphics and whose values are other dictionaries, each of which contains old values of graphic properties, if graphic properties have changed. It uses an NSMapTable instead of an NSMutableDictionary so we can set it up not to copy the graphics that are used as keys, something not possible with NSMutableDictionary. And then because NSMapTables were not objects in Mac OS 10.4 and earlier we have to wrap them in NSObjects that can be reference-counted by NSUndoManager, hence SKTMapTableOwner. _undoGroupPresentablePropertyName is the result of invoking +[SKTGraphic presentablePropertyNameForKey:] for changed graphics, if the result of each invocation has been the same so far, nil otherwise. _undoGroupHasChangesToMultipleProperties is YES if changes have been made to more than one property, as determined by comparing the results of invoking +[SKTGraphic presentablePropertyNameForKey:] for changed graphics, NO otherwise.
  NSMutableSet *_undoGroupInsertedGraphics;
  NSMutableDictionary *_undoGroupOldPropertiesPerGraphic; // Key is an SKTWrapper so we can copy it without copying the object it points to.
  NSString *_undoGroupPresentablePropertyName;
  BOOL _undoGroupHasChangesToMultipleProperties;

}
@end

// like NSPointerValue, but retains its object. Doesn't copy the object.
@interface SKTWrapper : NSObject < NSCopying>
@property(strong) id retainedObjectValue;
+ (instancetype)wrap:(id)object;
@end

@implementation SKTWrapper

+ (instancetype)wrap:(id)object {
  SKTWrapper *result = [[SKTWrapper alloc] init];
  result.retainedObjectValue = object;
  return result;
}


- (NSUInteger)hash {
  return (NSUInteger)self.retainedObjectValue;
}

- (BOOL)isEqual:(id)object {
  SKTWrapper *other = (SKTWrapper *)object;
  return [self class] == [other class] && [self hash] == [other hash];
}

- (instancetype)copyWithZone:(NSZone *)zone {
  SKTWrapper *result = [[SKTWrapper alloc] init];
  result.retainedObjectValue = self.retainedObjectValue;
  return result;
}

#if ! NDEBUG
- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p<<%@>> >", [self class], self, [self retainedObjectValue]];
}
#endif
@end

// String constants declared in the header.
NSString *const SKTDocumentCanvasSizeKey = @"canvasSize";
NSString *const SKTDocumentGraphicsKey = @"graphics";
NSString *const SKTDocumentVisibleRulerKey = @"visibleRuler";
NSString *const SKTDocumentScaleKey = @"scale";
NSString *const SKTDocumentGridColorKey = @"gridColor";
NSString *const SKTDocumentGridSpacingKey = @"gridSpacing";
NSString *const SKTDocumentGridAlwaysShownKey = @"gridAlwaysShown";
NSString *const SKTDocumentGridConstrainingKey = @"gridConstraining";

// Values that are used as contexts by this class' invocation of KVO observer registration methods. See the comment near the top of SKTGraphicView.m for a discussion of this.
static char *const SKTDocumentUndoKeysObservationContext = "com.turbozen.SKTDocument.undoKeys";
static char *const SKTDocumentUndoObservationContext = "com.turbozen.SKTDocument.undo";

// The document type names that must also be used in the application's Info.plist file. We'll take out all uses NSPDFPboardType and NSTIFFPboardType someday when we drop 10.4 compatibility and we can just use UTIs everywhere.
static NSString *const SKTDocumentTypeName = @"com.turbozen.FloorSketch";

// More keys, and a version number, which are just used in Sketch's property-list-based file format.
static NSString *const SKTDocumentVersionKey = @"version";
static NSString *const SKTDocumentPrintInfoKey = @"printInfo";
static NSString *const SKTDocumentPropertiesKey = @"docProperties";

static NSInteger SKTDocumentCurrentVersion = 2;

@implementation SKTDocument
@synthesize handleWidth;

// An override of the superclass' designated initializer, which means it should always be invoked.
- (instancetype)init {
  self = [super init];
  if (self) {
    _graphics = [NSMutableArray array];
    // Before anything undoable happens, register for a notification we need.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeUndoManagerCheckpoint:) name:NSUndoManagerCheckpointNotification object:[self undoManager]];
  }
  return self;
}


- (void)dealloc {
  // Undo some of what we did in -insertGraphics:atIndexes:.
  [self stopObservingGraphics:[self graphics]];

  // Undo what we did in -init.
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUndoManagerCheckpointNotification object:[self undoManager]];
}


#pragma mark - Private KVC-Compliance for Public Properties

// Never return nil when the invoker's expecting an empty collection.
- (NSMutableArray *)graphics {
  return _graphics;
}

- (void)setGraphics:(NSMutableArray *)graphics {
  if (nil == graphics) {
    NSLog(@"attempt to set graphics to nil");
    return ;
  }
  _graphics = graphics;
}


// There's no need for a -setGraphics: method right now, because [thisDocument mutableArrayValueForKey:@"graphics"] will happily return a mutable collection proxy that invokes our insertion and removal methods when necessary. A pitfall to watch out for is that -setValue:forKey: is _not_ bright enough to invoke our insertion and removal methods when you would think it should. If we ever catch anyone sending this object -setValue:forKey: messages for "graphics" then we have to add -setGraphics:. When we do, there's another pitfall to watch out for: if -setGraphics: is implemented in terms of -insertGraphics:atIndexes: and -removeGraphicsAtIndexes:, or vice versa, then KVO autonotification will cause observers to get redundant, incorrect, notifications (because all of the methods involved have KVC-compliant names).


#pragma mark - Simple Property Getting


- (NSSize)canvasSize {

  // A Sketch's canvas size is the size of the piece of paper that the user selects in the Page Setup panel for it, minus the document margins that are set.
  NSPrintInfo *printInfo = [self printInfo];
  NSSize canvasSize = [printInfo paperSize];
  canvasSize.width -= ([printInfo leftMargin] + [printInfo rightMargin]);
  canvasSize.height -= ([printInfo topMargin] + [printInfo bottomMargin]);
  return canvasSize;

}


#pragma mark - Overrides of NSDocument Methods


// This method will only be invoked on Mac 10.6 and later. It's ignored on Mac OS 10.5.x which just means that documents are opened serially.
+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {

  // There's nothing in FloorSketch that would cause multithreading trouble when documents are opened in parallel in separate NSOperations.
  return YES;

}


// This application's Info.plist only declares two document types, which go by the name SKTDocumentTypeName/kUTTypeScalableVectorGraphics for which it can play the "editor" role, and none for which it can play the "viewer" role, so the type better match one of those. Notice that we don't compare uniform type identifiers (UTIs) with -isEqualToString:. We use -[NSWorkspace type:conformsToType:] (new in 10.5), which is nearly always the correct thing to do with UTIs.
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {

  BOOL didReadSuccessfully = NO;
  NSArray *graphics = nil;
  NSPrintInfo *printInfo = nil;
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  NSDictionary *properties = nil;
  if ([workspace type:typeName conformsToType:SKTDocumentTypeName]) {
    properties = [self propertiesSKTDocumentTypeFromData:data graphics:&graphics printInfo:&printInfo error:outError];
  } else if ([workspace type:typeName conformsToType:(NSString *)kUTTypeScalableVectorGraphics]) {
    graphics = [self graphicsSVGTypeFromData:data printInfo:&printInfo error:outError];
    if (graphics) {
      properties = @{};
    }
  }
  didReadSuccessfully = (nil != properties);

  // Did the reading work? In this method we ought to either do nothing and return an error or overwrite every property of the document. Don't leave the document in a half-baked state.
  if (didReadSuccessfully) {

    // Update the document's list of graphics by going through KVC-compliant mutation methods. KVO notifications will be automatically sent to observers (which does matter, because this might be happening at some time other than document opening; reverting, for instance). Update its page setup the regular way. Don't let undo actions get registered while doing any of this. The fact that we have to explicitly protect against useless undo actions is considered an NSDocument bug nowadays, and will someday be fixed.
    [[self undoManager] disableUndoRegistration];
    NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[self graphics] count])];
    _propertiesWhileOpening = properties[SKTDocumentPropertiesKey];
    if (set) {
      [self removeGraphicsAtIndexes:set];
    }
    [self insertGraphics:graphics atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [graphics count])]];
    [self setPrintInfo:printInfo];
    [[self undoManager] enableUndoRegistration];

  } // else it was the responsibility of something in the previous paragraph to set *outError.
  return didReadSuccessfully;

}

- (NSDictionary *)propertiesSKTDocumentTypeFromData:(NSData *)data graphics:(NSArray **)outGraphics printInfo:(NSPrintInfo **)outPrintInfo error:(NSError **)outError {
 // The file uses FloorSketch's new format. Read in the property list.
  NSDictionary *properties = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
  if (properties) {
    // Get the graphics. Strictly speaking the property list of an empty document should have an empty graphics array, not no graphics array, but we cope easily with either. Don't trust the type of something you get out of a property list unless you know your process created it or it was read from your application or framework's resources.
    NSArray *graphicPropertiesArray = properties[SKTDocumentGraphicsKey];
    NSArray *graphics = [graphicPropertiesArray isKindOfClass:[NSArray class]] ? [SKTGraphic graphicsWithProperties:graphicPropertiesArray] : @[];
    if (outGraphics) {
      *outGraphics = graphics;
    }

    // Get the page setup. There's no point in considering the opening of the document to have failed if we can't get print info. A more finished app might present a panel warning the user that something's fishy though.
    NSData *printInfoData = properties[SKTDocumentPrintInfoKey];
    NSPrintInfo *printInfo = [printInfoData isKindOfClass:[NSData class]] ? [NSUnarchiver unarchiveObjectWithData:printInfoData] : [[NSPrintInfo alloc] init];
    if (outPrintInfo) {
      *outPrintInfo = printInfo;
    }
  } else if (outError) {

    // If property list parsing fails we have no choice but to admit that we don't know what went wrong. The error description returned by +[NSPropertyListSerialization propertyListFromData:mutabilityOption:format:errorDescription:] would be pretty technical, and not the sort of thing that we should show to a user.
    *outError = SKTErrorWithCode(SKTUnknownFileReadError);

  }
  return properties;
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {

  // This method must be prepared for typeName to be any value that might be in the array returned by any invocation of -writableTypesForSaveOperation:. Because this class:
  // doesn't - override -writableTypesForSaveOperation:, and
  // doesn't - override +writableTypes or +isNativeType: (which the default implementation of -writableTypesForSaveOperation: invokes),
  // and because:
  // - FloorSketch has a "Save a Copy As..." file menu item that results in NSSaveToOperations,
  // we know that that the type names we have to handle here include:
  // - SKTDocumentOldTypeName (on Mac OS 10.4) or SKTDocumentNewTypeName (on 10.5), because this application's Info.plist file declares that instances of this class can play the "editor" role for it, and
  // - NSPDFPboardType (on 10.4) or kUTTypePDF (on 10.5) and NSTIFFPboardType (on 10.4) or kUTTypeTIFF (on 10.5), because according to the Info.plist a FloorSketch document is exportable as them.
  // We use -[NSWorkspace type:conformsToType:] (new in 10.5), which is nearly always the correct thing to do with UTIs, but the arguments are reversed here compared to what's typical. Think about it: this method doesn't know how to write any particular subtype of the supported types, so it should assert if it's asked to. It does however effectively know how to write all of the supertypes of the supported types (like public.data), and there's no reason for it to refuse to do so. Not particularly useful in the context of an app like FloorSketch, but correct.
  // If we had reason to believe that +[SKTRenderingView pdfDataWithGraphics:] or +[SKTGraphic propertiesWithGraphics:] could return nil we would have to arrange for *outError to be set to a real value when that happens. If you signal failure in a method that takes an error: parameter and outError != NULL you must set *outError to something decent.
  NSData *data = nil;
  NSArray *graphics = [self graphics];
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  if (NSOrderedSame == [SKTDocumentTypeName caseInsensitiveCompare:typeName]) {
    data = [self dataOfSKTDocumentTypeError:outError];
  } else if ([workspace type:(NSString *)kUTTypeScalableVectorGraphics conformsToType:typeName]) {
    data = [self dataOfSVGTypeError:outError];
  } else if ([workspace type:(NSString *)kUTTypePDF conformsToType:typeName]) {
    data = [SKTRenderingView pdfDataWithGraphics:graphics];
  } else if ([workspace type:(NSString *)kUTTypePNG conformsToType:typeName]) {
    data = [SKTRenderingView pngDataWithGraphics:graphics error:outError];
  } else if ([workspace type:(NSString *)kUTTypeTIFF conformsToType:typeName]) {
    data = [SKTRenderingView tiffDataWithGraphics:graphics error:outError];
  }
  return data;
}

- (NSData *)dataOfSKTDocumentTypeError:(NSError **)outError {
  NSArray *graphics = [self graphics];
  NSPrintInfo *printInfo = [self printInfo];

  // Convert the contents of the document to a property list and then flatten the property list.
  NSMutableDictionary *properties = [NSMutableDictionary dictionary];
  properties[SKTDocumentVersionKey] = @(SKTDocumentCurrentVersion);
  properties[SKTDocumentGraphicsKey] = [SKTGraphic propertiesWithGraphics:graphics];
  properties[SKTDocumentPrintInfoKey] = [NSArchiver archivedDataWithRootObject:printInfo];
  NSMutableDictionary *docProperties = [NSMutableDictionary dictionary];
  SKTWindowController *controller = (SKTWindowController *)self.windowControllers.firstObject;
  if ([controller respondsToSelector:@selector(zoomFactor)]) {
    docProperties[SKTDocumentScaleKey] = @([controller zoomFactor]);
  }
  if ([controller respondsToSelector:@selector(rulersVisible)] && [controller rulersVisible]) {
    docProperties[SKTDocumentVisibleRulerKey] = @YES;
  }
  if ([controller respondsToSelector:@selector(grid)]) {
    SKTGrid *grid = [controller grid];
    if (grid) {
      if ([grid isAlwaysShown]) {
        docProperties[SKTDocumentGridAlwaysShownKey] = @YES;
      }
      if ([grid isConstraining]) {
        docProperties[SKTDocumentGridConstrainingKey] = @YES;
      }
      if (0.0 < [grid spacing]) {
        docProperties[SKTDocumentGridSpacingKey] = @([grid spacing]);
      }
      docProperties[SKTDocumentGridColorKey] = [[grid color] asArchiveData];
    }
  }
  properties[SKTDocumentPropertiesKey] = docProperties;
  NSData *data = [NSPropertyListSerialization dataFromPropertyList:properties format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
  return data;
}

- (NSData *)dataOfSVGTypeError:(NSError **)outError {
  NSArray *graphics = [self graphics];
  NSMutableArray *result = [NSMutableArray array];
  NSPrintInfo *printInfo = [self printInfo];
  [result addObject:[NSString stringWithFormat:
@"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
"<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\"\n"
"\"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n"
"<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%dpx\" height=\"%dpx\" viewbox=\"0 0 %d %d\">",
    (int)printInfo.paperSize.width, (int)printInfo.paperSize.height,
    (int)printInfo.paperSize.width, (int)printInfo.paperSize.height]];

  for (NSInteger i = ((NSInteger)[graphics count]) - 1;0 <= i; --i) {
    SKTGraphic *graphic = graphics[i];
    [result addObject:[graphic asSVGString]];
  }
  [result addObject:@"</svg>"];
  NSString *s = [result componentsJoinedByString:@"\n"];
  return [s dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)setPrintInfo:(NSPrintInfo *)printInfo {

  // Do the regular Cocoa thing, but also be KVO-compliant for canvasSize, which is derived from the print info.
  [self willChangeValueForKey:SKTDocumentCanvasSizeKey];
  [super setPrintInfo:printInfo];
  [self didChangeValueForKey:SKTDocumentCanvasSizeKey];

}


// This method will only be invoked on Mac 10.4 and later. If you're writing an application that has to run on 10.3.x and earlier you should override -printShowingPrintPanel: instead.
- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {

  // Figure out a title for the print job. It will be used with the .pdf file name extension in a save panel if the user chooses Save As PDF... in the print panel, or in a similar way if the user hits the Preview button in the print panel, or for any number of other uses the printing system might put it to. We don't want the user to see file names like "My Great FloorSketch.floorsketch.pdf", so we can't just use [self displayName], because the document's file name extension might not be hidden. Instead, because we know that all valid FloorSketch documents have file name extensions, get the last path component of the file URL and strip off its file name extension, and use what's left.
  NSString *printJobTitle = [[[[self fileURL] path] lastPathComponent] stringByDeletingPathExtension];
  if (!printJobTitle) {

    // Wait, this document doesn't have a file associated with it. Just use -displayName after all. It will be "Untitled" or "Untitled 2" or something, which is fine.
    printJobTitle = [self displayName];

  }

  // Create a view that will be used just for printing.
  NSSize documentSize = [self canvasSize];
  SKTRenderingView *renderingView = [[SKTRenderingView alloc] initWithFrame:NSMakeRect(0.0, 0.0, documentSize.width, documentSize.height) graphics:[self graphics] printJobTitle:printJobTitle];

  // Create a print operation.
  NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:renderingView printInfo:[self printInfo]];

  // Specify that the print operation can run in a separate thread. This will cause the print progress panel to appear as a sheet on the document window.
  [printOperation setCanSpawnSeparateThread:YES];

  // Set any print settings that might have been specified in a Print Document Apple event. We do it this way because we shouldn't be mutating the result of [self printInfo] here, and using the result of [printOperation printInfo], a copy of the original print info, means we don't have to make yet another temporary copy of [self printInfo].
  [[[printOperation printInfo] dictionary] addEntriesFromDictionary:printSettings];

  // We don't have to autorelease the print operation because +[NSPrintOperation printOperationWithView:printInfo:] of course already autoreleased it. Nothing in this method can fail, so we never return nil, so we don't have to worry about setting *outError.
  return printOperation;

}


- (void)makeWindowControllers {
  // Start off with one document window.
  SKTWindowController *windowController = [[SKTWindowController alloc] init];
  [self addWindowController:windowController];
}

#pragma mark - Undo


- (void)setGraphicProperties:(NSMutableDictionary *)propertiesPerGraphic {
  // The passed-in dictionary is keyed by graphic with values that are dictionaries of properties, keyed by key-value coding key.
  for (SKTWrapper *graphicWrapper in propertiesPerGraphic){
    NSDictionary *graphicProperties = propertiesPerGraphic[graphicWrapper];
    SKTGraphic *graphic = (SKTGraphic *)[graphicWrapper retainedObjectValue];
    // Use a relatively unpopular method. Here we're effectively "casting" a key path to a key (see how these dictionaries get built in -observeValueForKeyPath:ofObject:change:context:). It had better really be a key or things will get confused. For example, this is one of the things that would need updating if -[SKTGraphic keysForValuesToObserveForUndo] someday becomes -[SKTGraphic keyPathsForValuesToObserveForUndo].
    [graphic setValuesForKeysWithDictionary:graphicProperties];
  }
}


- (void)observeUndoManagerCheckpoint:(NSNotification *)notification {
  // Start the coalescing of graphic property changes over.
  _undoGroupHasChangesToMultipleProperties = NO;
  _undoGroupPresentablePropertyName = nil;
  _undoGroupOldPropertiesPerGraphic = nil;
  _undoGroupInsertedGraphics = nil;

}


- (void)startObservingGraphics:(NSArray *)graphics {
  // Each graphic can have a different set of properties that need to be observed.
  NSUInteger graphicCount = [graphics count];
  for (NSUInteger index = 0; index < graphicCount; index++) {
    SKTGraphic *graphic = graphics[index];
    NSSet *keys = [graphic keysForValuesToObserveForUndo];
    NSEnumerator *keyEnumerator = [keys objectEnumerator];
    NSString *key;
    while (key = [keyEnumerator nextObject]) {
      // We use NSKeyValueObservingOptionOld because when something changes we want to record the old value, which is what has to be set in the undo operation. We use NSKeyValueObservingOptionNew because we compare the new value against the old value in an attempt to ignore changes that aren't really changes.
      [graphic addObserver:self forKeyPath:key options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:SKTDocumentUndoObservationContext];
    }

    // The set of properties to be observed can itself change.
    [graphic addObserver:self forKeyPath:SKTGraphicKeysForValuesToObserveForUndoKey options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:SKTDocumentUndoKeysObservationContext];

  }

}


- (void)stopObservingGraphics:(NSArray *)graphics {

  // Do the opposite of what's done in -startObservingGraphics:.
  NSUInteger graphicCount = [graphics count];
  for (NSUInteger index = 0; index < graphicCount; index++) {
    SKTGraphic *graphic = graphics[index];
    [graphic removeObserver:self forKeyPath:SKTGraphicKeysForValuesToObserveForUndoKey];
    NSSet *keys = [graphic keysForValuesToObserveForUndo];
    NSEnumerator *keyEnumerator = [keys objectEnumerator];
    NSString *key;
    while (key = [keyEnumerator nextObject]) {
      [graphic removeObserver:self forKeyPath:key];
    }
  }
}


// An override of the NSObject(NSKeyValueObserving) method.
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(NSObject *)observedObject change:(NSDictionary *)change context:(void *)context {

  // Make sure we don't intercept an observer notification that's meant for NSDocument. In Mac OS 10.5 and earlier NSDocuments don't observe anything, but that could change in the future. We can do a simple pointer comparison because KVO doesn't do anything at all with the context value, not even retain or copy it.
  if (context == SKTDocumentUndoKeysObservationContext) {

    // The set of properties that we should be observing has changed for some graphic. Stop or start observing.
    NSSet *oldKeys = change[NSKeyValueChangeOldKey];
    NSSet *newKeys = change[NSKeyValueChangeNewKey];
    NSString *key;
    NSEnumerator *oldKeyEnumerator = [oldKeys objectEnumerator];
    while (key = [oldKeyEnumerator nextObject]) {
      if (![newKeys containsObject:key]) {
        [observedObject removeObserver:self forKeyPath:key];
      }
    }
    NSEnumerator *newKeyEnumerator = [newKeys objectEnumerator];
    while (key = [newKeyEnumerator nextObject]) {
      if (![oldKeys containsObject:key]) {
        [observedObject addObserver:self forKeyPath:key options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:SKTDocumentUndoObservationContext];
      }
    }

  } else if (context == SKTDocumentUndoObservationContext) {

    // The value of some graphic's property has changed. Don't waste memory by recording undo operations affecting graphics that would be removed during undo anyway. In FloorSketch this check matters when you use a creation tool to create a new graphic and then drag the mouse to resize it; there's no reason to record a change of "bounds" in that situation.
    SKTGraphic *graphic = (SKTGraphic *)observedObject;
    if (![_undoGroupInsertedGraphics containsObject:graphic]) {

      // Ignore changes that aren't really changes. Now that Sketch's inspector panel allows you to change a property of all selected graphics at once (it didn't always, as recently as the version that appears in Mac OS 10.4's /Developer/Examples/AppKit), it's easy for the user to cause a big batch of SKTGraphics to be sent -setValue:forKeyPath: messages that don't do anything useful. Try this simple example: create 10 ellipses, and set all but one to be filled. Select them all. In the inspector panel the Fill checkbox will show the mixed state indicator (a dash). Click on it. Cocoa's bindings machinery sends [theEllipse setValue:[NSNumber numberWithBOOL:YES] forKeyPath:SKTGraphicIsDrawingFillKey] to each selected ellipse. KVO faithfully notifies this SKTDocument, which is observing all of its graphics, for each ellipse object, even though the old value of the SKTGraphicIsDrawingFillKey property for 9 out of the 10 ellipses was already YES. If we didn't actively filter out useless notifications like these we would be wasting memory by recording undo operations that don't actually do anything.
      // How much processor time does this memory optimization cost? We don't know, because we haven't measured it. The use of NSKeyValueObservingOptionNew in -startObservingGraphics:, which makes NSKeyValueChangeNewKey entries appear in change dictionaries, definitely costs something when KVO notifications are sent (it costs virtually nothing at observer registration time). Regardless, it's probably a good idea to do simple memory optimizations like this as they're discovered and debug just enough to confirm that they're saving the expected memory (and not introducing bugs). Later on it will be easier to test for good responsiveness and sample to hunt down processor time problems than it will be to figure out where all the darn memory went when your app turns out to be notably RAM-hungry (and therefore slowing down _other_ apps on your user's computers too, if the problem is bad enough to cause paging).
      // Is this a premature optimization? No. Leaving out this very simple check, because we're worried about the processor time cost of using NSKeyValueChangeNewKey, would be a premature optimization.
      id newValue = change[NSKeyValueChangeNewKey];
      id oldValue = change[NSKeyValueChangeOldKey];
      if (![newValue isEqualTo:oldValue]) {

        // Is this the first observed graphic change in the current undo group?
        NSUndoManager *undoManager = [self undoManager];
        if (!_undoGroupOldPropertiesPerGraphic) {

          // We haven't recorded changes for any graphics at all since the last undo manager checkpoint. Get ready to start collecting them.
          _undoGroupOldPropertiesPerGraphic = [[NSMutableDictionary alloc] init];

          // Register an undo operation for any graphic property changes that are going to be coalesced between now and the next invocation of -observeUndoManagerCheckpoint:.
          [undoManager registerUndoWithTarget:self selector:@selector(setGraphicProperties:) object:_undoGroupOldPropertiesPerGraphic];

        }

        // Find the dictionary in which we're recording the old values of properties for the changed graphic.
        SKTWrapper *wrappedGraphic = [SKTWrapper wrap:graphic];
        NSMutableDictionary *oldGraphicProperties = _undoGroupOldPropertiesPerGraphic[wrappedGraphic];
        if (!oldGraphicProperties) {

          // We have to create a dictionary to hold old values for the changed graphic. -[NSMutableDictionary setObject:forKey:] always makes a copy of the key object, but we don't want to make copies of SKTGraphics here, so we use SKTWrapper.
          oldGraphicProperties = [[NSMutableDictionary alloc] init];
          _undoGroupOldPropertiesPerGraphic[wrappedGraphic] = oldGraphicProperties;

        }

        // Record the old value for the changed property, unless an older value has already been recorded for the current undo group. Here we're "casting" a KVC key path to a dictionary key, but that should be OK. -[NSMutableDictionary setObject:forKey:] doesn't know the difference.
        if (!oldGraphicProperties[keyPath]) {
          oldGraphicProperties[keyPath] = oldValue;
        }

        // Don't set the undo action name during undoing and redoing. In FloorSketch, SKTGraphicView sometimes overwrites whatever action name we set up here with something more specific (as in, "Move" or "Resize" instead of "Change of Bounds"), but only during the building of the original undo action. During undoing and redoing SKTGraphicView doesn't get a chance to do that desirable overwriting again. Just leave the action name alone during undoing and redoing and the action name from the original undo group will continue to be used.
        if (![undoManager isUndoing] && ![undoManager isRedoing]) {

          // What's the human-readable name of the property that's just been changed? Here we're effectively "casting" a key path to a key. It had better really be a key or things will get confused. For example, this is one of the things that would need updating if -[SKTGraphic keysForValuesToObserveForUndo] someday becomes -[SKTGraphic keyPathsForValuesToObserveForUndo].
          Class graphicClass = [graphic class];
          NSString *presentablePropertyName = [graphicClass presentablePropertyNameForKey:keyPath];
          if (!presentablePropertyName) {

            // Someone overrode -[SKTGraphic keysForValuesToObserveForUndo] but didn't override +[SKTGraphic presentablePropertyNameForKey:] to match. Help debug a little. Hopefully the SKTGraphic public interface makes it so that you only have to test a little bit to find bugs like this.
            NSString *graphicClassName = NSStringFromClass(graphicClass);
            [NSException raise:NSInternalInconsistencyException format:@"[[%@ class] keysForValuesToObserveForUndo] returns a set that includes @\"%@\", but [[%@ class] presentablePropertyNameForKey:@\"%@\"] returns nil.", graphicClassName, keyPath, graphicClassName, keyPath];

          }

          // Have we set an action name for the current undo group yet?
          if (_undoGroupPresentablePropertyName || _undoGroupHasChangesToMultipleProperties) {

            // Yes. Have we already determined that we have to use a generic undo action name, and set it? If so, there's nothing to do.
            if (!_undoGroupHasChangesToMultipleProperties) {

              // So far we've set an action name for the current undo group that mentions a specific property. Is the property that's just been changed the same one mentioned in that action name (regardless of which graphic has been changed)? If so, there's nothing to do.
              if (![_undoGroupPresentablePropertyName isEqualToString:presentablePropertyName]) {

                // The undo action is going to restore the old values of different properties. Set a generic undo action name and record the fact that we've done so.
                [undoManager setActionName:NSLocalizedStringFromTable(@"Change of Multiple Graphic Properties", @"UndoStrings", @"Generic action name for complex graphic property changes.")];
                _undoGroupHasChangesToMultipleProperties = YES;

                // This is useless now.
                _undoGroupPresentablePropertyName = nil;
              }
            }
          } else {

            // So far the action of the current undo group is going to be the restoration of the value of one property. Set a specific undo action name and record the fact that we've done so.
            [undoManager setActionName:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Change of %@", @"UndoStrings", @"Specific action name for simple graphic property changes. The argument is the name of a property."), presentablePropertyName]];
            _undoGroupPresentablePropertyName = [presentablePropertyName copy];

          }
        }
      }
    }
  } else {
    // In overrides of -observeValueForKeyPath:ofObject:change:context: always invoke super when the observer notification isn't recognized. Code in the superclass is apparently doing observation of its own. NSObject's implementation of this method throws an exception. Such an exception would be indicating a programming error that should be fixed.
    [super observeValueForKeyPath:keyPath ofObject:observedObject change:change context:context];
  }
}


#pragma mark - Scripting

// given an array of objects that presumably came from the graphics array.
- (void)setSelectionFromArray:(NSArray *)array {
  NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
  for (SKTGraphic *graphic in array) {
    NSUInteger index = [_graphics indexOfObject:graphic];
    if (NSNotFound != index) {
      [indexSet addIndex:index];
    }
  }
  if (1 < [indexSet count]) {
    SKTWindowController *controller = (SKTWindowController *)self.windowControllers.firstObject;
    NSArrayController *graphicsController = [controller valueForKey:@"graphicsController"];
    [graphicsController setSelectionIndexes:indexSet];
  }
}

- (SKTGraphicView *)primaryGraphicsView {
  SKTWindowController *controller = (SKTWindowController *)self.windowControllers.firstObject;
  return (SKTGraphicView *)[controller valueForKey:@"graphicView"];
}

- (void)alignBottomEdgesOfGraphics:(NSArray *)array {
  [self setSelectionFromArray:array];
  [[self primaryGraphicsView] alignBottomEdges:nil];
}

- (void)alignHorizontalCentersOfGraphics:(NSArray *)array {
  [self setSelectionFromArray:array];
  [[self primaryGraphicsView] alignHorizontalCenters:nil];
}

- (void)alignLeftEdgesOfGraphics:(NSArray *)array {
  [self setSelectionFromArray:array];
  [[self primaryGraphicsView] alignLeftEdges:nil];
}

- (void)alignRightEdgesOfGraphics:(NSArray *)array {
  [self setSelectionFromArray:array];
  [[self primaryGraphicsView] alignRightEdges:nil];
}

- (void)alignTopEdgesOfGraphics:(NSArray *)array {
  [self setSelectionFromArray:array];
  [[self primaryGraphicsView] alignTopEdges:nil];
}

- (void)alignVerticalCentersOfGraphics:(NSArray *)array {
  [self setSelectionFromArray:array];
  [[self primaryGraphicsView] alignVerticalCenters:nil];
}


- (void)addObjectsFromArrayToUndoGroupInsertedGraphics:(NSArray *)graphics {
  if (_undoGroupInsertedGraphics) {
    [_undoGroupInsertedGraphics addObjectsFromArray:graphics];
  } else {
    _undoGroupInsertedGraphics = [[NSMutableSet alloc] initWithArray:graphics];
  }
}


// An override of the NSObject(NSScripting) method. It will only be invoked on Mac OS 10.5 and later.
- (id)newScriptingObjectOfClass:(Class)objectClass forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {

  // "make new graphic" makes no sense because it's an abstract class. Use a default concrete class instead.
  if (objectClass==[SKTGraphic class]) {
    objectClass = [SKTEllipse class];
  }
  return [super newScriptingObjectOfClass:objectClass forValueForKey:key withContentsValue:contentsValue properties:properties];
}

@end
