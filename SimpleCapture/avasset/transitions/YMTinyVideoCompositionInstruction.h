//
//  YMTinyVideoCompositionInstruction.h
//  ymplayerdemo
//
//  Created by bleach on 2017/7/19.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "YMCommon.h"

@interface YMTinyVideoCompositionInstruction : NSObject<AVVideoCompositionInstruction>

@property (nonatomic, assign) YMTinyVideoTransitionType transitionType;
@property (nonatomic, assign) CMPersistentTrackID preTrackID;
@property (nonatomic, assign) CMPersistentTrackID nextTrackID;

- (instancetype)initPassThroughTrackID:(CMPersistentTrackID)passthroughTrackID forTimeRange:(CMTimeRange)timeRange;
- (instancetype)initTransitionWithSourceTrackIDs:(NSArray*)sourceTrackIDs forTimeRange:(CMTimeRange)timeRange;

@end
