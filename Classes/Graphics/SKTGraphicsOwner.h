/*  SKTGraphicsOwner.h
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/


#import <Cocoa/Cocoa.h>

// We don't have multiple inheritance in Obj-C, and there's much in common between SKTDocument and SKTGroup.
// So, we cast self to id<SKTGraphicsOwner> in a category on NSObject to implement the common code.
// This advantage of this is it makes any NSObject look like it will respond to these methods, but we'll get runtime crashes when
// the code tries to execute a protocol method on an object that doesn't actualy support the protocol.
//
// I could have just copied the code, but that seems error-prone.

@class SKTGraphic;

@protocol SKTGraphicsOwner<NSObject>
@property(nonatomic) NSMutableArray *graphics;
@property(readonly) CGFloat handleWidth;
- (void)addObjectsFromArrayToUndoGroupInsertedGraphics:(NSArray *)graphic;
- (NSUndoManager *)undoManager;
- (NSScriptObjectSpecifier *)objectSpecifier;
- (void)startObservingGraphics:(NSArray *)graphics;
- (void)stopObservingGraphics:(NSArray *)graphics;

@optional
// the drawing bounds of the graphic, potentially outset if we are drawing the resize handles.
- (NSRect)handleDrawingBoundsOfGraphic:(SKTGraphic *)graphic;

- (BOOL)isInSelectionSet:(NSUInteger)index;
- (BOOL)isBeingCreateOrEdited:(SKTGraphic *)graphic;
- (BOOL)isHidingHandles;
- (void)drawGraphics:(NSArray<SKTGraphic *> *)graphics view:(NSView *)view rect:(NSRect)rect;
@end

@interface NSObject(SKTGraphicsOwner)
- (NSArray *)graphicsWithClass:(Class)theClass;
- (NSArray *)ellipses;
- (NSArray *)images;
- (NSArray *)lines;
- (NSArray *)groups;
- (NSArray *)paths;
- (NSArray *)polygons;
- (NSArray *)rectangles;
- (NSArray *)textAreas;
- (NSScriptObjectSpecifier *)objectSpecifierForGraphic:(SKTGraphic *)graphic;
- (void)insertGraphics:(NSArray *)graphics atIndexes:(NSIndexSet *)indexes;
- (void)removeGraphicsAtIndexes:(NSIndexSet *)indexes;
- (void)insertGraphic:(SKTGraphic *)graphic atIndex:(NSUInteger)index;
- (void)removeGraphicAtIndex:(NSUInteger)index;
- (void)addInGraphics:(SKTGraphic *)graphic;
- (void)insertObject:(SKTGraphic *)graphic inRectanglesAtIndex:(NSUInteger)index;
- (void)removeObjectFromRectanglesAtIndex:(NSUInteger)index;
- (void)insertObject:(SKTGraphic *)graphic inEllipsesAtIndex:(NSUInteger)index;
- (void)removeObjectFromEllipsesAtIndex:(NSUInteger)index;
- (void)insertObject:(SKTGraphic *)graphic inLinesAtIndex:(NSUInteger)index;
- (void)removeObjectFromLinesAtIndex:(NSUInteger)index;
- (void)insertObject:(SKTGraphic *)graphic inTextAreasAtIndex:(NSUInteger)index;
- (void)removeObjectFromTextAreasAtIndex:(NSUInteger)index;
- (void)insertObject:(SKTGraphic *)graphic inImagesAtIndex:(NSUInteger)index;
- (void)removeObjectFromImagesAtIndex:(NSUInteger)index;
- (NSArray *)indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)rangeSpec;
- (NSArray *)indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)relSpec;
- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier;
@end
