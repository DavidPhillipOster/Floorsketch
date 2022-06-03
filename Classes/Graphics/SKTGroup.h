/*  SKTGroup.m
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTGraphic.h"

// Implements the Group/ungroup command. Represent as an SVG <g> eleement
@interface SKTGroup : SKTGraphic
@property(nonatomic) NSMutableArray *graphics;

// Given an array of graphics that had been in a document, remove them from the document,
// insert a new group with those contents into the document at the index of the last one.
+ (instancetype)groupWithGraphics:(NSArray *)graphics;

// remove itself from the owning document, putting its contents into the document.
- (NSArray *)ungroupInsertedContents;

// Reader tells group to update.
- (void)updateBounds;

@end
