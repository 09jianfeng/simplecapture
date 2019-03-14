//
//  H264VideoDecoder.h
//  SimpleCapture
//
//  Created by JFChen on 2017/3/31.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>
#import "VideoTool.h"

@protocol H264VideoDecoderDelegate <NSObject>
- (void)decodedPixelBuffer:(CVPixelBufferRef)pixelBuffer frameCont:(FrameContext *)frameCon;
@end

@interface H264VideoDecoder : NSObject
@property(nonatomic, weak) id<H264VideoDecoderDelegate> delegate;

- (bool)resetVideoSessionWithsps:(const uint8_t *)sps len:(uint32_t)spsLen pps:(const uint8_t *)pps ppsLen:(uint32_t)ppsLen;

- (void)decodeFramCMSamplebufferh264Data:(const uint8_t *)h264Data h264DataSize:(size_t)h264DataSize frameCon:(FrameContext *)frameCon;

@end
