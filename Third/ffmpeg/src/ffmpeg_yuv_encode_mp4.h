//
//  ffmpeg_yuv_encode_mp4.h
//  yymediarecordersdk
//
//  Created by bleach on 2018/1/2.
//  Copyright © 2018年 yy.com. All rights reserved.
//

#ifndef ffmpeg_yuv_encode_mp4_h
#define ffmpeg_yuv_encode_mp4_h
#include "ffmpeg.h"

#if defined __cplusplus
extern "C" {
#endif
    
    typedef struct YuvEncodeOutputStream {
        AVStream *st;
        AVCodecContext *enc;
        
        /* pts of the next frame that will be generated */
        int64_t next_pts;
        int samples_count;
        
        AVFrame *frame;
        AVFrame *tmp_frame;
        
        float t, tincr, tincr2;
        
        struct SwsContext *sws_ctx;
        struct SwrContext *swr_ctx;
    } YuvEncodeOutputStream;
    
    typedef struct YuvEncodeHandler {
        AVFormatContext * formatContext;
        AVOutputFormat * outputFormat;
        int bitrate;
        int width;
        int height;
        int frameRate;
        YuvEncodeOutputStream videoSt;
        YuvEncodeOutputStream audioSt;
    } YuvEncodeHandler;
    
    /**
     * 设置编码参数
     * @param bitrate
     * @param width
     * @param height
     * @param frameRate
     * @return 返回句柄
     */
    YuvEncodeHandler * yuvEncodeInitParams(const int bitrate, const int width, const int height, const int frameRate);
    
    /**
     * 初始化yuv编码
     * @param outputFile:输出目录
     * @return -1表示失败,0表示成功
     */
    int yuvEncodeCreateMp4(YuvEncodeHandler * yuvEncodeHandler, const char * outputFile);
    
    /**
     * 获取视频AVFrame做数据填充
     */
    AVFrame * yuvEncodeGetMp4Frame(YuvEncodeHandler * yuvEncodeHandler);
    
    /**
     * 填充完视频AVFrame后做encode写入
     * @param pts
     */
    int yuvEncodeVideoDataWrite(YuvEncodeHandler * yuvEncodeHandler, const double pts);
    
    /**
     * 获取音频AVFrame做数据填充
     */
    AVFrame * yuvEncodeGetAudioFrame(YuvEncodeHandler * yuvEncodeHandler);
    
    /**
     * 填充完音频AVFrame后做encode写入
     * @param pts
     */
    int yuvEncodeAudioDataWrite(YuvEncodeHandler * yuvEncodeHandler);
    
    /**
     * 写完关闭视频流
     */
    void yuvEncodeMuxerCloseMp4(YuvEncodeHandler * yuvEncodeHandler);
    
#if defined __cplusplus
};
#endif

#endif /* ffmpeg_yuv_encode_mp4_h */
