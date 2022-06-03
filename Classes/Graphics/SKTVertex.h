/*  SKTVertex.h
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import <Cocoa/Cocoa.h>

typedef enum SKTVertexKind {
  SKTVertexKindSimple = 0,
  SKTVertexKindQuadratic = 1,
  SKTVertexKindCubic = 2,
  SKTVertexKindQuadraticControl = 3,
  SKTVertexKindCubicControl = 4,
} SKTVertexKind;

// Represents a vertex for scripting. It holds a weak pointer to its parent and an index. The setters for x and y inform the parent that it should change. The 'Kind' allows us to talk about verticies of paths.
// TODO: allow a scripting interface to the vertices of a Path
@interface SKTVertex : NSObject
@property(nonatomic) SKTVertexKind kind;
@property(nonatomic) CGFloat xPosition;
@property(nonatomic) CGFloat yPosition;
@property(nonatomic) NSUInteger index;
  // The object that contains the vertex (unretained), from the point of view of scriptability. This is here only for use by this class' override of scripting's -objectSpecifier method. In FloorSketch this is an SKTPoly or SKTPath.
@property(nonatomic, weak) NSObject *scriptingContainer;

- (void)setScriptingContainer:(NSObject *)scriptingContainer;

@end

@interface NSObject(SKTVertexScriptingContainer)

// An informal protocol to which scriptable containers of SKTGraphics must conform. We declare this instead of just making it an SKTPoly method because that would needlessly reduce SKTVertex reusability (they would only be containable by SKTPoly).
- (NSScriptObjectSpecifier *)objectSpecifierForVertex:(SKTVertex *)vertex;

@end
