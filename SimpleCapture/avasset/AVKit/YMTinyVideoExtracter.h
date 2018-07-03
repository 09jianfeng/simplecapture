//
//  YMTinyVideoExtracter.h
//  yymediarecordersdk
//
//  Created by 陈俊明 on 11/10/17.
//  Copyright © 2017 yy.com. All rights reserved.
//

#ifndef YMTinyVideoExtracter_h
#define YMTinyVideoExtracter_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void(^YMTinyVideoECompletionBlock)(void);
typedef void(^YMTinyVideoEFailureBlock)(void);

@interface YMTinyVideoExtracter : NSObject

+ (void)extractVideoFromVideo:(NSString *)videoPath
                   outputPath:(NSString *)outputPath
              completionBlock:(YMTinyVideoECompletionBlock)completionBlock
                 failureBlock:(YMTinyVideoEFailureBlock)failureBlock;

+ (void)extractAudioFromVideo:(NSString *)videoPath
                    startTime:(CGFloat)startTime
                     duration:(CGFloat)duration
                   outputPath:(NSString *)outputPath
              completionBlock:(YMTinyVideoECompletionBlock)completionBlock
                 failureBlock:(YMTinyVideoEFailureBlock)failureBlock;

@end

#endif /* YMTinyVideoExtracter_h */
