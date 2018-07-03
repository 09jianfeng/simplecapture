//
//  YMTinyVideoCompositionEditor.h
//  yymediarecordersdk
//
//  Created by bleach on 2017/8/14.
//  Copyright © 2017年 yy.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "VideoItem.h"
#import "AudioItem.h"
#import "YMCommon.h"

#define YM_TINYVIDEO_NORMAL_FPS 30
#define YM_TINYVIDEO_PLAYER_FPS 60

@class YMTinyVideoUrlItem;
@interface YMTinyVideoClipItem : NSObject

@property (nonatomic, strong) YMTinyVideoUrlItem * clipUrlItem;
@property (nonatomic, strong) AVURLAsset * clip;
@property (nonatomic, assign) YMTinyVideoTransitionType transitionType;
@property (nonatomic, assign) CGFloat desiredTransitionDuration;            //希望设置的转场时长
@property (nonatomic, assign) CMTime preTransitionDurationTime;             //根据视频长度,实际选择的转场时长
@property (nonatomic, assign) CMTime nextTransitionDurationTime;            //根据视频长度,实际选择的转场时长
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) CMTimeRange clipTimeRange;
@property (nonatomic, assign) CMTimeRange passThroughTimeRange;
@property (nonatomic, assign) CMTimeRange transitionTimeRange;
@property (nonatomic, strong) NSURL * transitionAudioUrl;
@property (nonatomic, assign) CGFloat videoVolume;
@property (nonatomic, assign) CGFloat volumeStartTime;

@property (nonatomic, assign) CGFloat rotateAngle;

@end

@class YMTinyVideoUrlItem;

@interface YMTinyVideoCompositionEditor : NSObject

@property (nonatomic, strong) AVMutableComposition * composition;
@property (nonatomic, strong) AVMutableVideoComposition * videoComposition;
@property (nonatomic, strong) AVMutableAudioMix * audioMix;
@property (nonatomic, assign, readonly) YMROrientation videoOrientation;

- (instancetype)initWithVideoItems:(NSArray<VideoItem *> *)videoItems audioItems:(NSArray<AudioItem *> *)audioItems;

- (instancetype)initWithUrlItems:(NSArray<YMTinyVideoUrlItem *> *)urlItems;
- (instancetype)initWithUrlItems:(NSArray<YMTinyVideoUrlItem *> *)urlItems audioItems:(NSArray<AudioItem *> *)audioItems videoVolume:(CGFloat)videoVolume;

- (void)buildAVComposition;

- (void)buildCropAVComposition:(CGSize)outputSize cropRect:(CGRect)cropRect fps:(NSInteger)fps;

- (void)buildVideoComposition;

- (void)buildAudioComposition;

- (void)buildMultiVideoAudioComposition;

+ (CGFloat)videoTrackOrientationDegree:(AVAssetTrack *)videoTrack;

+ (CGFloat)videoTrackOrientationRadian:(AVAssetTrack *)videoTrack;

+ (CGFloat)videoOrientationDegree:(AVAsset *)asset;

+ (CGFloat)videoOrientationRadian:(AVAsset *)asset;

+ (YMROrientation)videoOrientation:(AVAsset *)asset;

@end
