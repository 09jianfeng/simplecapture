//
//  H264VideoDecoder.m
//  SimpleCapture
//
//  Created by JFChen on 2017/3/31.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "H264VideoDecoder.h"
#include <VideoToolbox/VideoToolbox.h>
#import "SCCommon.h"

H264VideoDecoder *globalPointer = nil;

@implementation H264VideoDecoder{
    VTDecompressionSessionRef m_deocderSession;
    uint8_t m_currentSps[1024];
    uint32_t m_spsLen;
    uint8_t m_currentPps[1024];
    uint32_t m_ppsLen;
    CMVideoFormatDescriptionRef m_decoderFormatDescription;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        globalPointer = self;
    }
    return self;
}


void didDecompress( void *decompressionOutputRefCon,
                   void *sourceFrameRefCon,
                   OSStatus status,
                   VTDecodeInfoFlags infoFlags,
                   CVImageBufferRef pixelBuffer,
                   CMTime presentationTimeStamp,
                   CMTime presentationDuration )
{
    if (!pixelBuffer) {
        return;
    }
    
    if (status != noErr) {
        return;
    }
    
    FrameContext *fc = (__bridge FrameContext *)sourceFrameRefCon;
    CVPixelBufferRef output = CVPixelBufferRetain(pixelBuffer);
    if (globalPointer.delegate && [globalPointer.delegate respondsToSelector:@selector(decodedPixelBuffer:frameCont:)]) {
        [globalPointer.delegate decodedPixelBuffer:output frameCont:fc];
    }
    CVPixelBufferRelease(output);
    
}


- (bool)resetVideoSessionWithsps:(const uint8_t *)sps len:(uint32_t)spsLen pps:(const uint8_t *)pps ppsLen:(uint32_t)ppsLen;{
    //clearDecoderSession();
    
    const uint8_t* const parameterSetPointers[2] = { sps, pps};
    const size_t parameterSetSizes[2] = { spsLen, ppsLen};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &m_decoderFormatDescription);
    
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(m_decoderFormatDescription);
    NSLog(@"dimensions height:%d  width:%d",dimensions.height,dimensions.width);
    
    CHECK_STATUS(status);
    if(status == noErr) {
        CFDictionaryRef attrs = NULL;
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
        //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
        
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              m_decoderFormatDescription,
                                              NULL, attrs,
                                              &callBackRecord,
                                              &m_deocderSession);
        CFRelease(attrs);
    } else {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
    }
    
    return status == noErr;
}

- (void)decodeFramCMSamplebufferh264Data:(const uint8_t *)h264Data h264DataSize:(size_t)h264DataSize frameCon:(FrameContext *)frameCon;{
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)h264Data, h264DataSize,
                                                          kCFAllocatorNull,
                                                          NULL, 0, h264DataSize,
                                                          0, &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {h264DataSize};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           m_decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(m_deocderSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      (__bridge void * _Nullable)(frameCon),
                                                                      &flagOut);
            
            if(decodeStatus == kVTInvalidSessionErr) {
                //resetDecoderSession();
                //m_decodeErrorEncoutered = true;
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", decodeStatus);
                //resetDecoderSession();
                //m_decodeErrorEncoutered = true;
            }
            
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
}

@end
