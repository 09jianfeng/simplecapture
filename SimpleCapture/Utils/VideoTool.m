//
//  VideoTool.m
//  SimpleCapture
//
//  Created by JFChen on 2017/3/31.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "VideoTool.h"
#import "libyuv.h"
#import <CocoaLumberjack/CocoaLumberjack.h>


//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
static const DDLogLevel ddLogLevel = DDLogLevelInfo;


@implementation FrameContext
@end


@implementation VideoTool

+ (CVPixelBufferRef)allocPixelBufferFromPictureData:(PictureData *)picData
{
    CVPixelBufferRef pb = [self allocPixelBuffer:picData->iWidth
                                          height:picData->iHeight
                                     pixelFormat:picData->pixelFormat
                                       matrixKey:picData->matrixKey];
    
    CVPixelBufferLockBaseAddress(pb, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(pb);
    CVPlanarPixelBufferInfo_YCbCrBiPlanar *pi = (CVPlanarPixelBufferInfo_YCbCrBiPlanar*)(baseAddress);
    size_t yPlaneOffset = CFSwapInt32(pi->componentInfoY.offset);
    size_t cbcrPlaneOffset = CFSwapInt32(pi->componentInfoCbCr.offset);
    uint32_t yPlanePitch = CFSwapInt32(pi->componentInfoY.rowBytes);
    uint32_t cbcrPlanePitch = CFSwapInt32(pi->componentInfoCbCr.rowBytes);
    
    unsigned char *src = (unsigned char*)picData->iPlaneData;
    unsigned char *dest = (unsigned char*)baseAddress;
    
    I420ToNV12(src + picData->iPlaneOffset[0], picData->iStrides[0],
               src + picData->iPlaneOffset[1], picData->iStrides[1],
               src + picData->iPlaneOffset[2], picData->iStrides[2],
               dest + yPlaneOffset, yPlanePitch,
               dest + cbcrPlaneOffset, cbcrPlanePitch,
               picData->iWidth, picData->iHeight);
    
    CVPixelBufferUnlockBaseAddress(pb, 0);
    
    return pb;
}

+ (void)allyuv420FromCVpixelBuffer:(CVPixelBufferRef)pixelBuffer
                             width:(uint32_t)iwidth
                             heigh:(uint32_t)iHeigh
                  outPutYUV420Data:(uint8 **)yuvData
                         yuvLength:(int *)yuvLength{
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    CVPlanarPixelBufferInfo_YCbCrBiPlanar *pi = (CVPlanarPixelBufferInfo_YCbCrBiPlanar*)(baseAddress);
    size_t yPlaneOffset = CFSwapInt32(pi->componentInfoY.offset);
    size_t cbcrPlaneOffset = CFSwapInt32(pi->componentInfoCbCr.offset);
    uint32_t yPlanePitch = CFSwapInt32(pi->componentInfoY.rowBytes);
    uint32_t cbcrPlanePitch = CFSwapInt32(pi->componentInfoCbCr.rowBytes);
    
    uint8 *yuv420BufferPointer = [self allocYUV420Buffer:iwidth heigh:iHeigh];
    NV12ToI420(baseAddress+yPlaneOffset, yPlanePitch, baseAddress+cbcrPlaneOffset, cbcrPlanePitch, yuv420BufferPointer, iwidth, yuv420BufferPointer+iwidth*iHeigh, iwidth/2, yuv420BufferPointer+iwidth*iHeigh+iwidth*iHeigh/4, iwidth/2, iwidth, iHeigh);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    *yuvData = yuv420BufferPointer;
    *yuvLength = iwidth*iHeigh*3/2;
}

+ (uint8 *)allocYUV420Buffer:(uint32_t)iWidth heigh:(uint32_t)iHeigh{
    uint32_t yuv420Size = iWidth*iHeigh*3/2;
    uint8 *yuv420Buffer = malloc(sizeof(char)*yuv420Size);
    return yuv420Buffer;
}

+ (CVPixelBufferRef)allocPixelBuffer:(uint32_t)width
                              height:(uint32_t)height
                         pixelFormat:(OSType)pixelFormat
                           matrixKey:(CFStringRef)matrixKey
{
    CVPixelBufferRef _pixelBuffer = NULL;
    const void *keys[] = {
        kCVPixelBufferOpenGLESCompatibilityKey,
        kCVPixelBufferIOSurfacePropertiesKey,
    };
    const void *values[] = {
        (__bridge const void *)([NSNumber numberWithBool:YES]),
        (__bridge const void *)([NSDictionary dictionary])
    };
    
    OSType bufferPixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        bufferPixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    }
    
    CFDictionaryRef optionsDictionary = CFDictionaryCreate(NULL, keys, values, 2, NULL, NULL);
    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault,
                                       width,
                                       height,
                                       bufferPixelFormat,
                                       optionsDictionary,
                                       &_pixelBuffer);
    
    
    CVBufferSetAttachment(_pixelBuffer,
                          kCVImageBufferYCbCrMatrixKey,
                          matrixKey,
                          kCVAttachmentMode_ShouldNotPropagate);
    
    if(err != 0) {
        DDLogError(@"CVPixelBufferCreate failed error=%d", err);
    }
    
    CFRelease(optionsDictionary);
    
    return _pixelBuffer;
}


+ (CMSampleBufferRef)allocSampleBufRefFromPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    if (!pixelBuffer) {
        return NULL;
    }
    CMVideoFormatDescriptionRef formatDesc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,
                                                 pixelBuffer,
                                                 &formatDesc);
    
    CMSampleTimingInfo _sampleTiming;
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

+ (void)printVideoFrameInfo:(CMSampleBufferRef)sampleBuf
{
    uint8_t *data = NULL;
    CMBlockBufferRef blockbuf = CMSampleBufferGetDataBuffer(sampleBuf);
    OSStatus status = CMBlockBufferGetDataPointer(blockbuf, 0, 0, 0, (char**)&data);
    CHECK_STATUS(status);
    
    size_t blockBufSize = (int)CMBlockBufferGetDataLength(blockbuf);
    
    uint8_t *nal = data;
    do {
        uint32_t nalType = nal[4];
        uint32_t nalSize = nal[0] << 24 | nal[1] << 16 | nal[2] << 8 | nal[3];
        
        const char *nalTypeString = NULL;
        switch (nalType) {
            case 0x06:
                nalTypeString = "SEI";
                break;
            case 0x25:
                nalTypeString = "I";
                break;
            case 0x21:
                nalTypeString = "P";
                break;
            case 0x01:
                nalTypeString = "B";
                break;
                
            default:
                break;
        }
        
        nal += nalSize + 4;
        
        NSLog(@"FrameType: %s size: %d", nalTypeString, nalSize);
    } while(nal < data + blockBufSize);
}

+ (const Byte*)valueForLengthString:(unsigned long)length {
    static Byte lengthValue[5];
    memset(lengthValue, 0, sizeof(lengthValue));
    
    for (int i=0; i<4; ++i) {
        lengthValue[4-1-i] = length % (int)pow(0x100, i+1) / (int)pow(0x100,i);
    }
    return lengthValue;
}

+ (VideoFrameTypeIos)getFrameType:(int)value {
    int type = value & 0x1f;
    VideoFrameTypeIos frametype = VideoFrameI;
    switch (type) {
        case 1:
            if( value == 1 )
            {
                frametype = VideoFrameB;
                break;
            }
        case 2:
        case 3:
        case 4:
            frametype = VideoFrameP;
            break;
        case 5:
            frametype = VideoFrameIDR;
            break;
        case 9:
            //NSLog(@"a new picture started");
            break;
        default:
            frametype = VideoFrameIDR;
            break;
    }
    return frametype;
}

@end
