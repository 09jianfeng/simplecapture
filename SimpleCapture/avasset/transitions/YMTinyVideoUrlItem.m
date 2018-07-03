//
//  YMTinyVideoUrlItem.m
//  ymplayerdemo
//
//  Created by bleach on 2017/7/19.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "YMTinyVideoUrlItem.h"

@implementation YMTinyVideoUrlItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _transitionType = YM_TINYVIDEO_TRANSITION_NONE;
        _desiredTransitionDuration = 0.0f;
        _videoVolume = 1.0f;
        _volumeStartTime = 0.0f;
        _startTime = 0.0f;
        _duration = 0.0f;
    }
    
    return self;
}

- (instancetype)initWithVideoUrl:(NSURL *)videoUrl {
    self = [super init];
    if (self) {
        _videoUrl = videoUrl;
        _transitionType = YM_TINYVIDEO_TRANSITION_NONE;
        _desiredTransitionDuration = 0.0f;
        _videoVolume = 1.0f;
        _volumeStartTime = 0.0f;
        _startTime = 0.0f;
        _duration = 0.0f;
    }
    
    return self;
}

- (instancetype)initWithVideoUrl:(NSURL *)videoUrl transitionType:(YMTinyVideoTransitionType)transitionType desiredTransitionDuration:(CGFloat)desiredTransitionDuration {
    self = [super init];
    if (self) {
        _videoUrl = videoUrl;
        _transitionType = transitionType;
        _desiredTransitionDuration = desiredTransitionDuration;
        _videoVolume = 1.0f;
        _volumeStartTime = 0.0f;
        _startTime = 0.0f;
        _duration = 0.0f;
    }
    
    return self;
}

- (void)setPreTransitionDuration:(CGFloat)preTransitionDuration {
    _preTransitionDuration = preTransitionDuration;
}

- (void)setNextTransitionDuration:(CGFloat)nextTransitionDuration {
    _nextTransitionDuration = nextTransitionDuration;
}

- (void)setVideoVolume:(CGFloat)videoVolume {
    _videoVolume = videoVolume;
}

- (void)setVolumeStartTime:(CGFloat)volumeStartTime {
    _volumeStartTime = volumeStartTime;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[YMTinyVideoUrlItem class]]) {
        return NO;
    }
    
    YMTinyVideoUrlItem * item = (YMTinyVideoUrlItem *)object;
    if (![self.videoUrl.path isEqualToString:item.videoUrl.path]) {
        return NO;
    }
    if (!(self.transitionType == item.transitionType)) {
        return NO;
    }
    if (!(self.desiredTransitionDuration == item.desiredTransitionDuration)) {
        return NO;
    }
    if (!(self.startTime == item.startTime)) {
        return NO;
    }
    if (!(self.duration == item.duration)) {
        return NO;
    }
    
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    YMTinyVideoUrlItem * item = [[[self class] allocWithZone:zone] init];
    item.videoUrl = [self.videoUrl copy];
    item.videoInfo = self.videoInfo;
    item.transitionType = self.transitionType;
    item.desiredTransitionDuration = self.desiredTransitionDuration;
    item.transitionAudioUrl = [self.transitionAudioUrl copy];
    item.startTime = self.startTime;
    item.duration = self.duration;
    item.preTransitionDuration = self.preTransitionDuration;
    item.nextTransitionDuration = self.nextTransitionDuration;
    item.videoVolume = self.videoVolume;
    item.volumeStartTime = self.volumeStartTime;
    return item;
}

@end
