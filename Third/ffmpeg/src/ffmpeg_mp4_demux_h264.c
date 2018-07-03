//
//  ffmpeg_mp4_demux_h264.c
//  yymediarecordersdk
//
//  Created by bleach on 2018/1/7.
//  Copyright © 2018年 yy.com. All rights reserved.
//

#include "ffmpeg_mp4_demux_h264.h"

int mp4DemuxerOpenCodecContext(Mp4DemuxerHandler * demuxerHandler, const char * src_filename, int *stream_idx, AVCodecContext **dec_ctx, AVFormatContext *fmt_ctx, enum AVMediaType type) {
    int ret, stream_index;
    AVStream *st;
    AVCodec *dec = NULL;
    AVDictionary *opts = NULL;
    
    ret = av_find_best_stream(fmt_ctx, type, -1, -1, NULL, 0);
    if (ret < 0) {
        fprintf(stderr, "Could not find %s stream in input file '%s'\n",
                av_get_media_type_string(type), src_filename);
        return ret;
    } else {
        stream_index = ret;
        st = fmt_ctx->streams[stream_index];
        
        /* find decoder for the stream */
        dec = avcodec_find_decoder(st->codecpar->codec_id);
        if (!dec) {
            fprintf(stderr, "Failed to find %s codec\n",
                    av_get_media_type_string(type));
            return AVERROR(EINVAL);
        }
        
        /* Allocate a codec context for the decoder */
        *dec_ctx = avcodec_alloc_context3(dec);
        if (!*dec_ctx) {
            fprintf(stderr, "Failed to allocate the %s codec context\n",
                    av_get_media_type_string(type));
            return AVERROR(ENOMEM);
        }
        
        /* Copy codec parameters from input stream to output codec context */
        if ((ret = avcodec_parameters_to_context(*dec_ctx, st->codecpar)) < 0) {
            fprintf(stderr, "Failed to copy %s codec parameters to decoder context\n",
                    av_get_media_type_string(type));
            return ret;
        }
        
        /* Init the decoders, with or without reference counting */
        av_dict_set(&opts, "refcounted_frames", demuxerHandler->refcount ? "1" : "0", 0);
        if ((ret = avcodec_open2(*dec_ctx, dec, &opts)) < 0) {
            fprintf(stderr, "Failed to open %s codec\n",
                    av_get_media_type_string(type));
            return ret;
        }
        *stream_idx = stream_index;
    }
    
    return 0;
}

Mp4DemuxerHandler * mp4DemuxerCreate(const char * sourceMp4) {
    Mp4DemuxerHandler * demuxerHandler = malloc(sizeof(Mp4DemuxerHandler));
    memset(demuxerHandler, 0, sizeof(Mp4DemuxerHandler));
    if (demuxerHandler == NULL) {
        return NULL;
    }
    
    int ret = 0;
    do {
        /* register all formats and codecs */
        av_register_all();
        
        /* open input file, and allocate format context */
        if (avformat_open_input(&(demuxerHandler->formatContext), sourceMp4, NULL, NULL) < 0) {
            fprintf(stderr, "Could not open source file %s\n", sourceMp4);
            ret = -1;
            break;
        }
        
        /* retrieve stream information */
        if (avformat_find_stream_info(demuxerHandler->formatContext, NULL) < 0) {
            fprintf(stderr, "Could not find stream information\n");
            ret = -1;
            break;
        }
        
        if (mp4DemuxerOpenCodecContext(demuxerHandler, sourceMp4, &(demuxerHandler->videoStreamIdx), &(demuxerHandler->videoCodecContext), demuxerHandler->formatContext, AVMEDIA_TYPE_VIDEO) >= 0) {
            demuxerHandler->videoStream = demuxerHandler->formatContext->streams[demuxerHandler->videoStreamIdx];
        }
        
        /* dump input information to stderr */
        av_dump_format(demuxerHandler->formatContext, 0, sourceMp4, 0);
        
        if (!demuxerHandler->videoStream) {
            fprintf(stderr, "Could not find audio or video stream in the input, aborting\n");
            ret = -1;
            break;
        }
        
        av_init_packet(&(demuxerHandler->pkt));
        demuxerHandler->pkt.data = NULL;
        demuxerHandler->pkt.size = 0;
    } while (0);
    
    return demuxerHandler;
}

static void mp4emuxerWriterLength(unsigned char * dataBuffer, uint32_t value) {
    dataBuffer[0] = (unsigned char)(value >> 24);
    dataBuffer[1] = (unsigned char)(value >> 16);
    dataBuffer[2] = (unsigned char)(value >> 8);
    dataBuffer[3] = (unsigned char)(value);
}

int mp4DemuxerReadSpsPps(Mp4DemuxerHandler * demuxerHandler, unsigned char ** h264SpsPpsData) {
    if (demuxerHandler == NULL || demuxerHandler->videoCodecContext == NULL) {
        return 0;
    }
    
    if(demuxerHandler->videoCodecContext->codec_id == AV_CODEC_ID_HEVC){
        uint16_t vpsLength;
        uint16_t spsLength;
        uint16_t ppsLength;
        
        unsigned char * extraData = demuxerHandler->videoCodecContext->extradata;
        
        int offset = 0;
        offset += 26;
        ((uint8_t *)&vpsLength)[1] = extraData[offset];
        offset++;
        ((uint8_t *)&vpsLength)[0] = extraData[offset];
        offset++;
        uint8_t *vpsdata = extraData + offset;
        offset += vpsLength;
        
        offset += 3;
        ((uint8_t *)&spsLength)[1] = extraData[offset];
        offset++;
        ((uint8_t *)&spsLength)[0] = extraData[offset];
        offset++;
        uint8_t *spsdata = extraData + offset;
        offset += spsLength;
        
        offset +=3 ;
        ((uint8_t *)&ppsLength)[1] = extraData[offset];
        offset++;
        ((uint8_t *)&ppsLength)[0] = extraData[offset];
        offset++;
        uint8_t *ppsdata = extraData + offset;
        offset += ppsLength;

        int length = 4*3 + vpsLength + spsLength + ppsLength;
        *h264SpsPpsData = (unsigned char *)malloc(sizeof(unsigned char) * length);
        unsigned char * pH264SpsPpsData = *h264SpsPpsData;
        memset(pH264SpsPpsData, 0, sizeof(unsigned char) * length);
        
        mp4emuxerWriterLength(pH264SpsPpsData, vpsLength);
        pH264SpsPpsData += 4;
        memcpy(pH264SpsPpsData, vpsdata, sizeof(unsigned char) * vpsLength);
        pH264SpsPpsData += vpsLength;
        
        mp4emuxerWriterLength(pH264SpsPpsData, spsLength);
        pH264SpsPpsData += 4;
        memcpy(pH264SpsPpsData, spsdata, sizeof(unsigned char) * spsLength);
        pH264SpsPpsData += spsLength;
        
        mp4emuxerWriterLength(pH264SpsPpsData, ppsLength);
        pH264SpsPpsData += 4;
        memcpy(pH264SpsPpsData, ppsdata, sizeof(unsigned char) * ppsLength);
        pH264SpsPpsData += ppsLength;
        
//        int newOffset = (8+2+1+5+32+48+8+4+12+6+2+6+2+5+3+5+3+16+2+3+1+2)/8;
//        int numOfArrays = extraData[newOffset];
//        for(int i = 0 ; i < numOfArrays ; i++){
//            uint16_t nalunitLength = 0;
//        }
        return length;
    }else{
        int startCodeSpsIndex = 0;
        int startCodePpsIndex = 0;
        uint32_t spsLength = 0;
        uint32_t ppsLength= 0;
        unsigned char * extraData = demuxerHandler->videoCodecContext->extradata;
        for (int index = 1; index < demuxerHandler->videoCodecContext->extradata_size;) {
            if ((extraData[index] & 0x1f) == 0x7 && extraData[index - 2] == 0x0) {
                startCodeSpsIndex = index;
                spsLength = (uint32_t)extraData[index - 1];
                index += spsLength;
                continue;
            }
            
            if ((extraData[index] & 0x1f) == 0x8 && extraData[index - 2] == 0x0) {
                startCodePpsIndex = index;
                ppsLength = (uint32_t)extraData[index - 1];
                index += ppsLength;
                continue;
            }
            
            index++;
        }
        
        if (spsLength == 0 || ppsLength == 0) {
            return 0;
        }
        
        int length = 8 + spsLength + ppsLength;
        *h264SpsPpsData = (unsigned char *)malloc(sizeof(unsigned char) * length);
        unsigned char * pH264SpsPpsData = *h264SpsPpsData;
        memset(pH264SpsPpsData, 0, sizeof(unsigned char) * length);
        mp4emuxerWriterLength(pH264SpsPpsData, spsLength);
        memcpy(pH264SpsPpsData + 4, extraData + startCodeSpsIndex, sizeof(unsigned char) * spsLength);
        mp4emuxerWriterLength(pH264SpsPpsData + 4 + spsLength, ppsLength);
        memcpy(pH264SpsPpsData + 8 + spsLength, extraData + startCodePpsIndex, sizeof(unsigned char) * ppsLength);
        
        return length;
    }
    
    return 0;
}

void mp4DemuxerClose(Mp4DemuxerHandler * demuxerHandler) {
    if (demuxerHandler == NULL) {
        return;
    }
    if (demuxerHandler->videoCodecContext) {
        avcodec_free_context(&(demuxerHandler->videoCodecContext));
        demuxerHandler->videoCodecContext = NULL;
    }
    
    if (demuxerHandler->formatContext) {
        avformat_close_input(&(demuxerHandler->formatContext));
        demuxerHandler->formatContext = NULL;
    }
    
    free(demuxerHandler);
    demuxerHandler = NULL;
}

int mp4DemuxerSeekFrame(Mp4DemuxerHandler * demuxerHandler,int streamIndex, int64_t timestamp,int flag){
    
    if (demuxerHandler == NULL) {
        mp4DemuxerClose(demuxerHandler);
        return -1;
    }
    
    /* flag:
     AVSEEK_FLAG_BACKWARD：若设置seek时间为1秒，但是只有0秒和2秒上才有I帧，则时间从0秒开始。
     AVSEEK_FLAG_ANY     ：若设置seek时间为1秒，但是只有0秒和2秒上才有I帧，则时间从2秒开始。
     AVSEEK_FLAG_FRAME   ：若设置seek时间为1秒，但是只有0秒和2秒上才有I帧，则时间从2秒开始。
     目前还没发现AVSEEK_FLAG_ANY和AVSEEK_FLAG_FRAME的区别
     */
    //seek参数单位为微妙
    while (av_seek_frame(demuxerHandler ->formatContext, streamIndex, timestamp, flag) >= 0 ) {
        return 0;
    }
    return -1;
}

int mp4DemuxerReadFrame(Mp4DemuxerHandler * demuxerHandler, unsigned char ** h264FrameData, double* pts) {
    if (demuxerHandler == NULL) {
        mp4DemuxerClose(demuxerHandler);
        return 0;
    }
    while (av_read_frame(demuxerHandler->formatContext, &(demuxerHandler->pkt)) >= 0) {
        if (demuxerHandler->pkt.stream_index == demuxerHandler->videoStreamIdx) {
            int frameSize = sizeof(uint8_t) * demuxerHandler->pkt.size;
            *h264FrameData = (uint8_t *)malloc(frameSize);
            *pts = av_q2d(demuxerHandler->videoStream->time_base) * demuxerHandler->pkt.pts;
            memcpy(*h264FrameData, demuxerHandler->pkt.data, frameSize);
            av_packet_unref(&(demuxerHandler->pkt));
            return frameSize;
        }
        av_packet_unref(&(demuxerHandler->pkt));
    }
    
    mp4DemuxerClose(demuxerHandler);
    return 0;
}
