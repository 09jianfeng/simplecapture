//
//  YMTinyVideoFFmpegContext.h
//  yymediarecordersdk
//
//  Created by 陈俊明 on 12/21/17.
//  Copyright © 2017年 yy.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YMTinyVideoFFmpegContext : NSObject

@property(readonly, nonatomic) dispatch_queue_t videoContextQueue;

+ (void *)contextKey;
+ (dispatch_queue_t) sharedContextQueue;

@end
