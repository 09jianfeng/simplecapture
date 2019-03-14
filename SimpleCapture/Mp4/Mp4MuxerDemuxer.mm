
// #import <AVFoundation/AVFoundation.h>

#import "Mp4MuxerDemuxer.h"


#ifdef __cplusplus
extern "C" {
#endif
#include "ffmpeg_mp4_demux_h264.h"
#include "ffmpeg_h264_muxer_mp4V2.h"
#ifdef __cplusplus
}
#endif


void* ymrMp4DemuxerCreate(const char* path)
{
    return mp4DemuxerCreate(path);
}

int ymrMp4DemuxerReadSpsPps(void* demuxerHandler, unsigned char** h264SpsPpsData)
{
    return mp4DemuxerReadSpsPps((Mp4DemuxerHandler*)demuxerHandler, h264SpsPpsData);
}

int ymrMp4DemuxerReadFrame(void* demuxerHandler, unsigned char** h264FrameData, double*pts)
{
    return mp4DemuxerReadFrame((Mp4DemuxerHandler*)demuxerHandler, h264FrameData, pts);
}

int ymrMp4DemuxerSeekFrame(void *demuxerHandler,int streamIndex,int64_t timestamp,int flag)
{
    return mp4DemuxerSeekFrame((Mp4DemuxerHandler *)demuxerHandler,streamIndex,timestamp,flag);
}

void ymrMp4DemuxerClose(void* demuxerHandler)
{
    return mp4DemuxerClose((Mp4DemuxerHandler*)demuxerHandler);
}

void ymrH264MuxerInitParams(void* h264MuxerHandler, const int bitrate, const int width, const int height, const int frameRate)
{
    h264MuxerInitParamsV2((H264MuxerHandler*)h264MuxerHandler, bitrate, width, height, frameRate);
}

void* ymrH264MuxerInitOutputPath(const char * path , const char * meta)
{
    return h264MuxerInitOutputPathV2(path, (int)strlen(path),meta,(int)strlen(meta));
}

void ymrH264MuxerCloseMp4(void* muxerHandler)
{
    h264MuxerCloseMp4V2((H264MuxerHandler*)muxerHandler);
}

void ymrH264MuxerWriteVideo(void * muxerHandler, const void * h264Data, const int h264DataLen, const int isKeyFrame, const void * spsData, const int spsLen, const void * ppsData, const int ppsLen, int64_t pts, int64_t dts)
{
    h264MuxerWriteVideoV2((H264MuxerHandler*)muxerHandler, h264Data, h264DataLen, isKeyFrame, spsData, spsLen, ppsData, ppsLen, pts, dts);
}

void ymrH264MuxerWriteAudio(void* muxerHandler, const void * aacData, const int aacDataLen)
{
    h264MuxerWriteAudioV2((H264MuxerHandler*)muxerHandler, aacData, aacDataLen);
}

void ymrH264MuxerWriteMeta(void* muxerHandler, const char*metaKey, const char*metaValue)
{
    h264MuxerWriteMetaV2((H264MuxerHandler*)muxerHandler, metaKey, metaValue);
}

void ymrH264MuxerSetAudioParam(void* muxerHandler, int channels, int sampleRate){
    H264MuxerHandler *handler = (H264MuxerHandler*)muxerHandler;
    handler->audioSampleRate = sampleRate;
    handler->audioChannels = channels;
}

