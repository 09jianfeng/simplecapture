//
//  YMTinyVideoDispatcher.h
//  yymediarecordersdk
//
//  Created by 陈俊明 on 2018/2/27.
//  Copyright © 2018 yy.com. All rights reserved.
//

#ifndef YMTinyVideoDispatcher_h
#define YMTinyVideoDispatcher_h

#import <Foundation/Foundation.h>

@class YMTinyVideoDispatcher;

typedef void (^YMTinyVideoDispatchBlock)(void);

#if defined __cplusplus
extern "C" {
#endif
    
    void dispatch_to_main_queue(YMTinyVideoDispatchBlock block);
    void dispatch_sync_task(YMTinyVideoDispatcher *dispatcher, YMTinyVideoDispatchBlock block);
    void dispatch_async_task(YMTinyVideoDispatcher *dispatcher, YMTinyVideoDispatchBlock block);
    
#if defined __cplusplus
};
#endif

@interface YMTinyVideoDispatcher : NSObject

@property (nonatomic, strong, readonly) dispatch_queue_t queue;

+ (instancetype)getPublicDispatcher;

- (instancetype)initWithQueueName:(NSString *)queueName;
- (void *)queueKey;

@end

#endif /* YMTinyVideoDispatcher_h */
