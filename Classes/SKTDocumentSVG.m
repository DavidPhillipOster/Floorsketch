/*  SKTDocumentSVG.m
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/
#import "SKTDocumentSVG.h"

#import "GDataXMLNode.h"
#import "NSArray_SKT.h"
#import "NSColor_SKT.h"
#import "SKTEllipse.h"
#import "SKTGroup.h"
#import "SKTImage.h"
#import "SKTLine.h"
#import "SKTPath.h"
#import "SKTPoly.h"
#import "SKTRectangle.h"
#import "SKTText.h"



@interface GDataXMLNode(SVG)
- (CGFloat)svgFloatValue;
@end
@implementation GDataXMLNode(SVG)
- (CGFloat)svgFloatValue {
  float result = 0;
  NSScanner *scanner = [[NSScanner alloc] initWithString:[self stringValue]];
  [scanner scanFloat:&result];
  return result;
}
@end

static NSImage *imageFromBase64String(NSString *base64) {
  NSData *data = [[NSData alloc] initWithBase64EncodedString:base64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
  if (data) {
    return [[NSImage alloc] initWithData:data];
  }
  return nil;
}


static NSColor *SVGColorFromString(NSString *s) {
  NSColor *result = nil;
  if ([s hasPrefix:@"#"]) {
    if ([s length] == 4) {
      int red, green, blue;
      int count = sscanf([s UTF8String], "#%01x%01x%01x", &red, &green, &blue);
      result = [NSColor colorWithCalibratedRed:red/15. green:green/15. blue:blue/15. alpha:1];
      if (count != 3) {
        NSLog(@"%d", count);
      }
    } else if ([s length] == 7) {
      int red, green, blue;
      int count = sscanf([s UTF8String], "#%02x%02x%02x", &red, &green, &blue);
      result = [NSColor colorWithCalibratedRed:red/255. green:green/255. blue:blue/255. alpha:1];
      if (count != 3) {
        NSLog(@"%d", count);
      }
    }
  } else if ([s isEqual:@"black"]) {
    return [NSColor blackColor];
  } else if([s isEqual:@"white"]) {
    return [NSColor whiteColor];
  } else if ([s isEqual:@"red"]) {
    return [NSColor redColor];
  } else if([s isEqual:@"green"]) {
    return [NSColor greenColor];
  } else if([s isEqual:@"blue"]) {
    return [NSColor blueColor];
  } else if([s hasPrefix:@"rgb"]) {
    NSScanner *scanner = [[NSScanner alloc] initWithString:s];
    [scanner scanString:@"rgb" intoString:NULL];
    float red, green, blue;
    NSInteger redDenom = 255, greenDenom = 255, blueDenom = 255;
    if ( [scanner scanString:@"(" intoString:NULL] && [scanner scanFloat:&red]) {
      if ([scanner scanString:@"%" intoString:NULL]) {
        redDenom = 100;
      }
      if ( [scanner scanString:@"," intoString:NULL] && [scanner scanFloat:&green]) {
        if ([scanner scanString:@"%" intoString:NULL]) {
          greenDenom = 100;
        }
        if ( [scanner scanString:@"," intoString:NULL] && [scanner scanFloat:&blue]) {
          if ([scanner scanString:@"%" intoString:NULL]) {
            blueDenom = 100;
          }
          if ( [scanner scanString:@")" intoString:NULL]) {
            result = [NSColor colorWithCalibratedRed:red/redDenom green:green/greenDenom blue:blue/blueDenom alpha:1];
          }
        }
      }
    }
  }
  return result;
}

// If they specified a color but an opacity of 0.0, then just turn off drawing of the fill or the stroke.
static void AdjustOpacity(NSMutableDictionary *dict, NSString *hasColorKey, NSString *colorKey, CGFloat alpha) {
  if (0.0 <= alpha && alpha < 1) {
    NSColor *c = [NSColor colorWithArchiveData:dict[colorKey]];
    if (c) {
      dict[colorKey] = [c colorWithAlphaComponent:alpha];
    }
  } else if (0.0 == alpha) {
    [dict removeObjectForKey:colorKey];
    [dict removeObjectForKey:hasColorKey];
  }
}

static void ColorValue(NSString *value, NSMutableDictionary * dict, NSString *hasColorKey, NSString *colorKey) {
  if ([value length] && ! [value isEqual:@"none"]) {
    NSColor *c = SVGColorFromString(value);
    if (c) {
      dict[hasColorKey] = @YES;
      dict[colorKey] = [c asArchiveData];
    }
  }
}

// Convert a string to a positive floating point number. Returns -1 on failure.
static float PositiveFloatValue(NSString *value) {
  if ([value length]) {
    NSScanner *number = [[NSScanner alloc] initWithString:value];
    float n;
    if ([number scanFloat:&n] && 0.0 <= n) {
      return n;
    }
  }
  return -1;
}

// TODO: this should loop over the attributes, looking each one up. Not do multiple linear searches.
static NSMutableDictionary *StylePropertiesFromAttributes(GDataXMLElement *element) {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  NSString *s;
  float n;
  CGFloat strokeOpacity = 1;
  CGFloat fillOpacity = 1;
  s = [[element attributeForName:@"fill"] stringValue];
  ColorValue(s, result, SKTGraphicIsDrawingFillKey, SKTGraphicFillColorKey);
  s = [[element attributeForName:@"stroke"] stringValue];
  ColorValue(s, result, SKTGraphicIsDrawingStrokeKey, SKTGraphicStrokeColorKey);
  if (0 <= (n = PositiveFloatValue([[element attributeForName:@"stroke-width"] stringValue]))) {
    result[SKTGraphicStrokeWidthKey] = @(n);
  }
  if (0 <= (n = PositiveFloatValue([[element attributeForName:@"fill-opacity"] stringValue])) && n <= 1) {
    fillOpacity = n;
  }
  if (0 <= (n = PositiveFloatValue([[element attributeForName:@"stroke-opacity"] stringValue])) && n <= 1) {
    strokeOpacity = n;
  }
  s = [[element attributeForName:@"transform"] stringValue];
  if ([s length]) {
    NSLog(@"\n'%@' transform attribute ignored. TODO: fix this.", element.name);
  }
  s = [[element attributeForName:@"style"] stringValue];
  if ([s length]) {
    NSScanner *clause = [[NSScanner alloc] initWithString:s];
    NSMutableCharacterSet *keyChars = [NSMutableCharacterSet alphanumericCharacterSet];
    [keyChars addCharactersInString:@"-+_"];
    while ( ! [clause isAtEnd]) {
      NSString *key;
      NSString *value;
      if ( ! [clause scanCharactersFromSet:keyChars intoString:&key]) {
        break;
      }
      if (! [clause scanString:@":" intoString:NULL]) {
        break;
      }
      if (! [clause scanUpToString:@";" intoString:&value]) {
        break;
      }
      [clause scanString:@";" intoString:NULL];
      if ([key isEqual:@"fill"]) {
        ColorValue(value, result, SKTGraphicIsDrawingFillKey, SKTGraphicFillColorKey);
      } else if ([key isEqual:@"stroke"]) {
        ColorValue(value, result, SKTGraphicIsDrawingStrokeKey, SKTGraphicStrokeColorKey);
      } else if ([key isEqual:@"stroke-width"] && 0 <= (n = PositiveFloatValue(value))) {
        result[SKTGraphicStrokeWidthKey] = @(n);
      } else if ([key isEqual:@"fill-opacity"] && 0 <= (n = PositiveFloatValue(value)) && n <= 1) {
        fillOpacity = n;
      } else if ([key isEqual:@"stroke-opacity"] && 0 <= (n = PositiveFloatValue(value)) && n <= 1) {
        strokeOpacity = n;
      } else if ([key isEqual:@"display"]) {
        if ([value isEqual:@"none"]) {
          strokeOpacity = fillOpacity = 0;
        }
      } else if ([key isEqual:@"visibility"]) {
        if ([value isEqual:@"hidden"] || [value isEqual:@"collapse"]) {
          strokeOpacity = fillOpacity = 0;
        }
      }
    }
    AdjustOpacity(result, SKTGraphicIsDrawingFillKey, SKTGraphicFillColorKey, fillOpacity);
    AdjustOpacity(result, SKTGraphicIsDrawingStrokeKey, SKTGraphicStrokeColorKey, strokeOpacity);
  }
  return result;
}

static NSDictionary *CirclePropertiesOfElement(GDataXMLElement *element) {
  CGFloat cx = [[element attributeForName:@"cx"] svgFloatValue];
  CGFloat cy = [[element attributeForName:@"cy"] svgFloatValue];
  CGFloat r = [[element attributeForName:@"r"] svgFloatValue];
  if (r <= 0) {
    return nil;
  }
  NSMutableDictionary *result = StylePropertiesFromAttributes(element);
  CGRect bounds = CGRectMake(cx - r, cy - r, r*2, r*2);
  result[SKTGraphicBoundsKey] = NSStringFromRect(bounds);
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfCircle(GDataXMLElement *element) {
  NSDictionary *props = CirclePropertiesOfElement(element);
  id result = [[SKTEllipse alloc] initWithProperties:props];
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfDesc(GDataXMLElement *element) {
  id result = @NO;
  return result;
}

static NSDictionary *EllipsePropertiesOfElement(GDataXMLElement *element) {
  CGFloat cx = [[element attributeForName:@"cx"] svgFloatValue];
  CGFloat cy = [[element attributeForName:@"cy"] svgFloatValue];
  CGFloat rx = [[element attributeForName:@"rx"] svgFloatValue];
  CGFloat ry = [[element attributeForName:@"ry"] svgFloatValue];
  if (rx <= 0 || ry <= 0) {
    return nil;
  }
  NSMutableDictionary *result = StylePropertiesFromAttributes(element);
  CGRect bounds = CGRectMake(cx - rx, cy - ry, rx*2, ry*2);
  result[SKTGraphicBoundsKey] = NSStringFromRect(bounds);
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfEllipse(GDataXMLElement *element) {
  NSDictionary *props = EllipsePropertiesOfElement(element);
  id result = [[SKTEllipse alloc] initWithProperties:props];
  return result;
}

static NSDictionary *GroupPropertiesOfElement(GDataXMLElement *element) {
  NSMutableDictionary *result = StylePropertiesFromAttributes(element);
  // TODO: more here: GroupPropertiesOfElement
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfGroup(GDataXMLElement *element) {
  NSDictionary *props = GroupPropertiesOfElement(element);
  SKTGroup *result = [[SKTGroup alloc] initWithProperties:props];
  [result setGraphics:[SKTDocument graphicsFromContainer:element error:NULL]];

  return result;
}

static NSDictionary *ImagePropertiesOfElement(GDataXMLElement *element) {
  NSMutableDictionary *result = StylePropertiesFromAttributes(element);
  NSString *s = [[element attributeForName:@"width"] stringValue];
  if (s.length) {
    CGFloat width = [s floatValue];
    result[SKTGraphicWidthKey] = @(width);
  }
  s = [[element attributeForName:@"height"] stringValue];
  if (s.length) {
    CGFloat height = [s floatValue];
    result[SKTGraphicHeightKey] = @(height);
  }
  s = [[element attributeForName:@"xlink:href"] stringValue];
  if (s.length) {
    if ([s hasPrefix:@"data:"]) {
      static NSString *const jpegHeader = @"data:image/jpeg;base64,";
      static NSString *const pngHeader = @"data:image/png;base64,";
      NSImage *image = nil;
      if ([s hasPrefix:jpegHeader]) {
        image = imageFromBase64String([s substringFromIndex:[jpegHeader length]]);
      } else if ([s hasPrefix:pngHeader]) {
        image = imageFromBase64String([s substringFromIndex:[pngHeader length]]);
      }
      if (image) {
        NSData *d = [NSArchiver archivedDataWithRootObject:image];
        result[SKTImageContentsKey] = d;
      } else {
        NSLog(@"missing: interpreter for URLs of the form 'data:image/jpeg;base64,'");
      }
    } else {
        NSLog(@"missing: interpreter non-data URLs");
    }
  }
  // TODO: more here: ImagePropertiesOfElement @"preserveAspectRatio"
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfImage(GDataXMLElement *element) {
  NSDictionary *props = ImagePropertiesOfElement(element);
  SKTImage *result = [[SKTImage alloc] initWithProperties:props];
  return result;
}

static NSDictionary *LinePropertiesOfElement(GDataXMLElement *element) {
  CGFloat x = [[element attributeForName:@"x1"] svgFloatValue];
  CGFloat y = [[element attributeForName:@"y1"] svgFloatValue];
  CGFloat x2 = [[element attributeForName:@"x2"] svgFloatValue];
  CGFloat y2 = [[element attributeForName:@"y2"] svgFloatValue];
  NSMutableDictionary *result = StylePropertiesFromAttributes(element);
  result[SKTLineBeginPointKey] = NSStringFromPoint(CGPointMake(x, y));
  result[SKTLineEndPointKey] = NSStringFromPoint(CGPointMake(x2, y2));
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfLine(GDataXMLElement *element) {
  NSDictionary *props = LinePropertiesOfElement(element);
  id result = [[SKTLine alloc] initWithProperties:props];
  return result;
}

static NSMutableDictionary *PathPropertiesOfElement(GDataXMLElement *element) {
  NSMutableDictionary *result = StylePropertiesFromAttributes(element);
  NSString *s = [[element attributeForName:@"d"] stringValue];
  if ([s respondsToSelector:@selector(characterAtIndex:)]) {
    result[SKTPathString] = s;
  }
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfPath(GDataXMLElement *element) {
  NSMutableDictionary *props = PathPropertiesOfElement(element);
  id result = [[SKTPath alloc] initWithProperties:props];
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfPattern(GDataXMLElement *element) {
  id result = @NO;
  return result;
}

static NSMutableDictionary *PolyPropertiesOfElement(GDataXMLElement *element) {
  NSMutableDictionary *result = StylePropertiesFromAttributes(element);
  result[SKTPolyPoints] = [[element attributeForName:@"points"] stringValue];
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfPolygon(GDataXMLElement *element) {
  NSMutableDictionary *props = PolyPropertiesOfElement(element);
  props[SKTGraphicClosed] = @YES;
  SKTPoly *result = [[SKTPoly alloc] initWithProperties:props];
  if (nil == result.strokeColor) {
    [result setValue:NSColor.blackColor forKey:@"strokeColor"];
  }
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfPolyline(GDataXMLElement *element) {
  NSDictionary *props = PolyPropertiesOfElement(element);
  SKTPoly *result = [[SKTPoly alloc] initWithProperties:props];
  if (nil == result.strokeColor) {
    [result setValue:NSColor.blackColor forKey:@"strokeColor"];
  }
  return result;
}

static NSDictionary *RectPropertiesOfElement(GDataXMLElement *element) {
  CGFloat x = [[element attributeForName:@"x"] svgFloatValue];
  CGFloat y = [[element attributeForName:@"y"] svgFloatValue];
  CGFloat width = [[element attributeForName:@"width"] svgFloatValue];
  CGFloat height = [[element attributeForName:@"height"] svgFloatValue];
  if (width <= 0  || height <= 0) {
    return nil;
  }
  NSMutableDictionary *result = StylePropertiesFromAttributes(element);
  CGRect bounds = CGRectMake(x, y, width, height);
  result[SKTGraphicBoundsKey] = NSStringFromRect(bounds);
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfRect(GDataXMLElement *element) {
  NSDictionary *props = RectPropertiesOfElement(element);
  id result = [[SKTRectangle alloc] initWithProperties:props];
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfStyle(GDataXMLElement *element) {
  id result = @NO;
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfSymbol(GDataXMLElement *element) {
  id result = @NO;
  return result;
}

static NSDictionary *TextPropertiesOfElement(GDataXMLElement *element) {
  CGFloat x = [[element attributeForName:@"x"] svgFloatValue];
  CGFloat y = [[element attributeForName:@"y"] svgFloatValue];
  CGFloat width = [[element attributeForName:@"width"] svgFloatValue];
  CGFloat height = [[element attributeForName:@"height"] svgFloatValue];
  NSMutableDictionary *result = StylePropertiesFromAttributes(element);
  CGRect bounds = CGRectMake(x, y, width, height);
  result[SKTGraphicBoundsKey] = NSStringFromRect(bounds);
  NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
  // interpret stroke color as foreground color, fill color as background color
  if ([result[SKTGraphicIsDrawingFillKey] boolValue]) {
    NSColor *c = [NSColor colorWithArchiveData:result[SKTGraphicFillColorKey]];
    if (c) {
      [attrs setObject:c forKey:NSBackgroundColorAttributeName];
    }
  }
  if ([result[SKTGraphicIsDrawingStrokeKey] boolValue]) {
    NSColor *c = [NSColor colorWithArchiveData:result[SKTGraphicStrokeColorKey]];
    if (c) {
      [attrs setObject:c forKey:NSForegroundColorAttributeName];
    }
  }

  NSTextStorage *storage = [[NSTextStorage alloc] initWithString:[element stringValue] attributes:attrs];
  result[SKTTextContentsKey] = [NSArchiver archivedDataWithRootObject:storage];
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfText(GDataXMLElement *element) {
  NSDictionary *props = TextPropertiesOfElement(element);
  SKTText *result = [[SKTText alloc] initWithProperties:props];
  CGRect bounds = [result bounds];
  bounds.size = [result naturalSize];
  [result setBounds:bounds];
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfTitle(GDataXMLElement *element) {
  id result = @NO;
  return result;
}

// return nil to signal parse error. return @NO to signal ignored.
static id GraphicOfUse(GDataXMLElement *element) {
  id result = @NO;
  return result;
}


id GraphicOfElement(GDataXMLElement *element) {
  id result = @NO;
  if (GDataXMLElementKind == [element kind]) {
    NSString *name = [element localName];
    if ([name isEqual:@"circle"]) {
      result = GraphicOfCircle(element);
    } else if ([name isEqual:@"desc"]) {
      result = GraphicOfDesc(element);
    } else if ([name isEqual:@"ellipse"]) {
      result = GraphicOfEllipse(element);
    } else if ([name isEqual:@"g"]) {
      result = GraphicOfGroup(element);
    } else if ([name isEqual:@"image"]) {
      result = GraphicOfImage(element);
    } else if ([name isEqual:@"line"]) {
      result = GraphicOfLine(element);
    } else if ([name isEqual:@"path"]) {
      result = GraphicOfPath(element);
    } else if ([name isEqual:@"pattern"]) {
      result = GraphicOfPattern(element);
    } else if ([name isEqual:@"polygon"]) {
      result = GraphicOfPolygon(element);
    } else if ([name isEqual:@"polyline"]) {
      result = GraphicOfPolyline(element);
    } else if ([name isEqual:@"rect"]) {
      result = GraphicOfRect(element);
    } else if ([name isEqual:@"style"]) {
      result = GraphicOfStyle(element);
    } else if ([name isEqual:@"symbol"]) {
      result = GraphicOfSymbol(element);
    } else if ([name isEqual:@"text"]) {
      result = GraphicOfText(element);
    } else if ([name isEqual:@"title"]) {
      result = GraphicOfTitle(element);
    } else if ([name isEqual:@"use"]) {
      result = GraphicOfUse(element);
    }
  }
  return result;
}

@implementation SKTDocument(SVG)

+ (NSMutableArray *)graphicsFromContainer:(GDataXMLElement *)root error:(NSError **)outError {
  NSUInteger count = [root childCount];
  NSMutableArray *graphics = [NSMutableArray array];
  // Parse from front to back so we can properly inherit styles. TODO: inherit styles
  for (NSUInteger i = 0; i < count; ++i) {
    GDataXMLElement *element = (GDataXMLElement *)[root childAtIndex:(unsigned)i];
    id graphic = GraphicOfElement(element);
    if (graphic) {
      if ( ! [graphic isEqual:@NO]) {
        [graphics addObject:graphic];
      }
    } else {
      NSLog(@"Couldn't parse %@", element);
    }
  }
  [graphics s_reverse];
  return graphics;
}

- (NSArray *)graphicsSVGTypeFromData:(NSData *)data
                           printInfo:(NSPrintInfo **)outPrintInfo
                               error:(NSError **)outError {
  GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:data options:0 error:outError];
  GDataXMLElement *root = [doc rootElement];
  NSArray *graphics = nil;
  if ([[root localName] isEqual:@"svg"]) {
    graphics = [[self class] graphicsFromContainer:root error:outError];
  }
  return graphics;
}

@end
