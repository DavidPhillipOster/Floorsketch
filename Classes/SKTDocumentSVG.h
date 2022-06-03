/*  SKTDocumentSVG.h
 Additional material Copyright © 2016 David Phillip Oster. All Rights Reserved.
*/

#import "SKTDocument.h"

@class GDataXMLElement;

@interface SKTDocument(SVG)
- (NSArray *)graphicsSVGTypeFromData:(NSData *)data
                           printInfo:(NSPrintInfo **)outPrintInfo
                               error:(NSError **)outError ;

+ (NSMutableArray *)graphicsFromContainer:(GDataXMLElement *)root error:(NSError **)outError;
@end
