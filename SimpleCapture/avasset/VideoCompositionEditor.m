//
//  VideoCompositionEditor.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "VideoCompositionEditor.h"
#import "ffmpeg.h"

@implementation VideoCompositionEditor


void addTinyVideoGpuFilter(AVFrame * frame,void * user,double pts) {
}

void YMTinyVideoFFmpegLog(const char * __restrict fmt, ...) {
    va_list arglist;
    va_start(arglist, fmt);
    NSString *infoString = [[NSString alloc] initWithFormat:@(fmt) arguments:arglist];
    va_end(arglist);
    NSString *logString = [NSString stringWithFormat:@"[kLogModule_FFmpeg]%@",infoString];
    
    NSLog(@"[yymediarecordersdk][Error]%@", logString);
}
@end
