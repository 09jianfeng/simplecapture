#include "ffmpeg_yuv_encode_mp4.h"
#include <stdlib.h>
#include <stdio.h>
#include "libavutil/opt.h"
#include "libavutil/mathematics.h"
#include "libavutil/timestamp.h"
#include "libavformat/avformat.h"
#include "libswresample/swresample.h"
#include "libswresample/swresample.h"
#include "libswscale/swscale.h"

#define YUV_ENCODE_STREAM_DURATION 10.0

static AVFrame * yuvEncodeAllocPicture(enum AVPixelFormat pix_fmt, int width, int height) {
    AVFrame *picture;
    int ret;
    
    picture = av_frame_alloc();
    if (!picture) {
        return NULL;
    }
    
    picture->format = pix_fmt;
    picture->width  = width;
    picture->height = height;
    
    /* allocate the buffers for the frame data */
    ret = av_frame_get_buffer(picture, 32);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate frame data.\n");
        return NULL;
    }
    
    return picture;
}

/* Add an output stream. */
static void yuvEncodeAddStream(YuvEncodeHandler * yuvEncodeHandler, YuvEncodeOutputStream * ost, AVFormatContext * oc, AVCodec **codec, enum AVCodecID codec_id) {
    AVCodecContext * c = NULL;
    int i;
    
    /* find the encoder */
    *codec = avcodec_find_encoder(codec_id);
    if (!(*codec)) {
        fprintf(stderr, "Could not find encoder for '%s'\n",
                avcodec_get_name(codec_id));
        return;
    }
    
    ost->st = avformat_new_stream(oc, NULL);
    if (!ost->st) {
        fprintf(stderr, "Could not allocate stream\n");
        return;
    }
    ost->st->id = oc->nb_streams-1;
    c = avcodec_alloc_context3(*codec);
    if (!c) {
        fprintf(stderr, "Could not alloc an encoding context\n");
        return;
    }
    ost->enc = c;
    
    switch ((*codec)->type) {
        case AVMEDIA_TYPE_AUDIO:
            c->sample_fmt  = (*codec)->sample_fmts ?
            (*codec)->sample_fmts[0] : AV_SAMPLE_FMT_FLTP;
            c->bit_rate    = 64000;
            c->sample_rate = 44100;
            if ((*codec)->supported_samplerates) {
                c->sample_rate = (*codec)->supported_samplerates[0];
                for (i = 0; (*codec)->supported_samplerates[i]; i++) {
                    if ((*codec)->supported_samplerates[i] == 44100)
                        c->sample_rate = 44100;
                }
            }
            c->channels        = av_get_channel_layout_nb_channels(c->channel_layout);
            c->channel_layout = AV_CH_LAYOUT_MONO;
            if ((*codec)->channel_layouts) {
                c->channel_layout = (*codec)->channel_layouts[0];
                for (i = 0; (*codec)->channel_layouts[i]; i++) {
                    if ((*codec)->channel_layouts[i] == AV_CH_LAYOUT_STEREO)
                        c->channel_layout = AV_CH_LAYOUT_STEREO;
                }
            }
            c->channels        = av_get_channel_layout_nb_channels(c->channel_layout);
            ost->st->time_base = (AVRational){ 1, c->sample_rate };
            break;
            
        case AVMEDIA_TYPE_VIDEO:
            c->codec_id = codec_id;
            
            c->bit_rate = yuvEncodeHandler->bitrate;
            /* Resolution must be a multiple of two. */
            c->width    = yuvEncodeHandler->width;
            c->height   = yuvEncodeHandler->height;
            /* timebase: This is the fundamental unit of time (in seconds) in terms
             * of which frame timestamps are represented. For fixed-fps content,
             * timebase should be 1/framerate and timestamp increments should be
             * identical to 1. */
            ost->st->time_base = (AVRational){ 1, yuvEncodeHandler->frameRate };
            c->time_base       = ost->st->time_base;
            
            c->gop_size      = 5; /* emit one intra frame every twelve frames at most */
            c->pix_fmt       = AV_PIX_FMT_YUV420P;
            if (c->codec_id == AV_CODEC_ID_MPEG2VIDEO) {
                /* just for testing, we also add B-frames */
                c->max_b_frames = 2;
            }
            if (c->codec_id == AV_CODEC_ID_MPEG1VIDEO) {
                /* Needed to avoid using macroblocks in which some coeffs overflow.
                 * This does not happen with normal video, it just happens here as
                 * the motion of the chroma plane does not match the luma plane. */
                c->mb_decision = 2;
            }
            
            break;
            
        default:
            break;
    }
    
    /* Some formats want stream headers to be separate. */
    if (oc->oformat->flags & AVFMT_GLOBALHEADER) {
        c->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
}

static void yuvEncodeOpenVideo(AVFormatContext * oc, AVCodec * codec, YuvEncodeOutputStream * ost, AVDictionary * opt_arg) {
    int ret;
    AVCodecContext * c = ost->enc;
    AVDictionary * opt = NULL;
    
    av_dict_copy(&opt, opt_arg, 0);
    
    /* open the codec */
    ret = avcodec_open2(c, codec, &opt);
    av_dict_free(&opt);
    if (ret < 0) {
        fprintf(stderr, "Could not open video codec: %s\n", av_err2str(ret));
        return;
    }
    
    /* allocate and init a re-usable frame */
    ost->frame = yuvEncodeAllocPicture(c->pix_fmt, c->width, c->height);
    if (!ost->frame) {
        fprintf(stderr, "Could not allocate video frame\n");
        return;
    }
    
    /* If the output format is not YUV420P, then a temporary YUV420P
     * picture is needed too. It is then converted to the required
     * output format. */
    ost->tmp_frame = NULL;
    if (c->pix_fmt != AV_PIX_FMT_YUV420P) {
        ost->tmp_frame = yuvEncodeAllocPicture(AV_PIX_FMT_YUV420P, c->width, c->height);
        if (!ost->tmp_frame) {
            fprintf(stderr, "Could not allocate temporary picture\n");
            return;
        }
    }
    
    /* copy the stream parameters to the muxer */
    ret = avcodec_parameters_from_context(ost->st->codecpar, c);
    if (ret < 0) {
        fprintf(stderr, "Could not copy the stream parameters\n");
        return;
    }
}

static AVFrame * yuvEncodeAllocAudioFrame(enum AVSampleFormat sample_fmt, uint64_t channel_layout, int sample_rate, int nb_samples) {
    AVFrame * frame = av_frame_alloc();
    int ret;
    
    if (!frame) {
        fprintf(stderr, "Error allocating an audio frame\n");
        return NULL;
    }
    
    frame->format = sample_fmt;
    frame->channel_layout = channel_layout;
    frame->sample_rate = sample_rate;
    frame->nb_samples = nb_samples;
    
    if (nb_samples) {
        ret = av_frame_get_buffer(frame, 0);
        if (ret < 0) {
            fprintf(stderr, "Error allocating an audio buffer\n");
            return NULL;
        }
    }
    
    return frame;
}

static void yuvEncodeOpenAudio(AVFormatContext * oc, AVCodec * codec, YuvEncodeOutputStream * ost, AVDictionary * opt_arg) {
    AVCodecContext * c = ost->enc;
    int nb_samples;
    int ret;
    AVDictionary * opt = NULL;
    
    /* open it */
    av_dict_copy(&opt, opt_arg, 0);
    ret = avcodec_open2(c, codec, &opt);
    av_dict_free(&opt);
    if (ret < 0) {
        fprintf(stderr, "Could not open audio codec: %s\n", av_err2str(ret));
        return;
    }
    
    /* init signal generator */
    ost->t     = 0;
    ost->tincr = 2 * M_PI * 110.0 / c->sample_rate;
    /* increment frequency by 110 Hz per second */
    ost->tincr2 = 2 * M_PI * 110.0 / c->sample_rate / c->sample_rate;
    
    if (c->codec->capabilities & AV_CODEC_CAP_VARIABLE_FRAME_SIZE) {
        nb_samples = 10000;
    } else {
        nb_samples = c->frame_size;
    }
    
    ost->frame     = yuvEncodeAllocAudioFrame(c->sample_fmt, c->channel_layout, c->sample_rate, nb_samples);
    ost->tmp_frame = yuvEncodeAllocAudioFrame(AV_SAMPLE_FMT_S16, c->channel_layout, c->sample_rate, nb_samples);
    
    /* copy the stream parameters to the muxer */
    ret = avcodec_parameters_from_context(ost->st->codecpar, c);
    if (ret < 0) {
        fprintf(stderr, "Could not copy the stream parameters\n");
        return;
    }
    
    /* create resampler context */
    ost->swr_ctx = swr_alloc();
    if (!ost->swr_ctx) {
        fprintf(stderr, "Could not allocate resampler context\n");
        return;
    }
    
    /* set options */
    av_opt_set_int       (ost->swr_ctx, "in_channel_count",   c->channels,       0);
    av_opt_set_int       (ost->swr_ctx, "in_sample_rate",     c->sample_rate,    0);
    av_opt_set_sample_fmt(ost->swr_ctx, "in_sample_fmt",      AV_SAMPLE_FMT_S16, 0);
    av_opt_set_int       (ost->swr_ctx, "out_channel_count",  c->channels,       0);
    av_opt_set_int       (ost->swr_ctx, "out_sample_rate",    c->sample_rate,    0);
    av_opt_set_sample_fmt(ost->swr_ctx, "out_sample_fmt",     c->sample_fmt,     0);
    
    /* initialize the resampling context */
    if ((ret = swr_init(ost->swr_ctx)) < 0) {
        fprintf(stderr, "Failed to initialize the resampling context\n");
        return;
    }
}

YuvEncodeHandler * yuvEncodeInitParams(const int bitrate, const int width, const int height, const int frameRate) {
    YuvEncodeHandler * yuvEncodeHandler = malloc(sizeof(YuvEncodeHandler));
    memset(yuvEncodeHandler, 0, sizeof(YuvEncodeHandler));
    if (yuvEncodeHandler == NULL) {
        return NULL;
    }
    
    yuvEncodeHandler->bitrate = bitrate;
    yuvEncodeHandler->width = width;
    yuvEncodeHandler->height = height;
    yuvEncodeHandler->frameRate = frameRate;
    YuvEncodeOutputStream videoSt = {0};
    yuvEncodeHandler->videoSt = videoSt;
    YuvEncodeOutputStream audioSt = {0};
    yuvEncodeHandler->audioSt = audioSt;
    
    return yuvEncodeHandler;
}

int yuvEncodeCreateMp4(YuvEncodeHandler * yuvEncodeHandler, const char * outputFile) {
    if (yuvEncodeHandler == NULL) {
        fprintf(stderr, "Error yuvEncodeHandler is null\n");
        return -1;
    }
    int ret; // 成功返回0，失败返回-1
    AVCodec * video_codec = NULL;
    AVCodec * audio_codec = NULL;
    AVDictionary * opt = NULL;
    
    av_register_all();
    
    /* allocate the output media context */
    avformat_alloc_output_context2(&(yuvEncodeHandler->formatContext), NULL, NULL, outputFile);
    if (!yuvEncodeHandler->formatContext) {
        printf("Could not deduce output format from file extension: using MPEG.\n");
        avformat_alloc_output_context2(&(yuvEncodeHandler->formatContext), NULL, "mpeg", outputFile);
    }
    if (!yuvEncodeHandler->formatContext) {
        return -1;
    }
    
    yuvEncodeHandler->outputFormat = yuvEncodeHandler->formatContext->oformat;
    
    if (yuvEncodeHandler->outputFormat->video_codec != AV_CODEC_ID_NONE) {
        yuvEncodeAddStream(yuvEncodeHandler, &(yuvEncodeHandler->videoSt), yuvEncodeHandler->formatContext, &video_codec, yuvEncodeHandler->outputFormat->video_codec);
        yuvEncodeOpenVideo(yuvEncodeHandler->formatContext, video_codec, &(yuvEncodeHandler->videoSt), opt);
    }
    if (yuvEncodeHandler->outputFormat->audio_codec != AV_CODEC_ID_NONE) {
        yuvEncodeAddStream(yuvEncodeHandler, &(yuvEncodeHandler->audioSt), yuvEncodeHandler->formatContext, &audio_codec, yuvEncodeHandler->outputFormat->audio_codec);
        yuvEncodeOpenAudio(yuvEncodeHandler->formatContext, audio_codec, &(yuvEncodeHandler->audioSt), opt);
    }
    
    av_dump_format(yuvEncodeHandler->formatContext, 0, outputFile, 1);
    
    /* open the output file, if needed */
    if (!(yuvEncodeHandler->outputFormat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&(yuvEncodeHandler->formatContext->pb), outputFile, AVIO_FLAG_WRITE);
        if (ret < 0) {
            fprintf(stderr, "Could not open '%s': %s\n", outputFile, av_err2str(ret));
            return -1;
        }
    }
    
    /* Write the stream header, if any. */
    ret = avformat_write_header(yuvEncodeHandler->formatContext, &opt);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file: %s\n", av_err2str(ret));
        return -1;
    }
    
    return 0;
}

AVFrame * yuvEncodeGetMp4Frame(YuvEncodeHandler * yuvEncodeHandler) {
    if (yuvEncodeHandler == NULL) {
        fprintf(stderr, "Error yuvEncodeHandler is null\n");
        return NULL;
    }
    YuvEncodeOutputStream * videoSt = &(yuvEncodeHandler->videoSt);
    AVCodecContext * c = videoSt->enc;
    
    /* check if we want to generate more frames */
    if (av_compare_ts(videoSt->next_pts, c->time_base, YUV_ENCODE_STREAM_DURATION, (AVRational){ 1, 1 }) >= 0) {
        return NULL;
    }
    
    /* when we pass a frame to the encoder, it may keep a reference to it
     * internally; make sure we do not overwrite it here */
    if (av_frame_make_writable(videoSt->frame) < 0) {
        return NULL;
    }
    
    videoSt->frame->pts = videoSt->next_pts++;
    
    return videoSt->frame;
}

int yuvEncodeVideoDataWrite(YuvEncodeHandler * yuvEncodeHandler, const double pts) {
    if (yuvEncodeHandler == NULL) {
        fprintf(stderr, "Error yuvEncodeHandler is null\n");
        return -1;
    }
    
    AVPacket pkt = { 0 };
    int ret = 0;
    
    YuvEncodeOutputStream * videoSt = &(yuvEncodeHandler->videoSt);
    AVCodecContext * c = videoSt->enc;
    av_init_packet(&pkt);

    int got_output = 0;
    /* encode the image */
    ret = avcodec_encode_video2(c, &pkt, videoSt->frame, &got_output);
    if (ret < 0) {
        fprintf(stderr, "Error encoding frame\n");
        return -1;
    }
    
    if (got_output) {
        av_packet_rescale_ts(&pkt, c->time_base, videoSt->st->time_base);
        pkt.stream_index = videoSt->st->index;
        
        /* Write the compressed frame to the media file. */
        ret = av_interleaved_write_frame(yuvEncodeHandler->formatContext, &pkt);
        if (ret < 0) {
            fprintf(stderr, "can not write frame\n");
            return -1;
        }
    }
    
    return 0;
}

AVFrame * yuvEncodeGetAudioFrame(YuvEncodeHandler * yuvEncodeHandler) {
    if (yuvEncodeHandler == NULL) {
        fprintf(stderr, "Error yuvEncodeHandler is null\n");
        return NULL;
    }
    
    YuvEncodeOutputStream * audioSt = &(yuvEncodeHandler->audioSt);
    AVFrame * frame = audioSt->tmp_frame;
    
    /* check if we want to generate more frames */
    if (av_compare_ts(audioSt->next_pts, audioSt->enc->time_base, YUV_ENCODE_STREAM_DURATION, (AVRational){ 1, 1 }) >= 0) {
        return NULL;
    }
    
    frame->pts = audioSt->next_pts;
    audioSt->next_pts  += frame->nb_samples;
    
    return frame;
}

int yuvEncodeAudioDataWrite(YuvEncodeHandler * yuvEncodeHandler) {
    if (yuvEncodeHandler == NULL) {
        fprintf(stderr, "Error yuvEncodeHandler is null\n");
        return -1;
    }
    
    AVPacket pkt = { 0 }; // data and size must be 0;
    int ret;
    int got_packet;
    int dst_nb_samples;
    
    av_init_packet(&pkt);
    
    YuvEncodeOutputStream * audioSt = &(yuvEncodeHandler->audioSt);
    AVFrame * frame = audioSt->tmp_frame;
    AVCodecContext * c = audioSt->enc;
    
    if (frame) {
        /* convert samples from native format to destination codec format, using the resampler */
        /* compute destination number of samples */
        dst_nb_samples = (int)av_rescale_rnd(swr_get_delay(audioSt->swr_ctx, c->sample_rate) + frame->nb_samples, c->sample_rate, c->sample_rate, AV_ROUND_UP);
        
        /* when we pass a frame to the encoder, it may keep a reference to it
         * internally;
         * make sure we do not overwrite it here
         */
        ret = av_frame_make_writable(audioSt->frame);
        if (ret < 0) {
            fprintf(stderr, "Error while av_frame_make_writable\n");
            return -1;
        }
        
        /* convert to destination format */
        ret = swr_convert(audioSt->swr_ctx,
                          audioSt->frame->data, dst_nb_samples,
                          (const uint8_t **)frame->data, frame->nb_samples);
        if (ret < 0) {
            fprintf(stderr, "Error while converting\n");
            return -1;
        }
        frame = audioSt->frame;
        
        frame->pts = av_rescale_q(audioSt->samples_count, (AVRational){1, c->sample_rate}, c->time_base);
        audioSt->samples_count += dst_nb_samples;
    }
    
    ret = avcodec_encode_audio2(c, &pkt, frame, &got_packet);
    if (ret < 0) {
        fprintf(stderr, "Error encoding audio frame: %s\n", av_err2str(ret));
        exit(1);
    }
    
    if (got_packet) {
        av_packet_rescale_ts(&pkt, c->time_base, audioSt->st->time_base);
        pkt.stream_index = audioSt->st->index;
        
        /* Write the compressed frame to the media file. */
        ret = av_interleaved_write_frame(yuvEncodeHandler->formatContext, &pkt);
        if (ret < 0) {
            fprintf(stderr, "can not write frame\n");
            return -1;
        }
    }
    
    return (frame || got_packet) ? 0 : 1;
}

static void yuvEncodeCloseStream(AVFormatContext * oc, YuvEncodeOutputStream * ost) {
    avcodec_free_context(&ost->enc);
    av_frame_free(&ost->frame);
    av_frame_free(&ost->tmp_frame);
    sws_freeContext(ost->sws_ctx);
    swr_free(&ost->swr_ctx);
}

void yuvEncodeMuxerCloseMp4(YuvEncodeHandler * yuvEncodeHandler) {
    if (yuvEncodeHandler == NULL) {
        fprintf(stderr, "Error yuvEncodeHandler is null\n");
        return;
    }
    
    AVPacket pkt = { 0 };
    YuvEncodeOutputStream * videoSt = &(yuvEncodeHandler->videoSt);
    AVCodecContext * c = videoSt->enc;
    av_init_packet(&pkt);

    int got_output = 1;
    int ret = 0;
    while (got_output) {
        ret = avcodec_encode_video2(c, &pkt, NULL, &got_output);
        if (ret < 0) {
            fprintf(stderr, "Error encoding frame\n");
            break;
        }
        
        if (got_output) {
            av_packet_rescale_ts(&pkt, c->time_base, videoSt->st->time_base);
            pkt.stream_index = videoSt->st->index;
            
            /* Write the compressed frame to the media file. */
            ret = av_interleaved_write_frame(yuvEncodeHandler->formatContext, &pkt);
        }
    }
    
    if (yuvEncodeHandler->formatContext) {
        av_write_trailer(yuvEncodeHandler->formatContext);
    }
    
    yuvEncodeCloseStream(yuvEncodeHandler->formatContext, &(yuvEncodeHandler->videoSt));
    
    yuvEncodeCloseStream(yuvEncodeHandler->formatContext, &(yuvEncodeHandler->audioSt));

    if (!(yuvEncodeHandler->outputFormat->flags & AVFMT_NOFILE)) {
        /* Close the output file. */
        avio_closep(&(yuvEncodeHandler->formatContext->pb));
    }
    
    if (yuvEncodeHandler->formatContext) {
        /* free the stream */
        avformat_free_context(yuvEncodeHandler->formatContext);
    }
    
    free(yuvEncodeHandler);
    yuvEncodeHandler = NULL;
}
