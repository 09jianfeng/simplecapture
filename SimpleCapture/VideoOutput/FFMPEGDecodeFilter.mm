//
//  FFMPEGDecodeFilter.m
//  SimpleCapture
//
//  Created by JFChen on 2017/5/11.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "FFMPEGDecodeFilter.h"
#import <libyuv/libyuv.h>

#include <string>
#ifdef __cplusplus
extern "C" {
#endif
#include "libavutil/opt.h"
#include "libavcodec/avcodec.h"
#include "libavutil/channel_layout.h"
#include "libavutil/common.h"
#include "libavutil/imgutils.h"
#include "libavutil/mathematics.h"
#include "libavutil/samplefmt.h"
#ifdef __cplusplus
}
#endif

@implementation FFMPEGDecodeFilter{
    int _width;
    int _height;
    AVCodecContext *_context;
    AVFrame *_avFrame;
    AVCodec *_codec;
    AVPacket _avPacket;
    AVCodecID _codecId;
    uint8_t *_extraData;
    int _extraDataSize;
    int _frameCount;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _codecId = AV_CODEC_ID_H264;
        avcodec_register_all();
    }
    return self;
}

- (int)processMediaSample:(MediaSample *)mediaSample from:(id)upstream{
    return 0;
}

- (int)processFlvData:(uint8_t *)pData len:(uint32_t)nDataLen des:(FrameDesc *)pInDes{
    if (!pData || nDataLen == 0) {
        NSLog(@"AVCodecID(%d) pData is null", _codecId);
        return -1;
    }
    
    if (!pInDes) {
        NSLog(@"AVCodecID(%d) pInDes is null", _codecId);
        return -1;
    }
    
    uint8_t *videoHeaderData = NULL;
    uint8_t *h264VideoData = NULL;
    uint32_t videoHeaderLen = 0;
    uint32_t flvDataSize = 0;
    if (pInDes.iFrameType == kVideoIFrame) {
        videoHeaderLen = *(uint32_t*)pData;
        if (videoHeaderLen > nDataLen) {
            NSLog(@"AVCoderID(%u) videoHeaderLen(%u) > nDataLen(%u)", _codecId, videoHeaderLen, nDataLen);
            return -1;
        }
        
        pData += sizeof(unsigned int);
        videoHeaderData = (unsigned char*)pData;
        pData += videoHeaderLen;
        //flvDataSize
        flvDataSize = [self getFlvDataLen:pData];
        //h264Data
        h264VideoData = (unsigned char*)pData + 16; //skip flv tag
    }else{
        //一般的video tag,flvDataSize
        flvDataSize = [self getFlvDataLen:pData];
        //h264Data
        h264VideoData = (unsigned char*)pData + 16; //skip flv tag
    }
    
    if (flvDataSize > nDataLen) {
        NSLog(@"VideoDataLen > nDataLen");
        return -1;
    }
    
    // if the vps/sps/pps has changed, we need to reopen the decoder too.
    if (_context == NULL || [self isExtraDataChanged:videoHeaderData len:videoHeaderLen]) {
        [self closeAll];
        
        // open the decoder with extra data
        _context = [self openDecoder:videoHeaderData len:videoHeaderLen];
        if (_codec == NULL) {
            NSLog(@"AVCodecID(%d) can not open codec", _codecId);
            return -1;
        }
        
        if (_extraData) {
            free(_extraData);
        }
        _extraData = (uint8_t *)malloc(videoHeaderLen);
        _extraDataSize = videoHeaderLen;
        memcpy(_extraData, videoHeaderData, videoHeaderLen);
    }
    
    _avPacket.data = h264VideoData;
    _avPacket.size = flvDataSize;
    _avPacket.dts = pInDes.iPts;
    
    int gotFrame = 0;
    int len = avcodec_decode_video2(_context, _avFrame, &gotFrame, &_avPacket);
    if (len < 0) {
        NSLog(@"AVCodecID(%d) Error while decoding frame %d", _codecId, _frameCount);
        return -1;
    }
    
    if (!gotFrame) {
        NSLog(@"AVCodecID(%d) decoder got nothing, frameCount %d", _codecId, _frameCount);
        return -1;
    }
    
    ++_frameCount;
    _width = _avFrame->width;
    _height = _avFrame->height;
    
    int pictureDataSize = _height * (_avFrame->linesize[0] + _avFrame->linesize[1] + _avFrame->linesize[2]);
    uint8_t *pictureData = (uint8_t *)malloc(pictureDataSize);
    if (!pictureData) {
        NSLog(@"failed to allocate memory for new frame.");
        return -1;
    }
    
    return 0;
}

#pragma mark - handle primitive h264 Data

- (BOOL)updateSPSPPS:(uint8_t *)sps spsLen:(int)spsLen pps:(uint8_t *)pps ppsLen:(int)ppsLen{
    int extraDataLen;
    uint8_t *extraData = [self writeSPSAndPPSToExtraData:sps spsLen:spsLen ppsData:pps ppsLen:ppsLen extraDataSize:&extraDataLen];
    if (![self isExtraDataChanged:extraData len:extraDataLen]) {
        return NO;
    }
    
    if (_extraData) {
        free(_extraData);
    }
    _extraData = extraData;
    _extraDataSize = extraDataLen;
    
    return YES;
}

// befor call precessH264Data, please call updateSPSPPS function first
- (int)processH264Data:(uint8_t *)h264Data h264DataLen:(int)h264Len pts:(int)pts{
    
    if (_context == NULL) {
        _context = [self openDecoder:_extraData len:_extraDataSize];
        if (_context == NULL) {
            NSLog(@"_context create fail");
            return -1;
        }
    }
    
    _avPacket.data = h264Data;
    _avPacket.size = h264Len;
    _avPacket.dts = pts;
    
    int gotFrame = 0;
    int len = avcodec_decode_video2(_context, _avFrame, &gotFrame, &_avPacket);
    if (len < 0) {
        NSLog(@"AVCodecID(%d) Error while decoding frame %d", _codecId, _frameCount);
        return -1;
    }
    
    if (!gotFrame) {
        NSLog(@"AVCodecID(%d) decoder got nothing, frameCount %d", _codecId, _frameCount);
        return -1;
    }
    
    ++_frameCount;
    _width = _avFrame->width;
    _height = _avFrame->height;
    
    CVPixelBufferRef pixelBuffer = [self allocPixelBufferFromPictureData:_avFrame];
    if ([_delegate respondsToSelector:@selector(decodedPixelBuffer:)]) {
        [_delegate decodedPixelBuffer:pixelBuffer];
    }
    
    return 0;
}

#pragma mark - decoderInit

- (AVCodecContext *)openDecoder:(void *)extradata len:(int)extradataLen{
    for(;;) {
        _frameCount = 0;
        av_init_packet(&_avPacket);
        _codec = avcodec_find_decoder(_codecId);
        if (!_codec) {
            NSLog(@"AVCodecID(%d) Codec not found", _codecId);
            break;
        }
        
        _context = avcodec_alloc_context3(_codec);
        if (!_context) {
            NSLog(@"AVCodecID(%d) Could not allocate video codec context", _codecId);
            break;
        }
        
        if (extradata && extradataLen > 0) {
            _context->extradata = (uint8_t*)extradata;
            _context->extradata_size = extradataLen;
            _context->flags |= CODEC_FLAG_GLOBAL_HEADER;
        }
        
        _context->thread_count = 2;
        _context->thread_type = FF_THREAD_SLICE;
        if (avcodec_open2(_context, _codec, NULL) < 0) {
            NSLog(@"AVCodecID(%d) Could not open codec", _codecId);
            break;
        }
        
        _avFrame = av_frame_alloc();
        if (!_avFrame) {
            NSLog(@"AVCodecID(%d) Could not allocate video frame", _codecId);
            break;
        }
        return _context;
    }
    
    if (_context) {
        avcodec_close(_context);
        av_free(_context);
        _context = 0;
    }
    if (_avFrame) {
        av_frame_free(&_avFrame);
        _avFrame = 0;
    }
    _codec = 0;
    return NULL;
}

- (void)closeAll{
    _avPacket.data = NULL;
    _avPacket.size = 0;
    if (_context) {
        avcodec_close(_context);
        av_free(_context);
        _context = 0;
    }
    
    if (_avFrame) {
        av_frame_free(&_avFrame);
        _avFrame = 0;
    }
    
    free(_extraData);
    _extraData = NULL;
    _extraDataSize = 0;
    _codec = 0;
}

#pragma mark - tool
/* 例子，下面的一段数据是传输层传过来的flv data
 这里的前4个字节是headerlen，加入extraData的要剔除这四个字节，0x01开始的才是要写入extraData（也就是从AVCDecoderConfigurationRecord 开始的sps/pps data）
 0x2a 0x00 0x00 0x00 headerlen 以小端读取，则是42
 0xe1 spsCount
 0x00 0x1b 两个字节表示sps长度 27长度
 0x01 0x00 0x04 第一个字节表示pps的数量，0x00 0x04表示pps的长度
 
 0x102ab9c0c: 0x2a 0x00 0x00 0x00 0x01 0x64 0x00 0x1f
 0x102ab9c14: 0xff 0xe1 0x00 0x1b 0x67 0x64 0x00 0x1f
 0x102ab9c1c: 0xac 0xd3 0x01 0x40 0x16 0xe9 0xa8 0x28
 0x102ab9c24: 0x28 0x2a 0x00 0x00 0x03 0x00 0x02 0x00
 0x102ab9c2c: 0x00 0x0f 0xa0 0x1e 0x30 0x62 0x70 0x01
 0x102ab9c34: 0x00 0x04 0x68 0xea 0xef 0x2c 0x09 0x00
 0x102ab9c3c: 0x2f 0x71
 */
- (uint8 *)writeSPSAndPPSToExtraData:(uint8_t *)sps spsLen:(int)spsLen ppsData:(uint8_t *)pps ppsLen:(int)ppsLen extraDataSize:(int *)extraDataLen{
    int extradata_size = 5 + 3 + spsLen + 3 + ppsLen;
    *extraDataLen = extradata_size;
    uint8_t *extradata = (uint8_t *)malloc(extradata_size);
    
    int offset = 0;
    //AVCDecoderConfigurationRecord
    extradata[0] = 0x01;
    extradata[1] = 0x64; //avc profile
    extradata[2] = 0x00;
    extradata[3] = 0x1f; //avc level
    extradata[4] = 0xff;
    extradata[5] = 0xe1; //sps count
    
    offset += 6;
    //紧接着两个字节表示sps的长度
    extradata[offset] = spsLen/0xff;
    extradata[offset+1] = spsLen%0xff;
    offset +=2;
    
    //接下来的spslen是sps data
    memcpy(extradata + offset, sps, spsLen);
    offset += spsLen;
    
    //接下来的一个字节表示pps的数量
    extradata[offset] = 0x01;
    offset += 1;
    
    //然后两个字节是表示pps的长度
    extradata[offset] = ppsLen/0xff;
    extradata[offset+1] = ppsLen%0xff;
    offset += 2;
    
    //接来下是pps的数据
    memcpy(extradata + offset, pps, ppsLen);
    return extradata;
}

- (bool)isExtraDataChanged:(void *)extraData  len:(int)len{
    if (!extraData || len <= 0) {
        return false;
    }
    
    if (!_extraData || len != _extraDataSize) {
        return true;
    }
    
    if(memcmp(extraData, _extraData, len) != 0) {
        return true;
    }
    
    return false;
}

-(int)getFlvDataLen:(uint8_t *)flvBuffer
{
    int byte1 = ((int)flvBuffer[1]) & 0xff;
    int byte2 = ((int)flvBuffer[2]) & 0xff;
    int byte3 = ((int)flvBuffer[3]) & 0xff;
    int len = (byte1 << 16) | (byte2 << 8) | byte3;
    return len - 5;
}

- (CVPixelBufferRef)allocPixelBufferFromPictureData:(AVFrame *)avFrame
{
    OSType pixelFormat;
    if (_avFrame->color_range == AVCOL_RANGE_JPEG) {
        // full range
        pixelFormat = kCVPixelFormatType_420YpCbCr8PlanarFullRange;
    } else {
        // limited range
        pixelFormat = kCVPixelFormatType_420YpCbCr8Planar;
    }
    
    CFStringRef matricKey;
    if (_avFrame->colorspace == AVCOL_SPC_BT709) {
        // 709
        matricKey = kCVImageBufferYCbCrMatrix_ITU_R_709_2;
    } else {
        // 601
        matricKey = kCVImageBufferYCbCrMatrix_ITU_R_601_4;
    }
    
    CVPixelBufferRef pb = [self allocPixelBuffer:avFrame->width
                                          height:avFrame->height
                                     pixelFormat:pixelFormat
                                       matrixKey:matricKey];
    
    
    CVPixelBufferLockBaseAddress(pb, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(pb);
    CVPlanarPixelBufferInfo_YCbCrBiPlanar *pi = (CVPlanarPixelBufferInfo_YCbCrBiPlanar*)(baseAddress);
    size_t yPlaneOffset = CFSwapInt32(pi->componentInfoY.offset);
    size_t cbcrPlaneOffset = CFSwapInt32(pi->componentInfoCbCr.offset);
    uint32_t yPlanePitch = CFSwapInt32(pi->componentInfoY.rowBytes);
    uint32_t cbcrPlanePitch = CFSwapInt32(pi->componentInfoCbCr.rowBytes);
    
    unsigned char *dest = (unsigned char*)baseAddress;
    libyuv::I420ToNV12(_avFrame->data[0], _avFrame->linesize[0],
               _avFrame->data[1], _avFrame->linesize[1],
               _avFrame->data[2], _avFrame->linesize[2],
               dest + yPlaneOffset, yPlanePitch,
               dest + cbcrPlaneOffset, cbcrPlanePitch,
               _avFrame->width, _avFrame->height);
    
    CVPixelBufferUnlockBaseAddress(pb, 0);
    
    return pb;
}


- (CVPixelBufferRef)allocPixelBuffer:(uint32_t)width
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
        NSLog(@"CVPixelBufferCreate failed error=%d", err);
    }
    
    CFRelease(optionsDictionary);
    
    return _pixelBuffer;
}
@end
