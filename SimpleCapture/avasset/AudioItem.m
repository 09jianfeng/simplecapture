//
//  AudioItem.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "AudioItem.h"

@implementation AudioItem

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _audioPath = nil;
        _startTime = 0.0f;
        _duration = 0.0f;
        _displayTime = 0.0f;
        _offsetTime = 0.0f;
        _volume = 1.0f;
        _extData = nil;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    AudioItem *audioItem = [[[self class] allocWithZone:zone] init];
    audioItem.audioPath = [self.audioPath copy];
    audioItem.startTime = self.startTime;
    audioItem.duration = self.duration;
    audioItem.displayTime = self.displayTime;
    audioItem.offsetTime = self.offsetTime;
    audioItem.volume = self.volume;
    audioItem.extData = [self.extData copy];
    return audioItem;
}

- (BOOL)isEqualToObject:(id)object {
    AudioItem *audioItem = (AudioItem *)object;
    BOOL ret1 = ([audioItem.audioPath isEqualToString:self.audioPath]);
    BOOL ret2 = (audioItem.startTime == self.startTime);
    BOOL ret3 = (audioItem.duration == self.duration);
    BOOL ret4 = (audioItem.displayTime == self.displayTime);
    BOOL ret5 = (audioItem.offsetTime == self.offsetTime);
    BOOL ret6 = (audioItem.volume == self.volume);
    BOOL ret7 = ([audioItem.extData isEqual:self.extData]);
    return ret1 && ret2 && ret3 && ret4 && ret5 && ret6 && ret7;
}

@end
