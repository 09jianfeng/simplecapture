//
//  YMTinyVideoFFmpegContext.m
//  yymediarecordersdk
//
//  Created by 陈俊明 on 12/21/17.
//  Copyright © 2017年 yy.com. All rights reserved.
//

#import "YMTinyVideoFFmpegContext.h"

@implementation YMTinyVideoFFmpegContext

@synthesize videoContextQueue = _videoContextQueue;

static void * videoProceContextQueueKey;

- (instancetype)init {
    if (self = [super init]) {
        _videoContextQueue = dispatch_queue_create("com.ycloud.recorder", DISPATCH_QUEUE_SERIAL);
        videoProceContextQueueKey = &videoProceContextQueueKey;
        dispatch_queue_set_specific(_videoContextQueue, videoProceContextQueueKey, (__bridge void *)self, NULL);
    }
    return self;
}

+ (YMTinyVideoFFmpegContext *)sharedVideoProcessingContext {
    static dispatch_once_t pred;
    static YMTinyVideoFFmpegContext * sharedVideoProcessingContext = nil;
    
    dispatch_once(&pred, ^{
        sharedVideoProcessingContext = [[[self class] alloc] init];
    });
    return sharedVideoProcessingContext;
}

+ (dispatch_queue_t)sharedContextQueue {
    return [[self sharedVideoProcessingContext] videoContextQueue];
}

+ (void *)contextKey {
    return videoProceContextQueueKey;
}

@end
