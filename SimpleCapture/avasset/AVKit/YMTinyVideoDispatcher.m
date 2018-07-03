//
//  YMTinyVideoDispatcher.m
//  yymediarecordersdk
//
//  Created by 陈俊明 on 2018/2/27.
//  Copyright © 2018 yy.com. All rights reserved.
//

#import "YMTinyVideoDispatcher.h"

void dispatch_to_main_queue(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@class YMTinyVideoDisptacher;

void dispatch_sync_task(YMTinyVideoDispatcher *dispatcher, dispatch_block_t block) {
    if (dispatcher == nil) {
        return;
    }
    if (block == nil) {
        return;
    }
    
    if (dispatch_get_specific(dispatcher.queueKey) != NULL) {
        block();
    } else {
        dispatch_queue_t queue = dispatcher.queue;
        if (queue == nil) {
            return;
        }
        dispatch_sync(queue, ^(){
            block();
        });
    }
}

void dispatch_async_task(YMTinyVideoDispatcher *dispatcher, dispatch_block_t block) {
    if (dispatcher == nil) {
        return;
    }
    if (block == nil) {
        return;
    }
    
    if (dispatch_get_specific(dispatcher.queueKey) != NULL) {
        block();
    } else {
        dispatch_queue_t queue = dispatcher.queue;
        if (queue == nil) {
            return;
        }
        dispatch_async(queue, ^(){
            block();
        });
    }
}

@interface YMTinyVideoDispatcher () {
    void *_queueKey;
}

@property (nonatomic, strong, readwrite) dispatch_queue_t queue;

@end

@implementation YMTinyVideoDispatcher

+ (instancetype)getPublicDispatcher {
    static YMTinyVideoDispatcher *sDispatcher = nil;
    if (sDispatcher == nil) {
        sDispatcher = [[YMTinyVideoDispatcher alloc] initWithQueueName:@"com.yy.yymediarecordersdk.public"];
    }
    return sDispatcher;
}

- (instancetype)init {
    return [[YMTinyVideoDispatcher alloc] initWithQueueName:nil];
}

- (instancetype)initWithQueueName:(NSString *)queueName {
    self = [super init];
    if (self != nil) {
        _queueKey = &_queueKey;
        NSString *name = [NSString stringWithFormat:@"%p", self];
        if (queueName != nil) {
            name = queueName;
        }
        const char *queueCName = [name UTF8String];
        _queue = dispatch_queue_create(queueCName, DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_queue, _queueKey, (__bridge void *)(self), NULL);
    }
    return self;
}

- (void *)queueKey {
    return _queueKey;
}

@end
