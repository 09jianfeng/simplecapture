//
//  YMTinyVideoUrlItem.h
//  ymplayerdemo
//
//  Created by bleach on 2017/7/19.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YMCommon.h"

@class YCloudVideoInfo;
@interface YMTinyVideoUrlItem : NSObject

@property (nonatomic, strong) NSURL * videoUrl;
@property (nonatomic, strong) YCloudVideoInfo * videoInfo;
@property (nonatomic, assign) YMTinyVideoTransitionType transitionType;         //转场动画类型,决定当前视频结束的时候以哪个动画做转场(最后一个视频无转场)
@property (nonatomic, assign) CGFloat desiredTransitionDuration;
@property (nonatomic, strong) NSURL * transitionAudioUrl;                       //转场声音

// 选择使用视频的区间段
@property (nonatomic, assign) CGFloat startTime;
@property (nonatomic, assign) CGFloat duration;
@property (nonatomic, assign) CGFloat rotateAngle;

@property (nonatomic, readonly, assign) CGFloat preTransitionDuration;
@property (nonatomic, readonly, assign) CGFloat nextTransitionDuration;
@property (nonatomic, readonly, assign) CGFloat videoVolume;
@property (nonatomic, readonly, assign) CGFloat volumeStartTime;

- (instancetype)initWithVideoUrl:(NSURL *)videoUrl;
- (instancetype)initWithVideoUrl:(NSURL *)videoUrl transitionType:(YMTinyVideoTransitionType)transitionType desiredTransitionDuration:(CGFloat)desiredTransitionDuration;
- (void)setPreTransitionDuration:(CGFloat)preTransitionDuration;
- (void)setNextTransitionDuration:(CGFloat)nextTransitionDuration;
- (void)setVideoVolume:(CGFloat)videoVolume;
- (void)setVolumeStartTime:(CGFloat)volumeStartTime;

@end
