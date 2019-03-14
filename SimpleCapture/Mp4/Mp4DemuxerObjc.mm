//
//  Mp4DemuxerObjc.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/16.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "Mp4DemuxerObjc.h"
#import <CoreMedia/CoreMedia.h>

#ifdef __cplusplus
extern "C" {
#endif
#include "ffmpeg_mp4_demux_h264.h"
#include "ffmpeg_h264_muxer_mp4V2.h"
#ifdef __cplusplus
}
#endif


@interface Mp4DemuxerObjc()
@property (nonatomic, assign) CMFormatDescriptionRef formatDescription;

@end

@implementation Mp4DemuxerObjc{
    NSString *_stringPath;
    Mp4DemuxerHandler *_demuxerHandler;
    
    NSData *_sps;
    NSData *_pps;
    NSData *_vps;
}

- (void)dealloc{
    CFRelease(_formatDescription);
}

- (instancetype)initWithVideoPath:(NSString *)path{
    self = [super init];
    if (self) {
        _demuxerHandler = mp4DemuxerCreate([path UTF8String]);
        _stringPath = [path copy];
    }
    return self;
}

- (NSData *)getOneFrameVideoData{
    
    unsigned char *frameData = NULL;
    double pts = 0.0f;
    int len = mp4DemuxerReadFrame(_demuxerHandler, &frameData, &pts);
    if (len <= 0) {
        NSLog(@"error len <= 0");
        _demuxerHandler = nil;
        return nil;
    }
    
    NSData *videoData = [NSData dataWithBytes:frameData length:len];
    return videoData;
}

- (VideoConfiguration *)getVideoConfig{
    VideoConfiguration *videoConf = [VideoConfiguration new];
    if (!_sps) {
        unsigned char * spspps = NULL;
        
        int spsppsLen = mp4DemuxerReadSpsPps(_demuxerHandler, &spspps);
        if (!spspps || spsppsLen == 0) {
            NSLog(@"error sps pps len 0");
            return nil;
        }
        
        int spsSize = getIntFromBigEndian(spspps);
        unsigned char * sps = spspps+4;
        int ppsSize = getIntFromBigEndian(spspps+4+spsSize);
        unsigned char * pps = spspps+4+spsSize+4;
        
        int vpsSize = 0;
        unsigned char * vps = NULL;
        if(spsppsLen > 4 + spsSize + 4 + ppsSize + 4){
            // h.265 vps
            vpsSize = getIntFromBigEndian(spspps+4+spsSize+4+ppsSize);
            vps = spspps+4+spsSize+4+ppsSize+4;
            _vps = [NSData dataWithBytes:vps length:vpsSize];
        }
        
        _sps = [NSData dataWithBytes:sps length:spsSize];
        _pps = [NSData dataWithBytes:pps length:ppsSize];
        free(spspps);
    }
    
    videoConf.sps = _sps;
    videoConf.pps = _pps;
    videoConf.vps = _vps;
    return videoConf;
}

static int getIntFromBigEndian(uint8_t *data)
{
    int data0 = data[3];
    int data1 = data[2];
    int data2 = data[1];
    int data3 = data[0];
    return (data0 << 0) | (data1 << 8) | (data2 << 16) | (data3 << 24);
}

static void freeBlockBufferData(void *o, void *block, size_t size)
{
    free(o);
}
@end
