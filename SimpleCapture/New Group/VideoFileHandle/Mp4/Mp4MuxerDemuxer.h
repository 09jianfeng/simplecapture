
#import <Foundation/Foundation.h>

void* ymrMp4DemuxerCreate(const char* path);

int ymrMp4DemuxerReadSpsPps(void* demuxerHandler, unsigned char** h264SpsPpsData);

int ymrMp4DemuxerReadFrame(void* demuxerHandler, unsigned char** h264FrameData, double*pts);

int ymrMp4DemuxerSeekFrame(void *demuxerHandler,int streamIndex,int64_t timestamp,int flag);

void ymrMp4DemuxerClose(void* demuxerHandler);


void ymrH264MuxerInitParams(void* h264MuxerHandler, const int bitrate, const int width, const int height, const int frameRate);

void* ymrH264MuxerInitOutputPath(const char * path,const char * meta);

void ymrH264MuxerCloseMp4(void* muxerHandler);

void ymrH264MuxerWriteVideo(void * muxerHandler, const void * h264Data, const int h264DataLen, const int isKeyFrame, const void * spsData, const int spsLen, const void * ppsData, const int ppsLen, long long pts, long long dts);

void ymrH264MuxerWriteAudio(void* muxerHandler, const void * aacData, const int aacDataLen);

void ymrH264MuxerWriteMeta(void* muxerHandler, const char*metaKey, const char*metaValue);

void ymrH264MuxerSetAudioParam(void* muxerHandler, int channels, int sampleRate);
