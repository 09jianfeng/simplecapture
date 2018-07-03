//
//  VideoItem.h
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface VideoItem : NSObject
/**
 视频文件路径
 */
@property (nonatomic, copy) NSString *videoPath;

/**
 视频裁剪区间的开始时刻，相对于视频的timeline。单位:s
 比如 startTime=1.0f 表示使用该视频第1s及以后的内容
 默认为0.0f
 */
@property (nonatomic, assign) CGFloat startTime;

/**
 视频裁剪区间的持续时长，单位:s
 默认为0.0f
 */
@property (nonatomic, assign) CGFloat duration;

/**
 视频音量倍率，1.0f为原始音量
 默认为1.0f
 */
@property (nonatomic, assign) CGFloat volume;

@property (nonatomic, assign) CGFloat rotateAngle;

/**
 视频的扩展信息，包含该视频每帧的扩展信息，目前支持：
  */
@property (nonatomic, strong) NSDictionary *extData;

@end
