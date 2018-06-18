//
//  MetalRenderLayer.h
//  SimpleCapture
//
//  Created by JFChen on 2018/6/18.
//  Copyright © 2018年 duowan. All rights reserved.
//


#if (TARGET_IPHONE_SIMULATOR)
// 在模拟器的情况下
#else

#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#include <CoreVideo/CoreVideo.h>
#import <QuartzCore/CAMetalLayer.h>
#import "OpenGLContianerDelegate.h"

typedef enum
{
    MetalFillModeNone,
    MetalFillModePreserveAspectRatio,//inner fit
    MetalFillModePreserveAspectRatioAndFill ,    // Maintains the aspect ratio of the source image, zooming in on its center to fill the view--->Outer Fit(crop first and then zoom)
} MetalVideoFillModeType;

@interface MetalRenderLayer : CAMetalLayer<OpenGLContianerDelegate>
{
    CVPixelBufferRef _pixelBuffer;
}

- (void)setFrame:(CGRect)frame;
- (void)setFillMode:(MetalVideoFillModeType)fillMode;
- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)clearContents;

- (CGRect)getRenderPosition;

@end

#endif
