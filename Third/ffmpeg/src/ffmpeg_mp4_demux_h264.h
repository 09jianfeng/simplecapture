//
//  ffmpeg_mp4_demux_h264.h
//  yymediarecordersdk
//
//  Created by bleach on 2018/1/7.
//  Copyright © 2018年 yy.com. All rights reserved.
//

#ifndef ffmpeg_mp4_demux_h264_h
#define ffmpeg_mp4_demux_h264_h

#include "libavformat/avformat.h"

#if defined __cplusplus
extern "C" {
#endif
    
    typedef struct Mp4DemuxerHandler {
        AVFormatContext * formatContext;
        AVCodecContext * videoCodecContext;
        AVStream * videoStream;
        int videoStreamIdx;
        /* Enable or disable frame reference counting. You are not supposed to support
         * both paths in your application but pick the one most appropriate to your
         * needs. Look for the use of refcount in this example to see what are the
         * differences of API usage between them. */
        int refcount;
        AVPacket pkt;
    } Mp4DemuxerHandler;
    
    /**
     * 初始化解析裸流
     * @param sourceMp4:视频源
     * @return -1表示失败,0表示成功
     */
    Mp4DemuxerHandler * mp4DemuxerCreate(const char * sourceMp4);
    
    /**
     * 读取sps和pps信息
     * @param h264SpsPpsData:spspps数据申请空间并拷贝,内存自己释放
     * @return 返回数据长度,为0代表读取不到数据，需要结束
     */
    int mp4DemuxerReadSpsPps(Mp4DemuxerHandler * demuxerHandler, unsigned char ** h264SpsPpsData);

    /**
     * 读取裸流
     * @param h264FrameData:裸流数据申请空间并拷贝,内存自己释放
     * @parma pts
     * @return 返回数据长度,为0代表读取不到数据，需要结束
     */
    int mp4DemuxerReadFrame(Mp4DemuxerHandler * demuxerHandler, unsigned char ** h264FrameData, double* pts);
    
    
    /**
     * seek裸流
     * @param demuxerHandler:句柄
     * @parma timestamp      需要seek到的时间点
     * @return 0代表成功, -1 代表失败
     */
    int mp4DemuxerSeekFrame(Mp4DemuxerHandler * demuxerHandler,int streamIndex, int64_t timestamp,int flag);
    
    /**
     * 关闭句柄
     * @param demuxerHandler: 句柄
     */
    void mp4DemuxerClose(Mp4DemuxerHandler * demuxerHandler);
#if defined __cplusplus
};
#endif

#endif /* ffmpeg_mp4_demux_h264_h */
