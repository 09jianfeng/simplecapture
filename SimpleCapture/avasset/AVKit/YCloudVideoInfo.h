//
//  YCloudVideoInfo.h
//  YCloudRecorderDev
//
//  Created by 包红来 on 15/8/18.
//  Copyright (c) 2015年 包红来. All rights reserved.
//

#import "YMTinyVideoObject.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface YCloudVideoInfo : YMTinyVideoObject

@property (nonatomic, copy, readonly) NSString *filePath;

/**
 *  @author baohonglai, 15-08-21 20:08:30
 *
 *  返回视频的宽(如果视频是带旋转角度的,这是返回旋转前的宽)
 */
@property(nonatomic,readonly) NSInteger width;

/**
 *  @author baohonglai, 15-08-21 20:08:43
 *
 *  返回视频的高(如果视频是带旋转角度的,这是返回旋转前的高)
 */
@property(nonatomic,readonly) NSInteger height;

/**
 *  返回视频的宽(如果视频是带旋转角度的,这是返回旋转后的宽)
 */
@property(nonatomic,readonly) NSInteger rotatedWidth;

/**
 *  返回视频的高(如果视频是带旋转角度的,这是返回旋转后的高)
 */
@property(nonatomic,readonly) NSInteger rotatedHeight;

/**
 *  @author baohonglai, 15-08-21 20:08:54
 *
 *  获取视频的总的帧数
 */
@property(nonatomic,readonly) NSInteger nb_frames;

/**
 *  @author baohonglai, 15-08-21 20:08:15
 *
 *  获取视频的总的时长
 */
@property(nonatomic,readonly) CGFloat   duration;

/**
 * @brief 视频startime
 */
@property(nonatomic,readonly) CGFloat start_time;
@property(nonatomic,readonly) NSInteger rotate;
@property(nonatomic,readonly) NSInteger video_bitrate;
@property(nonatomic,readonly) CGFloat   audio_duration;
@property(nonatomic,readonly) CGFloat   audio_start_time;
@property(nonatomic,readonly) NSInteger   fps;

/**
 *  @author baohonglai, 16-01-07 17:01:50
 *
 *  音频的声道数
 */
@property (nonatomic,readonly) NSInteger audioChannels;


-(instancetype)initWithPath:(NSString *)filePath;

@end
