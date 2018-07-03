//
//  YMTinyVideoFFmpeg.m
//  yymediarecordersdk
//
//  Created by 陈俊明 on 12/21/17.
//  Copyright © 2017年 yy.com. All rights reserved.
//

#import "YMTinyVideoFFmpeg.h"
#import "YMTinyVideoFFmpegContext.h"
#import "ffmpeg.h"

char * ffprobe_main(int argc, char **argv);
extern int ffmpeg_running;
extern int ffmpeg_process_cacelled;

@implementation YMTinyVideoFFmpeg

static NSString * dateToString(NSDate * date) {
    NSDateFormatter * formatter=[[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:@"YYYYMMddHHmmss"];
    formatter.timeZone=[NSTimeZone timeZoneWithName:@"shanghai"];
    NSString * dateString = [formatter stringFromDate:date];
    return dateString;
}

+ (NSString *)getDefaultFileName:(NSString *)videoName
                   withExtension:(NSString *)extension {
    NSString * fileName;
    NSDate * now = [NSDate date];
    if (videoName) {
        fileName = [videoName stringByAppendingString:dateToString(now)];
        fileName = [fileName stringByAppendingPathExtension:extension];
    } else {
        NSLog(@"[Error] videoName is nil");
    }
    return fileName;
}

+ (NSString *)getDefaultFileDir:(NSString *)videoDir
                       pathment:(NSString *)pathComponent {
    NSString * videoConcatDir = [videoDir stringByAppendingPathComponent:pathComponent];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    BOOL isdir=YES;
    if (![fileManager fileExistsAtPath:videoConcatDir isDirectory:&isdir]) {
        BOOL isCreatSuccess=[fileManager createDirectoryAtPath:videoConcatDir
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:nil];
        if (!isCreatSuccess) {
            NSLog(@"[Error] create directory fail");
            videoConcatDir = videoDir;
        }
    }
    return videoConcatDir;
}

+ (NSLock *)ffmpegProcessCancelLock {
    static NSLock * sFFmpegProcessCancel;
    static dispatch_once_t sOnceToken;
    
    dispatch_once(&sOnceToken, ^{
        sFFmpegProcessCancel = [[NSLock alloc] init];
    });
    return sFFmpegProcessCancel;
}

+ (void)ffmpeg_reset_cancel {
    [[YMTinyVideoFFmpeg ffmpegProcessCancelLock] lock];
    ffmpeg_process_cacelled = NO;
    [[YMTinyVideoFFmpeg ffmpegProcessCancelLock] unlock];
}

+ (BOOL)is_ffmpeg_canceled {
    BOOL isLock = NO;
    [[YMTinyVideoFFmpeg ffmpegProcessCancelLock] lock];
    isLock = ffmpeg_process_cacelled;
    [[YMTinyVideoFFmpeg ffmpegProcessCancelLock] unlock];
    
    return isLock;
}

+ (void)ffmpeg_exit {
    [[YMTinyVideoFFmpeg ffmpegProcessCancelLock] lock];
    if (ffmpeg_running) {
        ffmpeg_process_cacelled = YES;
    }
    [[YMTinyVideoFFmpeg ffmpegProcessCancelLock] unlock];
}

+ (int)ffmpeg_cmd:(libffmpeg_instance_t *)p_md
             argnumbers:(NSInteger)numberOfArgs
              arguments:(char **)arguments {
    return ffmpeg_main(p_md, (int)numberOfArgs, arguments);
}

void runOnMainQueue(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

void runAsynOnVideoProcessingQueue(void (^block)(void)) {
    dispatch_queue_t videoProcessingQueue = [YMTinyVideoFFmpegContext sharedContextQueue];
    if (dispatch_get_specific([YMTinyVideoFFmpegContext contextKey])) {
        block();
    } else {
        dispatch_async(videoProcessingQueue, block);
    }
}

+ (NSString *)argsConvert:(const char **)arguments {
    NSString *result = [[NSString alloc] init];
    if (!arguments) {
        return nil;
    }
    int i= 0;
    char *argc = (char *)*(arguments+i);
    while (argc) {
        NSString *argcStr = [NSString stringWithCString:argc encoding:NSUTF8StringEncoding];
        if (!argcStr) {
            break;
        }
        result = [result stringByAppendingString:argcStr];
        result = [result stringByAppendingString:@" "];
        i++;
        argc = (char *)*(arguments+i);
    }
    return result;
}

@end
