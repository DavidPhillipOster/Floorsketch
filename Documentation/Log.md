#  FloorSketch

## Log
12/09/2021 - Fixed: read in rhino from inkscape. came in OK, but ignored display:none attribute.
  display:none - means hide. display:inline - means show.
  visiblity:hidden | collapse
6/10/2021 - qrcode.svg : a transform attribute on an element is ignored
3/02/2021 - save as SVG fixes: images, default colors.
3/01/2021 - 420 NW 11th Ave #918.svg first reading an image (from SVG). Fix SVG bug where group contents were added twice.
2/21/2021 SVG parser wasn't handling implicit verbs correctly. Fixed.
2/06/2021 Zoom in and out on the View menu.
Moved handle size out of SKTGraphic to allow for scaling the handles opposite the view scaling in the future.
Fixed bug in Path now that I know that a path can have multiple closed segments.
2/05/2021 Reading and writing native and SVG documents that came from Inkscape.
2/03/2021 Resizing groups by dragging any of the selection handles works. Even for groups of grpups.
Create polylines by clicking with the mouse. Double-click or any key to end the polyline. Menu command to close.
1/30/2021 Only allow grouping if all are locked or all unlocked. Allow opening and closing polygons. Rectangles convert to polygons when opened.
Beginnings of path parsing and unparsing. done: polygons. still to do: most of the splines and arcs.
1/29/2021 Groups: read, draw, select, move, stretch, menu commands ot group and ungroup.  (Path are still not handled.)
1/28/2021 Tools now has a node-arrow, an exterior, a room, a wall. 
SKTSelectionStyle now gives a choice between node select and object select.
windows, doors will come later.
All those tools need work.
1/27/2021 used genstrings to create the en.lproj/xxx.strings file.
1/26/2021 begun. FIxed bug where SVG line was being exported improperly.

## TODO
qrcode.svg : a transform attribute on an element is ignored
If multiple items are selected, and you drag a resize handle, only one resizes. See group setBounds.
arc needs work. image position and size?
setting the x posiition of a path or group form aplescript does not move it.
grouping or ungtouping from applescript.
Document should default to landcape mode.
Document should default to grid on.
Tool palette: cursor, node cursor, exterior wall, room, interior wall, window/door, Text

## BUGS
• SVG Paths can contain multiple NSBezierPaths. whiteHouse.svg is an example. These don't come in correctly..
  • Hollow circle is a simple example. It has two subpaths, but only one is in the SVGPath array of atoms, and the fill color got set to nil partway through the parse.
• Drag handles should scale: they are too big to grab at small scales.
• Handle the 'trasform' attribute.
• move down/move up in stacking order.
• inspector doesn't operate on groups.
• Undo Group gets the selection wrong.

## Wishlist

• import a scalable underlay, grayed out, that you can draw over, and choose to delete.
• a palette floating room names that you can drag in an edit to save typing.
• manual size, auto size, and orange and red for room sizes?
• a fuzzy notion of a room, that is refined as interior walls are added.
• a notion of a "wall" interior walls have flippable doorways that have a default size. Exterior walls have windows.
• walls are sticky to the walls they abut.
File fomat:
SVG but doors are SVG lines with fs:class = "door", windows fs:class = "window" in relative coordiantes to the wall they are in,  interior walls : fs:class = "interior",
 are paths, in a group with the windows and doors they belong to.
  exterior walls are paths fs:class = "exterior" and they 
  rooms are closed paths, fs:class = "room" with a list of comma separated IDs of the walls they abut.
  Walls, also comma separateed.
  
? When reading an SVG, record attributes that this app doesn't understand and write them back out again

## Lessons learned

I made the document icon with 

```
iconutil -c icns DocIcon.iconset
```

I used  `genstrings`  to generate the .strings files.

```
cd Classes/
genstrings -a -o ../Resources *.m */*.m
```

https://developer.apple.com/documentation/appkit/nsdocumentcontroller/1514937-displaynamefortype?language=objc
describes how to add file types to the SaveAs dialog by editing the Info.plist.


