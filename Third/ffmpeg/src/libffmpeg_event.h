//
//  libffmpeg_event.h
//
//  Created by baohonglai on 15/7/1.
//  Copyright (c) 2015  baohonglai All rights reserved.
//
#include "libavutil/frame.h"
#include "libavcodec/avcodec.h"

#ifndef _LIBFFMPEG_EVENT_H_
#define _LIBFFMPEG_EVENT_H_

typedef enum {
    // ffmpeg common events
    libffmpeg_event_error = -1,
    libffmpeg_event_ok = 0,
    libffmpeg_event_log = 1,
    
    //webp events
    libffmpeg_event_webp_progress = 500,
    
    // snapshot events
    libffmpeg_event_snapshot_single_progress = 1000,
    libffmpeg_event_snapshot_multiple_progress = 1001,
    libffmpeg_event_snapshot_error = 1002,
    
    // concat events
    libffmpeg_event_video_concat_progress = 2000,
    libffmpeg_event_image_video_progress = 2001,
    
    // ... events
    
    // media record events
    libffmpeg_event_media_record_error = 3000,
    
    //filter events
    libffmpeg_event_filter_progress = 4000,
    libffmpeg_event_image_filter_progress = 4001,
    
    //transcode
    libffmpeg_event_transcode_progress = 5000,
    libffmpeg_event_audio_progress = 5001,
    
}libffmpeg_event_type;

typedef enum {
    libffmpeg_cmd_none = 0,
    libffmpeg_cmd_webp,             //webp
    libffmpeg_cmd_snapshot_single,
    libffmpeg_cmd_snapshot_multiple,//多张截图
    libffmpeg_cmd_video_concat,     //视频拼接
    libffmpeg_cmd_probe,            //查询视频信息
    libffmpeg_cmd_filter,           //视频导出
    libffmpeg_cmd_transcode,        //视频转码
    libffmpeg_cmd_image_video,      //图片合成视频
    libffmpeg_cmd_image_filter,     //图片加特效
    libffmpeg_cmd_split_screen_merge, //分屏显示合并视频
    //    libffmpeg_cmd_audio,
} libffmpeg_command_type;

typedef struct libffmpeg_event_t{
    libffmpeg_event_type  type;
    union {
        struct {
            int      log_level;
            char     *log_content;
        }log_t;
        struct {
            int64_t   frame_pts;
            int       frame_num;
        }webp_progress_t;
        struct {
            int64_t   frame_pts;
            int       frame_num;
        }snapshot_progress_t;
        struct {
            int       frame_num;
        }concat_progress_t;
        struct {
            int       frame_num;
        }filter_progress_t;
        struct {
            int       frame_num;
        }transcode_progress_t;
        struct {
            int       frame_num;
        }audio_progress_t;
        struct {
            int       frame_num;
        }image_video_progress_t;
    } u;
    void *user_data;
}libffmpeg_event_t;

typedef void (*FFmpegEventCB)(libffmpeg_event_t *event) ;
typedef void (*FFmpegAVAssetCB)(AVFrame *frame, void *user_data,enum AVMediaType type);

typedef struct FFmpegCtx {
    libffmpeg_command_type      cmd_type;
    FFmpegEventCB               ffmpeg_event_cb;
    FFmpegAVAssetCB             ffmpeg_avasset_cb;
    int                         useAssetWriter;//1表示使用硬件编码，0表示使用软件编码
    void                        *user_data;
    void                        *gpuFilterUser;
} FFmpegCtx;

void ffmpeg_event_callback(const libffmpeg_event_t *ev);
typedef struct {
    FFmpegCtx *excontext;
}libffmpeg_instance_t;
#endif // _LIBFFMPEG_EVENT_H_
