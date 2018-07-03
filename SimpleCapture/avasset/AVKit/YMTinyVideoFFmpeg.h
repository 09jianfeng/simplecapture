//
//  YMTinyVideoFFmpeg.h
//  yymediarecordersdk
//
//  Created by 陈俊明 on 12/21/17.
//  Copyright © 2017年 yy.com. All rights reserved.
//

#import "YCloudVideoInfo.h"
#import "ffmpeg.h"
#import "libffmpeg_event.h"

@interface YMTinyVideoFFmpeg : NSObject

+ (NSString *)getDefaultFileName:(NSString *)videoName
                   withExtension:(NSString *)extension;

+ (NSString *)getDefaultFileDir:(NSString *)videoDir
                       pathment:(NSString *)pathComponent;

+ (void)ffmpeg_reset_cancel;

+ (BOOL)is_ffmpeg_canceled;

+ (void)ffmpeg_exit;

+ (int)ffmpeg_cmd:(libffmpeg_instance_t *)p_md
             argnumbers:(NSInteger)numberOfArgs
              arguments:(char **)arguments;

void runOnMainQueue(void (^block)(void));
void runAsynOnVideoProcessingQueue(void (^block)(void));

+ (NSString *)argsConvert:(const char **)arguments;

@end
