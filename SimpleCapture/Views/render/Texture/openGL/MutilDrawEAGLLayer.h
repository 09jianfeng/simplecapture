//
//  MutilDrawEAGLLayer.h
//  yyvideolib
//
//  Created by JFChen on 2017/11/13.
//  Copyright © 2017年 yy. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#include <CoreVideo/CoreVideo.h>
#import "MultiDrawMetalLayer.h"
#import "AAPLEAGLLayer.h"
#import "OpenGLContianerDelegate.h"

@interface MutilDrawEAGLLayer : CAEAGLLayer<OpenGLContianerDelegate>

- (id)initWithFrame:(CGRect)frame Capacity:(int) capacity;
- (void)resetRenderBuffer;
- (void)setxMode:(VideoFillModeType)md;

-(void) removePixelBufferAtIndex:(int)index;
-(CVPixelBufferRef) pixelBufferAtIndex:(int) index;
- (void)setPixelBuffer:(CVPixelBufferRef)pb ViewCoordinate:(MutilVideoViewCoordinateInfo *)viewCoordinate;
-(void)setBackgroudPixelBuffer:(CVPixelBufferRef)bgPixeBuffer ViewCoordinate:(MutilVideoViewCoordinateInfo*)viewCoordinate;
@end
