//
//  VideoEncoder.h
//  SimpleCapture
//
//  Created by Yao Dong on 16/1/22.
//  Copyright © 2016年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CMSampleBuffer.h>

@protocol VideoEncoderDelegate <NSObject>
- (void) encoderOutput:(CMSampleBufferRef)sampleBuf;
@end

@interface VideoEncoder : NSObject
@property CGSize videoSize;
@property int frameRate;
@property int bitrate;
@property OSType pixelFormatType;

- (id) init;
- (void) reset;
- (void) beginEncode;
- (void) endEncode;
- (void) encode:(CMSampleBufferRef)sampleBuffer;
- (void) setTargetBitrate:(int)bitrateInKbps;
- (void) setDelegate:(id<VideoEncoderDelegate>)encoderDelegate queue:(dispatch_queue_t)encoderCallbackQueue;
@end
