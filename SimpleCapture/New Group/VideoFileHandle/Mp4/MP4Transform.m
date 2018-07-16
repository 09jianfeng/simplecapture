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

@interface MP4Transform()
@property (nonatomic, strong) Mp4DemuxerObjc *demuxer;
@property (nonatomic, strong) H264VideoDecoder *decoder;
@end

@implementation MP4Transform{
    int _frameCount;
}

- (instancetype)initWithMp4Path:(NSString *)path{
    self = [super init];
    if (self) {
        _demuxer = [[Mp4DemuxerObjc alloc] initWithVideoPath:path];
        _decoder = [[H264VideoDecoder alloc] init];
    }
    return self;
}

- (void)transFormBegin{
    VideoConfiguration *config = [_demuxer getVideoConfig];
    [_decoder resetVideoSessionWithsps:[config.sps bytes]  len:(int)config.sps.length pps:[config.pps bytes] ppsLen:(int)config.pps.length];
    
    NSData *h264data = [_demuxer getOneFrameVideoData];
    while (h264data) {
        _frameCount++;
        [_decoder decodeFramCMSamplebufferh264Data:[h264data bytes] h264DataSize:h264data.length frameCon:nil];
        h264data = [_demuxer getOneFrameVideoData];
    }
    
    NSLog(@"_frameCount %d",_frameCount);
}

@end
