//
//  YMTinyVideoCompositionInstruction.m
//  ymplayerdemo
//
//  Created by bleach on 2017/7/19.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "YMTinyVideoCompositionInstruction.h"

@implementation YMTinyVideoCompositionInstruction

@synthesize timeRange = _timeRange;
@synthesize enablePostProcessing = _enablePostProcessing;
@synthesize containsTweening = _containsTweening;
@synthesize requiredSourceTrackIDs = _requiredSourceTrackIDs;
@synthesize passthroughTrackID = _passthroughTrackID;

- (instancetype)initPassThroughTrackID:(CMPersistentTrackID)passthroughTrackID forTimeRange:(CMTimeRange)timeRange {
    self = [super init];
    if (self) {
        _transitionType = YM_TINYVIDEO_TRANSITION_NONE;
        _passthroughTrackID = passthroughTrackID;
        _requiredSourceTrackIDs = nil;
        _timeRange = timeRange;
        _containsTweening = NO;
        _enablePostProcessing = NO;
    }
    
    return self;
}

- (instancetype)initTransitionWithSourceTrackIDs:(NSArray *)sourceTrackIDs forTimeRange:(CMTimeRange)timeRange {
    self = [super init];
    if (self) {
        _transitionType = YM_TINYVIDEO_TRANSITION_NONE;
        _requiredSourceTrackIDs = sourceTrackIDs;
        _passthroughTrackID = kCMPersistentTrackID_Invalid;
        _timeRange = timeRange;
        _containsTweening = YES;
        _enablePostProcessing = NO;
    }
    
    return self;
}


@end
