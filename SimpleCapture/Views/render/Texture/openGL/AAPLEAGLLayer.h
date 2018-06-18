/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  This CAEAGLLayer subclass demonstrates how to draw a CVPixelBufferRef using OpenGLES and display the timecode associated with that pixel buffer in the top right corner.
  
 */

//@import QuartzCore;
#include <QuartzCore/QuartzCore.h>
#include <CoreVideo/CoreVideo.h>
#include "OpenGLContianerDelegate.h"

typedef enum
{
    FillModeNone,
    FillModePreserveAspectRatio,//inner fit
    FillModePreserveAspectRatioAndFill ,    // Maintains the aspect ratio of the source image, zooming in on its center to fill the view--->Outer Fit(crop first and then zoom)
} VideoFillModeType;

@interface AAPLEAGLLayer : CAEAGLLayer<OpenGLContianerDelegate>

@property CVPixelBufferRef pixelBuffer;

- (id)initWithFrame:(CGRect)frame;
- (void)resetRenderBuffer;
- (void)updateFrame:(CGRect)frame;
- (void)setxMode:(VideoFillModeType)md;
@end
