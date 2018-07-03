//
//  VideoItem.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "VideoItem.h"

@implementation VideoItem

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _videoPath = nil;
        _startTime = 0.0f;
        _duration = 0.0f;
        _volume = 1.0f;
        _rotateAngle = 0.0f;
        _extData = nil;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    VideoItem *videoItem = [[[self class] allocWithZone:zone] init];
    videoItem.videoPath = [self.videoPath copy];
    videoItem.startTime = self.startTime;
    videoItem.duration = self.duration;
    videoItem.volume = self.volume;
    videoItem.rotateAngle = self.rotateAngle;
    videoItem.extData = [self.extData copy];
    return videoItem;
}

- (BOOL)isEqualToObject:(id)object {
    VideoItem *videoItem = (VideoItem *)object;
    BOOL ret1 = ([videoItem.videoPath isEqualToString:self.videoPath]);
    BOOL ret2 = (videoItem.volume == self.volume);
    BOOL ret3 = (videoItem.startTime == self.startTime);
    BOOL ret4 = (videoItem.duration == self.duration);
    BOOL ret5 = (videoItem.rotateAngle == self.rotateAngle);
    BOOL ret6 = (videoItem.extData == self.extData);
    return ret1 && ret2 && ret3 && ret4 && ret5 && ret6;
}

- (void)setStartTime:(CGFloat)startTime {
    _startTime = startTime;
    if (_startTime < 0.0f) {
        _startTime = 0.0f;
    }
}

- (void)setDuration:(CGFloat)duration {
    _duration = duration;
    if (_duration < 0.0f) {
        _duration = 0.0f;
    }
}

- (void)setVolume:(CGFloat)volume {
    _volume = volume;
    if (_volume < 0.0f) {
        _volume = 0.0f;
    }
}

@end
