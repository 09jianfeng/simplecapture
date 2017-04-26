//
//  VideoEncoder.m
//  SimpleCapture
//
//  Created by Yao Dong on 16/1/22.
//  Copyright © 2016年 duowan. All rights reserved.
//

#import <VideoToolbox/VideoToolbox.h>
#import "VideoTool.h"
#import "SCCommon.h"
#import "VideoEncoder.h"
#include <sys/time.h>

const int kGOPSeconds = 2;

OSStatus VTSessionSetProperty_int(VTCompressionSessionRef session, CFStringRef name, int val)
{
    CFNumberRef num = CFNumberCreate(NULL, kCFNumberIntType, &val);
    OSStatus status = VTSessionSetProperty(session, name, num);
    CFRelease(num);
    
    return status;
}

OSStatus VTSessionSetProperty_double(VTCompressionSessionRef session, CFStringRef name, double val)
{
    CFNumberRef num = CFNumberCreate(NULL, kCFNumberDoubleType, &val);
    OSStatus status = VTSessionSetProperty(session, name, num);
    CFRelease(num);
    
    return status;
}

void cCFDictionarySetValue_int32(CFMutableDictionaryRef dict, CFStringRef key, int32_t val)
{
    CFNumberRef num = CFNumberCreate (NULL, kCFNumberSInt32Type, &val);
    CFDictionarySetValue(dict, key, num);
    CFRelease(num);
}

@interface VideoEncoder ()
{
    id<VideoEncoderDelegate> _encoderDelegate;
    dispatch_queue_t _callbackQueue;
    
    VTCompressionSessionRef _encoderSession;
}
- (void) onEncoded:(FrameContext*)fc
            status:(OSStatus)compressStatus
         infoFlags:(VTEncodeInfoFlags)infoFlags
         sampleBuf:(CMSampleBufferRef)sampleBuf;
@end

void compressSessionOnEncoded(void *refCon,
                              void *sourceFrameRefCon,
                              OSStatus compressStatus,
                              VTEncodeInfoFlags infoFlags,
                              CMSampleBufferRef sampleBuf)
{
    VideoEncoder *encoder = (__bridge VideoEncoder*)refCon;
    FrameContext *fc = (__bridge FrameContext*)sourceFrameRefCon;
    [encoder onEncoded:fc status:compressStatus infoFlags:infoFlags sampleBuf:sampleBuf];
    CFRelease(sourceFrameRefCon);
}

@implementation VideoEncoder

- (id) init
{    
    return [super init];
}

- (void) reset {
    [self endEncode];
    [self beginEncode];
}

- (void) beginEncode
{
    // create a dictionary for creation
    CFMutableDictionaryRef pixbuf_attrs = CFDictionaryCreateMutable(NULL, 0,
                                                                    &kCFTypeDictionaryKeyCallBacks,
                                                                    &kCFTypeDictionaryValueCallBacks);
    
    cCFDictionarySetValue_int32(pixbuf_attrs,
                                kCVPixelBufferPixelFormatTypeKey,
                                _pixelFormatType);
    
    cCFDictionarySetValue_int32(pixbuf_attrs,
                                kCVPixelBufferWidthKey,
                                self.videoSize.width);
    
    cCFDictionarySetValue_int32(pixbuf_attrs,
                                kCVPixelBufferHeightKey,
                                self.videoSize.height);
    
    // create compress session
    OSStatus status = VTCompressionSessionCreate(NULL, self.videoSize.width, self.videoSize.height,
                                                 kCMVideoCodecType_H264,
                                                 NULL,
                                                 (CFDictionaryRef) pixbuf_attrs,
                                                 0, compressSessionOnEncoded,
                                                 (__bridge void * _Nullable)(self),
                                                 &_encoderSession);

    CHECK_STATUS(status);
    
    CFMutableDictionaryRef sessionAttributes = CFDictionaryCreateMutable(
                                                                         NULL,
                                                                         0,
                                                                         &kCFTypeDictionaryKeyCallBacks,
                                                                         &kCFTypeDictionaryValueCallBacks);
    int bitrate = self.bitrate * 1000;
    CFNumberRef bitrateNum = CFNumberCreate(NULL, kCFNumberSInt32Type, &bitrate);
    CFDictionarySetValue(sessionAttributes, kVTCompressionPropertyKey_AverageBitRate, bitrateNum);
    CFRelease(bitrateNum);
    CFDictionarySetValue(sessionAttributes, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
    CFDictionarySetValue(sessionAttributes, kVTCompressionPropertyKey_RealTime, kCFBooleanFalse);
    
    int gop = self.frameRate * kGOPSeconds;
    CFNumberRef gopNum = CFNumberCreate(NULL, kCFNumberSInt32Type, &gop);
    CFDictionarySetValue(sessionAttributes, kVTCompressionPropertyKey_MaxKeyFrameInterval, gopNum);
    CFRelease(gopNum);

    status = VTSessionSetProperties(_encoderSession, sessionAttributes);
    
    CHECK_STATUS(status);
}

- (void) endEncode;
{
    OSStatus status = VTCompressionSessionCompleteFrames(_encoderSession, kCMTimeInvalid);
    CHECK_STATUS(status);

    if(status == noErr) {
        VTCompressionSessionInvalidate(_encoderSession);
    }

    _encoderSession = NULL;
}

- (void) setTargetBitrate:(int)bitrateInKbps
{
    VTSessionSetProperty_int(_encoderSession, kVTCompressionPropertyKey_AverageBitRate, bitrateInKbps * 1000);
}

- (void) encode:(CMSampleBufferRef)sampleBuffer
{    
    CMSampleTimingInfo timingInfo;
    CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timingInfo);
    
    FrameContext *fc = [[FrameContext alloc] init];
    fc.pts = getTickCount();
    
    VTEncodeInfoFlags infoFlags = 0;
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    OSStatus status = VTCompressionSessionEncodeFrame(_encoderSession,
                                                      imageBuffer,
                                                      timingInfo.presentationTimeStamp, timingInfo.duration,
                                                      NULL,
                                                      (__bridge_retained void * _Nullable)(fc),
                                                      &infoFlags);
    
    //NSLog(@"pts %lld, duration %lld", timingInfo.presentationTimeStamp.value, timingInfo.duration.value);
    
    CHECK_STATUS(status);
    
    //强制输出，这样就不会输出B帧
    status = VTCompressionSessionCompleteFrames(_encoderSession, kCMTimeInvalid);
    CHECK_STATUS(status);
}

- (char)getFrameType:(CMSampleBufferRef)sampleBuffer
{
    char *data = NULL;
    CMBlockBufferRef blockbuf = CMSampleBufferGetDataBuffer(sampleBuffer);
    CMBlockBufferGetDataPointer(blockbuf, 0, 0, 0, (char**)&data);
    uint8_t nalutype = data[4] & 0x1f;
    
    char frameType = 0;
    if (nalutype == 0x05) {
        frameType = 'I';
    } else if (nalutype == 0x01) {
        if (data[4] == 0x01) {
            frameType = 'B';
        } else {
            frameType = 'P';
        }
    } else {
        frameType = '?';
    }
    
    return frameType;
}

- (void) onEncoded:(FrameContext*)fc
            status:(OSStatus)compressStatus
         infoFlags:(VTEncodeInfoFlags)infoFlags
         sampleBuf:(CMSampleBufferRef)sampleBuf
{
    if(compressStatus != noErr) {
        NSLog(@"Encode failed status=%d", (int)compressStatus);
        return;
    }
    
    CFRetain(sampleBuf);
    dispatch_async(_callbackQueue, ^{
        //NSLog(@"frame type %c", [self getFrameType:sampleBuf]);
        
        [_encoderDelegate encoderOutput:sampleBuf frameCont:fc];
        CFRelease(sampleBuf);
    });
}

- (void) setDelegate:(id<VideoEncoderDelegate>)encoderDelegate queue:(dispatch_queue_t)encoderCallbackQueue
{
    _encoderDelegate = encoderDelegate;
    _callbackQueue = encoderCallbackQueue;
}

#pragma mark - 
static uint32_t getTickCount() {
    struct timeval now;
    gettimeofday(&now, NULL);
    return (uint32_t) (((uint64_t)now.tv_sec * USEC_PER_SEC + now.tv_usec) / 1000);
}

@end

