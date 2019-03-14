//
//  MP4Transform.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/16.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "MP4Transform.h"
#import "Mp4DemuxerObjc.h"
#import "H264VideoDecoder.h"
#import "VideoEncoder.h"

@interface MP4Transform()<H264VideoDecoderDelegate,VideoEncoderDelegate>
@property (nonatomic, strong) Mp4DemuxerObjc *demuxer;
@property (nonatomic, strong) H264VideoDecoder *decoder;
@property (nonatomic, strong) VideoEncoder *encoder;
@end

@implementation MP4Transform{
    int _frameCount;
}

- (instancetype)initWithMp4Path:(NSString *)path{
    self = [super init];
    if (self) {
        _demuxer = [[Mp4DemuxerObjc alloc] initWithVideoPath:path];
        _decoder = [[H264VideoDecoder alloc] init];
        _decoder.delegate = self;
    }
    return self;
}

- (void)transFormBegin{
    VideoConfiguration *config = [_demuxer getVideoConfig];
    [_decoder resetVideoSessionWithsps:(const uint8_t *)[config.sps bytes]  len:(int)config.sps.length pps:(const uint8_t *)[config.pps bytes] ppsLen:(int)config.pps.length];
    
    NSData *h264data = [_demuxer getOneFrameVideoData];
    while (h264data) {
        _frameCount++;
        [_decoder decodeFramCMSamplebufferh264Data:(const uint8_t *)[h264data bytes] h264DataSize:h264data.length frameCon:nil];
        h264data = [_demuxer getOneFrameVideoData];
    }
    
    NSLog(@"_frameCount %d",_frameCount);
}


#pragma mark - delegate
- (void)decodedPixelBuffer:(CVPixelBufferRef)pixelBuffer frameCont:(FrameContext *)frameCon{
    CMSampleBufferRef sampleBuf = [self allocSampleBufRefFromPixelBuffer:pixelBuffer];
    
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int heigh = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    if (!_encoder) {
        _encoder = [VideoEncoder new];
        _encoder.pixelFormatType = kCVPixelFormatType_420YpCbCr8PlanarFullRange;
        _encoder.frameRate = 10000;
        _encoder.bitrate = 600;
        _encoder.maxBFrame = 0;
        _encoder.keyFrameInterval = 6;
        _encoder.enableDatalimit = false;
        [_encoder setDelegate:self queue:NULL];
        _encoder.videoSize = CGSizeMake(width, heigh);
        [_encoder beginEncode];
    }
    [_encoder encode:sampleBuf];
}

- (void) encoderOutput:(CMSampleBufferRef)sampleBuffer frameCont:(FrameContext *)frameCont{
    uint64_t pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value;
    NSLog(@"encode callback pts :%lld",pts);
}

- (CMSampleBufferRef)allocSampleBufRefFromPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    if (!pixelBuffer) {
        return NULL;
    }
    CMVideoFormatDescriptionRef formatDesc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,
                                                 pixelBuffer,
                                                 &formatDesc);
    
    CMSampleTimingInfo _sampleTiming;
    uint64_t currentTime = GetTickCount64();
    _sampleTiming.presentationTimeStamp = CMTimeMake(currentTime * 1000, 1000);

    CMSampleBufferRef newSampleBuf = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                       pixelBuffer,
                                       YES,
                                       NULL,
                                       NULL,
                                       formatDesc,
                                       &_sampleTiming,
                                       &newSampleBuf);
    
    CFRelease(formatDesc);
    
    return newSampleBuf;
}
@end
