//
//  YMTinyVideoExtracter.m
//  yymediarecordersdk
//
//  Created by 陈俊明 on 11/10/17.
//  Copyright © 2017 yy.com. All rights reserved.
//

#import "YMTinyVideoExtracter.h"
#import "YCloudVideoInfo.h"
#import "YMTinyVideoFFmpeg.h"
#import "VideoFileKit.h"

extern int ffmpeg_running;

@interface YMTinyVideoExtracter ()

@property (nonatomic, assign) FFmpegCtx *ffmpegContext;

@end

@implementation YMTinyVideoExtracter

+ (void)extractVideoFromVideo:(NSString *)videoPath
                   outputPath:(NSString *)outputPath
              completionBlock:(YMTinyVideoECompletionBlock)completionBlock
                 failureBlock:(YMTinyVideoEFailureBlock)failureBlock {
    NSLog(@"VideoPath:%@, outputPath:%@", videoPath, outputPath);
    if (![VideoFileKit existFileAtPath:videoPath]) {
        NSLog(@"Nonexistent videoPath:%@", videoPath);
        if (failureBlock != NULL) {
            failureBlock();
        }
        return;
    }
    if (outputPath == nil) {
        NSLog(@"OutputPath is nil.");
        if (failureBlock != NULL) {
            failureBlock();
        }
        return;
    }
    
    if (ffmpeg_running) {
        NSLog(@"FFmpeg has been occupied.");
        if (failureBlock != NULL) {
            failureBlock();
        }
        return;
    }
    
    [YMTinyVideoFFmpeg ffmpeg_reset_cancel];
    runAsynOnVideoProcessingQueue( ^{
        NSInteger numberOfArgs = 8;
        NSInteger i=0;
        char** arguments = calloc(numberOfArgs, sizeof(char*));
        arguments[i++] = "ffmpeg";
        arguments[i++] = "-y";
        arguments[i++] = "-i";
        arguments[i++] = (char*)[videoPath UTF8String];
        arguments[i++] = "-an";
        arguments[i++] = "-vcodec";
        arguments[i++] = "copy";
        arguments[i++] = (char*)[outputPath UTF8String];
        YMTinyVideoExtracter *extracter = [[YMTinyVideoExtracter alloc] init];
        extracter.ffmpegContext = calloc(sizeof(FFmpegCtx), 1);
        (extracter.ffmpegContext)->cmd_type = libffmpeg_cmd_transcode;
        (extracter.ffmpegContext)->user_data = (__bridge void *)self;
        libffmpeg_instance_t *p_md = ffmpeg_new(extracter.ffmpegContext);
        int ret = [YMTinyVideoFFmpeg ffmpeg_cmd:p_md argnumbers:(int)numberOfArgs arguments:arguments];
        if (ret == 0) {
            if (completionBlock != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
        } else {
            if (failureBlock != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failureBlock();
                });
            }
        }
        
        if (p_md)
            ffmpeg_release(p_md);
        if (extracter.ffmpegContext != NULL) {
            free(extracter.ffmpegContext);
        }
        if (arguments != NULL) {
            free(arguments);
        }
        [YMTinyVideoFFmpeg ffmpeg_reset_cancel];
    });
}

+ (void)extractAudioFromVideo:(NSString *)videoPath
                    startTime:(CGFloat)startTime
                     duration:(CGFloat)duration
                   outputPath:(NSString *)outputPath
              completionBlock:(YMTinyVideoECompletionBlock)completionBlock
                 failureBlock:(YMTinyVideoEFailureBlock)failureBlock {
    NSLog(@"VideoPath:%@, startTime:%f, duration:%f, outputPath:%@", videoPath, startTime, duration, outputPath);
    if (![VideoFileKit existFileAtPath:videoPath]) {
        NSLog(@"Nonexistent videoPath:%@", videoPath);
        if (failureBlock != NULL) {
            failureBlock();
        }
        return;
    }
    if (outputPath == nil) {
        NSLog(@"OutputPath is nil.");
        if (failureBlock != NULL) {
            failureBlock();
        }
        return;
    }
    
    if (ffmpeg_running) {
        NSLog(@"FFmpeg has been occupied.");
        if (failureBlock != NULL) {
            failureBlock();
        }
        return;
    }

    [YMTinyVideoFFmpeg ffmpeg_reset_cancel];
    runAsynOnVideoProcessingQueue( ^{
        NSInteger numberOfArgs = 10;
        NSInteger i = 0;
        char** arguments = calloc(numberOfArgs, sizeof(char*));
        arguments[i++] = "ffmpeg";
        arguments[i++] = "-y";
        arguments[i++] = "-ss";
        arguments[i++] = (char *)[[@(startTime) stringValue] UTF8String];
        arguments[i++] = "-i";
        arguments[i++] = (char*)[videoPath UTF8String];
        arguments[i++] = "-t";
        arguments[i++] = (char *)[[@(duration) stringValue] UTF8String];
        arguments[i++] = "-vn";
        arguments[i++] = (char*)[outputPath UTF8String];
        YMTinyVideoExtracter *extracter = [[YMTinyVideoExtracter alloc] init];
        extracter.ffmpegContext = calloc(sizeof(FFmpegCtx), 1);
        (extracter.ffmpegContext)->cmd_type = libffmpeg_cmd_transcode;
        (extracter.ffmpegContext)->user_data = (__bridge void *)self;
        libffmpeg_instance_t *p_md = ffmpeg_new(extracter.ffmpegContext);
        int ret = [YMTinyVideoFFmpeg ffmpeg_cmd:p_md argnumbers:(int)numberOfArgs arguments:arguments];
        if (ret == 0) {
            if (completionBlock != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
        } else {
            if (failureBlock != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failureBlock();
                });
            }
        }
        
        if (p_md)
            ffmpeg_release(p_md);
        if (extracter.ffmpegContext != NULL) {
            free(extracter.ffmpegContext);
        }
        if (arguments != NULL) {
            free(arguments);
        }
        [YMTinyVideoFFmpeg ffmpeg_reset_cancel];
    });
}

@end
