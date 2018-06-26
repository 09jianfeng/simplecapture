//
//  PixelBufferRotateTool.h
//  SimpleCapture
//
//  Created by JFChen on 2018/6/23.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#include <QuartzCore/QuartzCore.h>
#include <CoreVideo/CoreVideo.h>

@interface PixelBufferRotateTool : NSObject
//nv12 pixelbuffer rotate
- (CVPixelBufferRef)rotatePixelBuffer:(CVPixelBufferRef)pix rotate:(int)angle;

@end
