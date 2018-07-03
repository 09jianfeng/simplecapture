//
//  AudioItem.h
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AudioItem : NSObject

/**
 音频文件路径
 */
@property (nonatomic, copy) NSString *audioPath;

/**
 音频裁剪区间的开始时刻，相对于音频的timeline。单位:s
 比如 startTime=1.0f 表示使用该音频第1s及以后的内容
 默认为0.0f
 */
@property (atomic, assign) CGFloat startTime;

/**
 音频裁剪区间的持续时长，单位:s
 默认为0.0f
 */
@property (atomic, assign) CGFloat duration;

/**
 音频开始播放的时刻，相对于合成后的timeline。单位:s
 比如 displayTime=1.0f 表示从第1s开始播放。
 默认为0.0f
 */
@property (atomic, assign) CGFloat displayTime;

/**
 音频播放的时长，相对于合成后的timeline。单位:s
 默认为文件长度
 */
@property (atomic, assign) CGFloat displayDuration;

/**
 相对displayTime的偏移,主要用于调节同步问题，通常为0.0f。单位:s
 默认为0.0f
 */
@property (nonatomic, assign) CGFloat offsetTime;

/**
 音频音量倍率，1.0f为原始音量
 默认为1.0f
 */
@property (atomic, assign) CGFloat volume;

/**
 音频的扩展信息，目前支持：
 kYMTinyVideoAudioExtDataRhythmFile  节奏配置文件
 */
@property (nonatomic, strong) NSDictionary *extData;

@property (atomic, assign) BOOL loop;

@end
