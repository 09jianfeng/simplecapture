//
//  VideoTool.h
//  SimpleCapture
//
//  Created by JFChen on 2017/3/31.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include "SCCommon.h"

typedef enum {
    VideoFrameUnknow = 0xFF,   // 8bits
    VideoFrameI = 0,
    VideoFrameP = 1,
    VideoFrameB = 2,
    VideoFramePSEI = 3,        // 0 - 3 is same with YY video packet's frame type.
    VideoFrameIDR = 4,
    VideoFrameSPS = 5,
    VideoFramePPS = 6,
    
    //rgb or yuv data
    VideoFrameYV12 = 100,
    VideoFrameNV12 = 101,
    VideoFrameNV21 = 102,
} VideoFrameTypeIos;


@interface VideoTool : NSObject

+ (CVPixelBufferRef)allocPixelBufferFromPictureData:(PictureData *)picData;

+ (CMSampleBufferRef)allocSampleBufRefFromPixelBuffer:(CVPixelBufferRef)pixelBuffer;

+ (void) printVideoFrameInfo:(CMSampleBufferRef) sampleBuf;

+ (const Byte*)valueForLengthString:(unsigned long)length;

+ (VideoFrameTypeIos)getFrameType:(int)value;

+ (void)allyuv420FromCVpixelBuffer:(CVPixelBufferRef)pixelBuffer
                             width:(uint32_t)iwidth
                             heigh:(uint32_t)iHeigh
                  outPutYUV420Data:(unsigned char **)yuvData
                         yuvLength:(int *)yuvLength;

@end
