//
//  YMTinyVideoCompositionEditor.m
//  yymediarecordersdk
//
//  Created by bleach on 2017/8/14.
//  Copyright © 2017年 yy.com. All rights reserved.
//

#import "YMTinyVideoCompositionEditor.h"
#import "YMTinyVideoCompositor.h"
#import "YMTinyVideoUrlItem.h"
#import "AudioItem.h"
#import "YMTinyVideoCompositionInstruction.h"
#import "YCloudVideoInfo.h"
#import "VideoFileKit.h"
//#import "YCloudTranscode.h"

@implementation YMTinyVideoClipItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _clip = nil;
        _transitionType = YM_TINYVIDEO_TRANSITION_NONE;
        _preTransitionDurationTime = kCMTimeZero;
        _nextTransitionDurationTime = kCMTimeZero;
        _videoSize = CGSizeZero;
        _clipTimeRange = kCMTimeRangeZero;
        _passThroughTimeRange = kCMTimeRangeZero;
        _transitionTimeRange = kCMTimeRangeZero;
        _videoVolume = 1.0f;
        _volumeStartTime = 0.0f;
        _rotateAngle = 0.0f;
    }
    return self;
}

@end

@interface YMTinyVideoCompositionEditor()

@property (nonatomic, strong) NSMutableArray * clipItems;
@property (nonatomic, strong) NSArray<AudioItem *> *audioItems;
@property (nonatomic, assign) CGFloat videoVolume;
@property (nonatomic, assign) YMROrientation videoOrientation;

@end

@implementation YMTinyVideoCompositionEditor

- (instancetype)initWithVideoItems:(NSArray<VideoItem *> *)videoItems audioItems:(NSArray<AudioItem *> *)audioItems {
    NSMutableArray<YMTinyVideoUrlItem *> *urlItems = nil;
    for (VideoItem *videoItem in videoItems) {
        if (urlItems == nil) {
            urlItems = [NSMutableArray array];
        }
        NSURL *videoURL = [VideoFileKit pathToFileUrl:videoItem.videoPath];
        YMTinyVideoUrlItem *urlItem = [[YMTinyVideoUrlItem alloc] initWithVideoUrl:videoURL];
        urlItem.startTime = videoItem.startTime;
        urlItem.duration = videoItem.duration;
        urlItem.rotateAngle = videoItem.rotateAngle;
        [urlItems addObject:urlItem];
    }
    return [[YMTinyVideoCompositionEditor alloc] initWithUrlItems:urlItems audioItems:audioItems videoVolume:videoItems.firstObject.volume];
}

- (instancetype)initWithUrlItems:(NSArray<YMTinyVideoUrlItem *> *)urlItems {
    self = [super init];
    if (self) {
        [self doInit:urlItems audioItems:nil videoVolume:0.0f];
    }
    return self;
}

- (instancetype)initWithUrlItems:(NSArray<YMTinyVideoUrlItem *> *)urlItems audioItems:(NSArray<AudioItem *> *)audioItems videoVolume:(CGFloat)videoVolume {
    self = [super init];
    if (self) {
        [self doInit:urlItems audioItems:audioItems videoVolume:videoVolume];
    }
    return self;
}

- (void)dealloc {
    
}

- (void)doInit:(NSArray<YMTinyVideoUrlItem *> *)urlItems audioItems:(NSArray<AudioItem *> *)audioItems videoVolume:(CGFloat)videoVolume {
    _audioItems = audioItems;
    _videoVolume = videoVolume;
    _clipItems = [[NSMutableArray alloc] initWithCapacity:urlItems.count];
    _videoOrientation = YMR_ORIENTATION_NOTFOUND;
    
    NSInteger index = 0;
    NSDictionary * options = @{AVURLAssetPreferPreciseDurationAndTimingKey:@YES};
    for (YMTinyVideoUrlItem * urlItem in urlItems) {
        if (![VideoFileKit isReadableFileAtPath:urlItem.videoUrl.path]) {
            NSLog(@"file not readable %@", urlItem.videoUrl.path);
            continue;
        }
        
        if (![VideoFileKit existFileAtPath:urlItem.videoUrl.path]) {
            NSLog(@"file not exist %@", urlItem.videoUrl.path);
            continue;
        }
        
        AVURLAsset * asset = [AVURLAsset URLAssetWithURL:urlItem.videoUrl options:options];
        if (asset == nil) {
            NSLog(@"asset is nil %@", urlItem.videoUrl.path);
            continue;
        }
        
        if (CMTimeCompare(asset.duration, kCMTimeZero) == 0) {
            NSLog(@"duration is zero %@", urlItem.videoUrl.path);
            continue;
        }
        
        if ([asset tracksWithMediaType:AVMediaTypeVideo].count > 0) {
            YMTinyVideoClipItem * clipItem = [[YMTinyVideoClipItem alloc] init];
            clipItem.clipUrlItem = urlItem;
            clipItem.clip = asset;
            clipItem.transitionType = urlItem.transitionType;
            clipItem.desiredTransitionDuration = urlItem.desiredTransitionDuration;
            clipItem.videoVolume = urlItem.videoVolume;
            clipItem.volumeStartTime = urlItem.volumeStartTime;
            clipItem.rotateAngle = urlItem.rotateAngle;
            
            AVAssetTrack * videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] lastObject];
            
            clipItem.videoSize = [videoTrack naturalSize];
            
            CGFloat videoStartTime = CMTimeGetSeconds(videoTrack.timeRange.start);
            CGFloat videoDuration = CMTimeGetSeconds(videoTrack.timeRange.duration);
            
            if (index == 0) {
                YCloudVideoInfo * videoInfo = [[YCloudVideoInfo alloc] initWithPath:urlItem.videoUrl.path];
                videoStartTime = videoInfo.start_time + 0.001f;
                videoDuration = videoInfo.duration;
            }
            CGFloat videoEndTime = videoStartTime + videoDuration;
            
            CGFloat finalStartTime = urlItem.startTime;
            if (urlItem.startTime <= videoStartTime) {
                finalStartTime = videoStartTime;
            }
            if (urlItem.startTime >= videoEndTime) {
                NSLog(@"Invalid startTime %f,%f", urlItem.startTime, videoEndTime);
                continue;
            }
            
            CGFloat finalDuration = videoEndTime - finalStartTime;
            if (urlItem.duration > 0.0f && urlItem.duration < finalDuration) {
                finalDuration = urlItem.duration;
            }
            
            clipItem.clipTimeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(finalStartTime, 1000), CMTimeMakeWithSeconds(finalDuration, 1000));
            
            clipItem.transitionAudioUrl = urlItem.transitionAudioUrl;
            [_clipItems addObject:clipItem];
        } else {
            NSLog(@"video track count is zero %@", urlItem.videoUrl.path);
        }
        
        index++;
    }
    
    // 计算转场时长
    [self updateTransitionDurations];
}

- (void)updateTransitionDurations {
    for (NSInteger index = 0; index < _clipItems.count; index++) {
        YMTinyVideoClipItem * clipItem = [_clipItems objectAtIndex:index];
        CMTime transitionDurationTime = kCMTimeInvalid;
        if (clipItem.transitionType == YM_TINYVIDEO_TRANSITION_NONE || CMTimeGetSeconds(clipItem.clipTimeRange.duration) < YM_TINYVIDEO_MIN_TRANSITION_VIDEO_DURATION) {
            clipItem.desiredTransitionDuration = 0.0f;
        }
        CMTime desiredTransitionDurationTime = CMTimeMake(clipItem.desiredTransitionDuration * 1000, 1000);
        CMTime halfClipDuration = clipItem.clipTimeRange.duration;
        halfClipDuration.timescale *= 2;
        transitionDurationTime = CMTimeMinimum(desiredTransitionDurationTime, halfClipDuration);
        
        if ((index + 1) < _clipItems.count) {
            YMTinyVideoClipItem * nextClipItem = [_clipItems objectAtIndex:index + 1];
            halfClipDuration = nextClipItem.clipTimeRange.duration;
            halfClipDuration.timescale *= 2;
            transitionDurationTime = CMTimeMinimum(transitionDurationTime, halfClipDuration);
            nextClipItem.preTransitionDurationTime = transitionDurationTime;
            [nextClipItem.clipUrlItem setPreTransitionDuration:CMTimeGetSeconds(transitionDurationTime)];
            clipItem.nextTransitionDurationTime = transitionDurationTime;
            [clipItem.clipUrlItem setNextTransitionDuration:CMTimeGetSeconds(transitionDurationTime)];
            
            NSLog(@"index %ld, transitionDurationTime = %f", (long)index, CMTimeGetSeconds(transitionDurationTime));
        }
    }
}

- (void)buildAVComposition {
    if ([_clipItems count] == 0) {
        _composition = nil;
        _videoComposition = nil;
        NSLog(@"_clipItems count = 0");
        return;
    }
    
    AVMutableComposition * composition = [AVMutableComposition composition];
    YMTinyVideoClipItem * clipItem = _clipItems.firstObject;
    composition.naturalSize = clipItem.videoSize;
    
    AVMutableVideoComposition * videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, YM_TINYVIDEO_PLAYER_FPS);
    videoComposition.renderSize = clipItem.videoSize;
    videoComposition.customVideoCompositorClass = [YMTinyVideoCompositor class];
    
    AVMutableAudioMix * audioMix = [AVMutableAudioMix audioMix];
    
    [self buildAVTransitionComposition:composition videoComposition:videoComposition audioMix:audioMix outputSize:CGSizeZero cropRect:CGRectZero];
    
    self.composition = composition;
    self.videoComposition = videoComposition;
    self.audioMix = audioMix;
}

- (void)buildCropAVComposition:(CGSize)outputSize cropRect:(CGRect)cropRect fps:(NSInteger)fps {
    if ([_clipItems count] == 0) {
        _composition = nil;
        _videoComposition = nil;
        NSLog(@"_clipItems count = 0");
        return;
    }
    
    AVMutableComposition * composition = [AVMutableComposition composition];
    composition.naturalSize = outputSize;
    
    AVMutableVideoComposition * videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, (int32_t)fps);
    videoComposition.renderSize = outputSize;
    videoComposition.customVideoCompositorClass = nil;
    
    AVMutableAudioMix * audioMix = [AVMutableAudioMix audioMix];
    
    [self buildAVTransitionComposition:composition videoComposition:videoComposition audioMix:audioMix outputSize:outputSize cropRect:cropRect];
    
    self.composition = composition;
    self.videoComposition = videoComposition;
    self.audioMix = audioMix;
}

- (void)buildVideoComposition {
    if ([_clipItems count] == 0) {
        _composition = nil;
        _videoComposition = nil;
        NSLog(@"_clipItems count = 0");
        return;
    }
    
    AVMutableComposition * composition = [AVMutableComposition composition];
    YMTinyVideoClipItem * clipItem = _clipItems.firstObject;
    composition.naturalSize = clipItem.videoSize;
    
    AVMutableVideoComposition * videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, YM_TINYVIDEO_PLAYER_FPS);
    videoComposition.renderSize = clipItem.videoSize;
    videoComposition.customVideoCompositorClass = [YMTinyVideoCompositor class];
    
    [self buildVTransitionComposition:composition videoComposition:videoComposition];
    
    self.composition = composition;
    self.videoComposition = videoComposition;
}

- (void)buildAudioComposition {
    if ([_clipItems count] == 0) {
        _composition = nil;
        _videoComposition = nil;
        NSLog(@"_clipItems count = 0");
        return;
    }
    
    AVMutableComposition * composition = [AVMutableComposition composition];
    AVMutableAudioMix * audioMix = [AVMutableAudioMix audioMix];
    
    [self buildATransitionComposition:composition audioMix:audioMix];
    
    self.composition = composition;
    self.audioMix = audioMix;
}

- (void)buildMultiVideoAudioComposition {
    if ([_clipItems count] == 0) {
        _composition = nil;
        _videoComposition = nil;
        NSLog(@"_clipItems count = 0");
        return;
    }
    
    AVMutableComposition * composition = [AVMutableComposition composition];
    AVMutableAudioMix * audioMix = [AVMutableAudioMix audioMix];
    
    [self buildMultiVideoAComposition:composition audioMix:audioMix];
    
    self.composition = composition;
    self.audioMix = audioMix;
}

- (void)buildAVTransitionComposition:(AVMutableComposition *)composition videoComposition:(AVMutableVideoComposition *)videoComposition audioMix:(AVMutableAudioMix *)audioMix outputSize:(CGSize)outputSize cropRect:(CGRect)cropRect {
    if (_clipItems.count == 0) {
        NSLog(@"_clipItems.count == 0");
        return;
    }
    
    NSDictionary * options = @{AVURLAssetPreferPreciseDurationAndTimingKey:@YES};
    CMTime nextClipStartTime = kCMTimeZero;
    AVMutableCompositionTrack * compositionVideoTracks[2];
    AVMutableCompositionTrack * compositionAudioTracks[2];
    AVMutableCompositionTrack * compositionTransitionAudioTrack;
    NSMutableArray * inputParameters = [[NSMutableArray alloc] initWithCapacity:5];
    
    NSLog(@"_volumeAudioItems.videoVolume == %f", _videoVolume);
    
    /* 拼接视频片段 */
    for (NSInteger index = 0; index < _clipItems.count; index++) {
        NSInteger alternatingIndex = index % 2;
        YMTinyVideoClipItem * clipItem = [_clipItems objectAtIndex:index];
        
        /* 添加视频片段 */
        CMTimeRange timeRangeInAsset = clipItem.clipTimeRange;
        if (CMTimeRangeEqual(timeRangeInAsset, kCMTimeRangeZero)) {
            NSLog(@"timeRange is zero");
            continue;
        }
        
        if ([clipItem.clip tracksWithMediaType:AVMediaTypeVideo].count > 0) {
            if (compositionVideoTracks[alternatingIndex] == nil) {
                compositionVideoTracks[alternatingIndex] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            }
            AVAssetTrack * clipVideoTrack = [[clipItem.clip tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
            [compositionVideoTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipVideoTrack atTime:nextClipStartTime error:nil];
            [compositionVideoTracks[alternatingIndex] setPreferredTransform:clipVideoTrack.preferredTransform];
        }
        
        if ([[clipItem.clip tracksWithMediaType:AVMediaTypeAudio] count]) {
            if (compositionAudioTracks[alternatingIndex] == nil) {
                compositionAudioTracks[alternatingIndex] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            }
            AVAssetTrack * clipAudioTrack = [[clipItem.clip tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            [compositionAudioTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:nextClipStartTime error:nil];
            
            AVMutableAudioMixInputParameters * mixInput = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionAudioTracks[alternatingIndex]];
            mixInput.trackID = [compositionAudioTracks[alternatingIndex] trackID];
            [mixInput setVolume:_videoVolume atTime:nextClipStartTime];
            [inputParameters addObject:mixInput];
        }
        
        clipItem.passThroughTimeRange = CMTimeRangeMake(nextClipStartTime, timeRangeInAsset.duration);
        // 第一个视频不需要以转场开始
        if (index != 0) {
            clipItem.passThroughTimeRange = CMTimeRangeMake(CMTimeAdd(clipItem.passThroughTimeRange.start, clipItem.preTransitionDurationTime), CMTimeSubtract(clipItem.passThroughTimeRange.duration, clipItem.preTransitionDurationTime)) ;
        }
        // 最后一个视频不需要以转场结束
        if ((index + 1) < _clipItems.count) {
            clipItem.passThroughTimeRange = CMTimeRangeMake(clipItem.passThroughTimeRange.start, CMTimeSubtract(clipItem.passThroughTimeRange.duration, clipItem.nextTransitionDurationTime)) ;
        }
        
        nextClipStartTime = CMTimeAdd(nextClipStartTime, timeRangeInAsset.duration);
        nextClipStartTime = CMTimeSubtract(nextClipStartTime, clipItem.nextTransitionDurationTime);
        if ((index + 1) < _clipItems.count) {
            clipItem.transitionTimeRange = CMTimeRangeMake(nextClipStartTime, clipItem.nextTransitionDurationTime);
            
            if (clipItem.transitionAudioUrl != nil) {
                NSString * transCodePath = clipItem.transitionAudioUrl.path;
                
                if (transCodePath != nil) {
                    NSURL * transCodeUrl = [VideoFileKit pathToFileUrl:transCodePath];
                    if (transCodeUrl) {
                        AVURLAsset * audioAsset = [AVURLAsset URLAssetWithURL:transCodeUrl options:options];
                        if ([audioAsset tracksWithMediaType:AVMediaTypeAudio].count > 0) {
                            if (compositionTransitionAudioTrack == nil) {
                                compositionTransitionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                            }
                            [compositionTransitionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, clipItem.nextTransitionDurationTime) ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject] atTime:nextClipStartTime error:nil];
                        }
                    }
                }
            }
        }
    }
    
    if (_audioItems.count != 0) {
        NSUInteger index = 0;
        for (AudioItem * audioItem in _audioItems) {
            index++;
            NSString * transCodePath = audioItem.audioPath;
            YCloudVideoInfo * audioInfo = [[YCloudVideoInfo alloc] initWithPath:transCodePath];
            
            NSURL * transCodeUrl = [VideoFileKit pathToFileUrl:transCodePath];
            if (transCodeUrl == nil) {
                continue;
            }
            
            AVURLAsset * audioAsset = [AVURLAsset URLAssetWithURL:transCodeUrl options:options];
            if ([audioAsset tracksWithMediaType:AVMediaTypeAudio].count > 0) {
                CMTimeRange audioTimeRange;
                if (audioItem.duration > 0.0f) {
                    audioTimeRange = CMTimeRangeMake(CMTimeMake(audioInfo.audio_start_time * 1000, 1000), CMTimeMake(audioItem.duration * 1000, 1000));
                } else {
                    audioTimeRange = CMTimeRangeMake(CMTimeMake(audioInfo.audio_start_time * 1000, 1000), CMTimeMake(audioInfo.audio_duration * 1000, 1000));
                }
                CMTime audioStartTime = CMTimeAdd(audioTimeRange.start, CMTimeMake(audioItem.startTime * 1000, 1000));
                if (CMTimeCompare(audioStartTime, audioTimeRange.duration) >= 0) {
                    continue;
                }
                
                // 插入后视频剩余时长
                CMTime offsetTime = CMTimeMake((audioItem.offsetTime + audioItem.displayTime) * 1000, 1000);
                if (CMTimeCompare(offsetTime, nextClipStartTime) >= 0) {
                    continue;
                }
                CMTime durationTime = CMTimeSubtract(audioTimeRange.duration, audioStartTime);
                CMTime realDurationTime = CMTimeSubtract(nextClipStartTime, offsetTime);
                if (CMTimeCompare(durationTime, realDurationTime) > 0) {
                    durationTime = realDurationTime;
                }
                
                if (CMTimeCompare(durationTime, kCMTimeZero) > 0) {
                    AVMutableCompositionTrack * audioItemTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                    [audioItemTrack insertTimeRange:CMTimeRangeMake(audioStartTime, durationTime) ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject] atTime:offsetTime error:nil];
                    
                    AVMutableAudioMixInputParameters * mixInput = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioItemTrack];
                    mixInput.trackID = [audioItemTrack trackID];
                    [mixInput setVolume:audioItem.volume atTime:offsetTime];
                    [inputParameters addObject:mixInput];
                    
                    NSLog(@"path %@, audioItem.volume == %f", audioItem.audioPath, audioItem.volume);
                }
            }
        }
    }
    
    /* 添加转场 */
    NSMutableArray * instructions = [[NSMutableArray alloc] initWithCapacity:5];
    for (NSInteger index = 0; index < _clipItems.count; index++) {
        NSInteger alternatingIndex = index % 2;
        YMTinyVideoClipItem * clipItem = [_clipItems objectAtIndex:index];
        
        AVMutableVideoCompositionInstruction * videoInstruction = nil;
        if (videoComposition.customVideoCompositorClass == nil) {
            videoInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
            videoInstruction.timeRange = clipItem.passThroughTimeRange;
            if (!CGSizeEqualToSize(outputSize, CGSizeZero) && !CGRectEqualToRect(cropRect, CGRectZero)) {
                AVMutableVideoCompositionLayerInstruction * passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTracks[alternatingIndex]];
                CGSize naturalSize = compositionVideoTracks[alternatingIndex].naturalSize;
                CGSize targetSize = outputSize;
                CGSize cropSize = cropRect.size;
                CGPoint cropPoint = cropRect.origin;
                CGFloat videoAngleInDegree = [YMTinyVideoCompositionEditor videoTrackOrientationDegree:compositionVideoTracks[alternatingIndex]] + clipItem.rotateAngle;
                BOOL transformX = NO;
                BOOL transformY = NO;
                if (videoAngleInDegree == 90 || videoAngleInDegree == -270) {
                    CGFloat naturalWidth = naturalSize.width;
                    naturalSize.width = naturalSize.height;
                    naturalSize.height = naturalWidth;
                    
                    CGFloat cropWidth = cropSize.width;
                    cropSize.width = cropSize.height;
                    cropSize.height = cropWidth;
                    
                    CGFloat cropOriginX = cropPoint.x;
                    cropPoint.x = cropPoint.y;
                    cropPoint.y = cropOriginX;
                    
                    transformX = YES;
                } else if(videoAngleInDegree == 270 || videoAngleInDegree == -90) {
                    CGFloat naturalWidth = naturalSize.width;
                    naturalSize.width = naturalSize.height;
                    naturalSize.height = naturalWidth;
                    
                    CGFloat cropWidth = cropSize.width;
                    cropSize.width = cropSize.height;
                    cropSize.height = cropWidth;
                    
                    CGFloat cropOriginX = cropPoint.x;
                    cropPoint.x = cropPoint.y;
                    cropPoint.y = cropOriginX;
                    
                    transformY = YES;
                } else if(videoAngleInDegree == 180 || videoAngleInDegree == -180) {
                    transformX = YES;
                    transformY = YES;
                }
                
                CGAffineTransform finalTransform = CGAffineTransformIdentity;
                CGFloat naturalRatio = (CGFloat)cropSize.width / (CGFloat)cropSize.height;
                CGFloat targetRatio = (CGFloat)targetSize.width / (CGFloat)targetSize.height;
                
                CGFloat scale = naturalRatio < targetRatio ? (targetSize.width / cropSize.width) : (targetSize.height / cropSize.height);
                
                CGFloat offsetX = transformX ? ((naturalSize.width - cropPoint.x) * scale) : (cropPoint.x * scale);
                CGFloat offsetY = transformY ? ((naturalSize.height - cropPoint.y) * scale) : (cropPoint.y * scale);
                CGFloat translateX = transformX ? offsetX : -offsetX;
                CGFloat translateY = transformY ? offsetY : -offsetY;
                
                CGFloat theta = videoAngleInDegree * M_PI / 180;
                
                finalTransform.a = scale * cos(theta);
                finalTransform.b = scale * sin(theta);
                finalTransform.c = scale * -sin(theta);
                finalTransform.d = scale * cos(theta);
                finalTransform.tx = translateX;
                finalTransform.ty = translateY;
                
                [passThroughLayer setTransform:finalTransform atTime:kCMTimeZero];
                videoInstruction.layerInstructions = @[passThroughLayer];
                [compositionVideoTracks[alternatingIndex] setPreferredTransform:CGAffineTransformIdentity];
            }
        } else {
            videoInstruction = (AVMutableVideoCompositionInstruction *)[[YMTinyVideoCompositionInstruction alloc] initPassThroughTrackID:compositionVideoTracks[alternatingIndex].trackID forTimeRange:clipItem.passThroughTimeRange];
            ((YMTinyVideoCompositionInstruction *)videoInstruction).transitionType = clipItem.transitionType;
        }
        
        [instructions addObject:videoInstruction];
        
        // 最后一个视频不需要以转场结束
        if ((index + 1) < _clipItems.count) {
            if (compositionVideoTracks[alternatingIndex] != nil && compositionVideoTracks[1 - alternatingIndex] != nil) {
                YMTinyVideoCompositionInstruction * videoInstruction = [[YMTinyVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[alternatingIndex].trackID], [NSNumber numberWithInt:compositionVideoTracks[1 - alternatingIndex].trackID]] forTimeRange:clipItem.transitionTimeRange];
                videoInstruction.preTrackID = compositionVideoTracks[alternatingIndex].trackID;
                videoInstruction.nextTrackID = compositionVideoTracks[1 - alternatingIndex].trackID;
                videoInstruction.transitionType = clipItem.transitionType;
                
                [instructions addObject:videoInstruction];
            }
            
            if (clipItem.transitionAudioUrl != nil) {
                if (compositionAudioTracks[alternatingIndex] != nil) {
                    AVMutableAudioMixInputParameters * preMixInput = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionAudioTracks[alternatingIndex]];
                    [preMixInput setVolumeRampFromStartVolume:1.0f toEndVolume:1.0f timeRange:clipItem.passThroughTimeRange];
                    [preMixInput setVolumeRampFromStartVolume:0.0f toEndVolume:0.0f timeRange:clipItem.transitionTimeRange];
                    [inputParameters addObject:preMixInput];
                }
                
                YMTinyVideoClipItem * nextClipItem = [_clipItems objectAtIndex:index + 1];
                if (compositionAudioTracks[1 - alternatingIndex] != nil) {
                    AVMutableAudioMixInputParameters * nextMixInput = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionAudioTracks[1 - alternatingIndex]];
                    [nextMixInput setVolumeRampFromStartVolume:0.0f toEndVolume:0.0f timeRange:clipItem.transitionTimeRange];
                    [nextMixInput setVolume:1.0f atTime:nextClipItem.passThroughTimeRange.start];
                    [inputParameters addObject:nextMixInput];
                }
            }
        }
    }
    
    videoComposition.instructions = instructions;
    audioMix.inputParameters = inputParameters;
}

- (void)buildVTransitionComposition:(AVMutableComposition *)composition videoComposition:(AVMutableVideoComposition *)videoComposition {
    if (_clipItems.count == 0) {
        NSLog(@"_clipItems.count == 0");
        return;
    }
    
    CMTime nextClipStartTime = kCMTimeZero;
    AVMutableCompositionTrack * compositionVideoTracks[2];
    
    /* 拼接视频片段 */
    for (NSInteger index = 0; index < _clipItems.count; index++) {
        NSInteger alternatingIndex = index % 2;
        YMTinyVideoClipItem * clipItem = [_clipItems objectAtIndex:index];
        
        /* 添加视频片段 */
        CMTimeRange timeRangeInAsset = clipItem.clipTimeRange;
        if (CMTimeRangeEqual(timeRangeInAsset, kCMTimeRangeZero)) {
            NSLog(@"timeRange is zero");
            continue;
        }
        
        if ([clipItem.clip tracksWithMediaType:AVMediaTypeVideo].count > 0) {
            if (compositionVideoTracks[alternatingIndex] == nil) {
                compositionVideoTracks[alternatingIndex] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            }
            AVAssetTrack * clipVideoTrack = [[clipItem.clip tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
            [compositionVideoTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipVideoTrack atTime:nextClipStartTime error:nil];
            [compositionVideoTracks[alternatingIndex] setPreferredTransform:clipVideoTrack.preferredTransform];
        }
        
        clipItem.passThroughTimeRange = CMTimeRangeMake(nextClipStartTime, timeRangeInAsset.duration);
        // 第一个视频不需要以转场开始
        if (index != 0) {
            clipItem.passThroughTimeRange = CMTimeRangeMake(CMTimeAdd(clipItem.passThroughTimeRange.start, clipItem.preTransitionDurationTime), CMTimeSubtract(clipItem.passThroughTimeRange.duration, clipItem.preTransitionDurationTime)) ;
        }
        // 最后一个视频不需要以转场结束
        if ((index + 1) < _clipItems.count) {
            clipItem.passThroughTimeRange = CMTimeRangeMake(clipItem.passThroughTimeRange.start, CMTimeSubtract(clipItem.passThroughTimeRange.duration, clipItem.nextTransitionDurationTime)) ;
        }
        
        nextClipStartTime = CMTimeAdd(nextClipStartTime, timeRangeInAsset.duration);
        nextClipStartTime = CMTimeSubtract(nextClipStartTime, clipItem.nextTransitionDurationTime);
        if ((index + 1) < _clipItems.count) {
            clipItem.transitionTimeRange = CMTimeRangeMake(nextClipStartTime, clipItem.nextTransitionDurationTime);
        }
    }
    
    /* 添加转场 */
    NSMutableArray * instructions = [[NSMutableArray alloc] initWithCapacity:5];
    for (NSInteger index = 0; index < _clipItems.count; index++) {
        NSInteger alternatingIndex = index % 2;
        YMTinyVideoClipItem * clipItem = [_clipItems objectAtIndex:index];
        
        AVMutableVideoCompositionInstruction * videoInstruction = nil;
        videoInstruction = (AVMutableVideoCompositionInstruction *)[[YMTinyVideoCompositionInstruction alloc] initPassThroughTrackID:compositionVideoTracks[alternatingIndex].trackID forTimeRange:clipItem.passThroughTimeRange];
        ((YMTinyVideoCompositionInstruction *)videoInstruction).transitionType = clipItem.transitionType;
        
        [instructions addObject:videoInstruction];
        
        // 最后一个视频不需要以转场结束
        if ((index + 1) < _clipItems.count) {
            if (compositionVideoTracks[alternatingIndex] != nil && compositionVideoTracks[1 - alternatingIndex] != nil) {
                YMTinyVideoCompositionInstruction * videoInstruction = [[YMTinyVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[alternatingIndex].trackID], [NSNumber numberWithInt:compositionVideoTracks[1 - alternatingIndex].trackID]] forTimeRange:clipItem.transitionTimeRange];
                videoInstruction.preTrackID = compositionVideoTracks[alternatingIndex].trackID;
                videoInstruction.nextTrackID = compositionVideoTracks[1 - alternatingIndex].trackID;
                videoInstruction.transitionType = clipItem.transitionType;
                
                [instructions addObject:videoInstruction];
            }
        }
    }
    
    videoComposition.instructions = instructions;
}

- (void)buildATransitionComposition:(AVMutableComposition *)composition audioMix:(AVMutableAudioMix *)audioMix {
    if (_clipItems.count == 0) {
        NSLog(@"_clipItems.count == 0");
        return;
    }
    
    NSDictionary * options = @{AVURLAssetPreferPreciseDurationAndTimingKey:@YES};
    CMTime nextClipStartTime = kCMTimeZero;
    AVMutableCompositionTrack * compositionAudioTracks[2];
    AVMutableCompositionTrack * compositionTransitionAudioTrack;
    NSMutableArray * inputParameters = [[NSMutableArray alloc] initWithCapacity:5];
    
    NSLog(@"_volumeAudioItems.videoVolume == %f", _videoVolume);
    
    /* 拼接音频片段 */
    for (NSInteger index = 0; index < _clipItems.count; index++) {
        NSInteger alternatingIndex = index % 2;
        YMTinyVideoClipItem * clipItem = [_clipItems objectAtIndex:index];
        
        /* 添加音频片段 */
        CMTimeRange timeRangeInAsset = clipItem.clipTimeRange;
        if (CMTimeRangeEqual(timeRangeInAsset, kCMTimeRangeZero)) {
            NSLog(@"timeRange is zero");
            continue;
        }
        
        if ([[clipItem.clip tracksWithMediaType:AVMediaTypeAudio] count]) {
            if (compositionAudioTracks[alternatingIndex] == nil) {
                compositionAudioTracks[alternatingIndex] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            }
            AVAssetTrack * clipAudioTrack = [[clipItem.clip tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            [compositionAudioTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:nextClipStartTime error:nil];
            
            AVMutableAudioMixInputParameters * mixInput = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionAudioTracks[alternatingIndex]];
            mixInput.trackID = [compositionAudioTracks[alternatingIndex] trackID];
            [mixInput setVolume:_videoVolume atTime:nextClipStartTime];
            [inputParameters addObject:mixInput];
        }
        
        clipItem.passThroughTimeRange = CMTimeRangeMake(nextClipStartTime, timeRangeInAsset.duration);
        // 第一个视频不需要以转场开始
        if (index != 0) {
            clipItem.passThroughTimeRange = CMTimeRangeMake(CMTimeAdd(clipItem.passThroughTimeRange.start, clipItem.preTransitionDurationTime), CMTimeSubtract(clipItem.passThroughTimeRange.duration, clipItem.preTransitionDurationTime)) ;
        }
        // 最后一个视频不需要以转场结束
        if ((index + 1) < _clipItems.count) {
            clipItem.passThroughTimeRange = CMTimeRangeMake(clipItem.passThroughTimeRange.start, CMTimeSubtract(clipItem.passThroughTimeRange.duration, clipItem.nextTransitionDurationTime)) ;
        }
        
        nextClipStartTime = CMTimeAdd(nextClipStartTime, timeRangeInAsset.duration);
        nextClipStartTime = CMTimeSubtract(nextClipStartTime, clipItem.nextTransitionDurationTime);
        
        if ((index + 1) < _clipItems.count) {
            clipItem.transitionTimeRange = CMTimeRangeMake(nextClipStartTime, clipItem.nextTransitionDurationTime);
            
            if (clipItem.transitionAudioUrl != nil) {
                NSString * transCodePath = clipItem.transitionAudioUrl.path;
                NSLog(@"transitionAudio transCodePath %@", transCodePath);

                if (transCodePath != nil) {
                    NSURL * transCodeUrl = [VideoFileKit pathToFileUrl:transCodePath];
                    if (transCodeUrl) {
                        AVURLAsset * audioAsset = [AVURLAsset URLAssetWithURL:transCodeUrl options:options];
                        if ([audioAsset tracksWithMediaType:AVMediaTypeAudio].count > 0) {
                            if (compositionTransitionAudioTrack == nil) {
                                compositionTransitionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                            }
                            [compositionTransitionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, clipItem.nextTransitionDurationTime) ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject] atTime:nextClipStartTime error:nil];
                        }
                    }
                }
            }
        }
    }
    
    if (_audioItems.count != 0) {
        NSUInteger index = 0;
        for (AudioItem * audioItem in _audioItems) {
            index++;
            NSLog(@"auidoItem transCodePath %@, audioItem.volume == %f", audioItem.audioPath, audioItem.volume);

            NSString * transCodePath = audioItem.audioPath;
            YCloudVideoInfo * audioInfo = [[YCloudVideoInfo alloc] initWithPath:transCodePath];
            
            NSURL * transCodeUrl = [VideoFileKit pathToFileUrl:transCodePath];
            if (transCodeUrl == nil) {
                continue;
            }
            
            AVURLAsset * audioAsset = [AVURLAsset URLAssetWithURL:transCodeUrl options:options];
            if ([audioAsset tracksWithMediaType:AVMediaTypeAudio].count > 0) {
                CMTimeRange audioTimeRange = CMTimeRangeMake(CMTimeMake(audioInfo.audio_start_time * 1000, 1000), CMTimeMake(audioInfo.audio_duration * 1000, 1000));
                CMTime audioStartTime = CMTimeAdd(audioTimeRange.start, CMTimeMake(audioItem.startTime * 1000, 1000));
                if (CMTimeCompare(audioStartTime, audioTimeRange.duration) >= 0) {
                    NSLog(@"auidoItem audioStartTime %f, audioTimeRange.duration %f", CMTimeGetSeconds(audioStartTime), CMTimeGetSeconds(audioTimeRange.duration));
                    continue;
                }
                
                // 插入后视频剩余时长
                CMTime offsetTime = CMTimeMake((audioItem.offsetTime + audioItem.displayTime) * 1000, 1000);
                if (CMTimeCompare(offsetTime, nextClipStartTime) >= 0) {
                    NSLog(@"auidoItem offsetTime %f, nextClipStartTime %f", CMTimeGetSeconds(offsetTime), CMTimeGetSeconds(nextClipStartTime));
                    continue;
                }
                CMTime durationTime = CMTimeSubtract(audioTimeRange.duration, audioStartTime);
                CMTime realDurationTime = CMTimeSubtract(nextClipStartTime, offsetTime);
                if (CMTimeCompare(durationTime, realDurationTime) > 0) {
                    durationTime = realDurationTime;
                }
                
                if (CMTimeCompare(durationTime, kCMTimeZero) > 0) {
                    AVMutableCompositionTrack * audioItemTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                    [audioItemTrack insertTimeRange:CMTimeRangeMake(audioStartTime, durationTime) ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject] atTime:offsetTime error:nil];
                    
                    AVMutableAudioMixInputParameters * mixInput = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioItemTrack];
                    mixInput.trackID = [audioItemTrack trackID];
                    [mixInput setVolume:audioItem.volume atTime:offsetTime];
                    [inputParameters addObject:mixInput];
                    
                    NSLog(@"path %@, audioItem.volume == %f", audioItem.audioPath, audioItem.volume);
                }
            }
        }
    }
    
    /* 添加转场 */
    for (NSInteger index = 0; index < _clipItems.count; index++) {
        NSInteger alternatingIndex = index % 2;
        YMTinyVideoClipItem * clipItem = [_clipItems objectAtIndex:index];
        
        // 最后一个视频不需要以转场结束
        if ((index + 1) < _clipItems.count) {
            if (clipItem.transitionAudioUrl != nil) {
                if (compositionAudioTracks[alternatingIndex] != nil) {
                    AVMutableAudioMixInputParameters * preMixInput = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionAudioTracks[alternatingIndex]];
                    [preMixInput setVolumeRampFromStartVolume:1.0f toEndVolume:1.0f timeRange:clipItem.passThroughTimeRange];
                    [preMixInput setVolumeRampFromStartVolume:0.0f toEndVolume:0.0f timeRange:clipItem.transitionTimeRange];
                    [inputParameters addObject:preMixInput];
                }
                
                YMTinyVideoClipItem * nextClipItem = [_clipItems objectAtIndex:index + 1];
                if (compositionAudioTracks[1 - alternatingIndex] != nil) {
                    AVMutableAudioMixInputParameters * nextMixInput = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionAudioTracks[1 - alternatingIndex]];
                    [nextMixInput setVolumeRampFromStartVolume:0.0f toEndVolume:0.0f timeRange:clipItem.transitionTimeRange];
                    [nextMixInput setVolume:1.0f atTime:nextClipItem.passThroughTimeRange.start];
                    [inputParameters addObject:nextMixInput];
                }
            }
        }
    }
    
    audioMix.inputParameters = inputParameters;
}

- (void)buildMultiVideoAComposition:(AVMutableComposition *)composition audioMix:(AVMutableAudioMix *)audioMix {
    if (_clipItems.count == 0) {
        NSLog(@"_clipItems.count == 0");
        return;
    }
    
    AVMutableCompositionTrack * compositionAudioTracks[_clipItems.count];
    NSMutableArray * inputParameters = [[NSMutableArray alloc] initWithCapacity:5];
    
    /* 拼接音频片段 */
    for (NSInteger index = 0; index < _clipItems.count; index++) {
        YMTinyVideoClipItem * clipItem = [_clipItems objectAtIndex:index];
        
        compositionAudioTracks[index] = nil;
        
        /* 添加音频片段 */
        CMTimeRange timeRangeInAsset = clipItem.clipTimeRange;
        if (CMTimeRangeEqual(timeRangeInAsset, kCMTimeRangeZero)) {
            NSLog(@"timeRange is zero");
            continue;
        }
        
        if (clipItem.videoVolume == 0.0f) {
            NSLog(@"clipItem.videoVolume zero");
            continue;
        }
        
        NSLog(@"clipItem.videoVolume == %f", clipItem.videoVolume);
        
        CMTime startTime = CMTimeMake(clipItem.volumeStartTime * 1000000, 1000000);
        if ([[clipItem.clip tracksWithMediaType:AVMediaTypeAudio] count]) {
            AVAssetTrack * clipAudioTrack = [[clipItem.clip tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            compositionAudioTracks[index] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [compositionAudioTracks[index] insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:startTime error:nil];
            
            AVMutableAudioMixInputParameters * mixInput = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionAudioTracks[index]];
            mixInput.trackID = [compositionAudioTracks[index] trackID];
            [mixInput setVolume:clipItem.videoVolume atTime:startTime];
            [inputParameters addObject:mixInput];
        }
    }
    
    audioMix.inputParameters = inputParameters;
}

#pragma mark - orientation

+ (CGFloat)videoTrackOrientationDegree:(AVAssetTrack *)videoTrack {
    if (videoTrack == nil) {
        return 0;
    }
    
    CGAffineTransform txf = [videoTrack preferredTransform];
    CGFloat videoAngleInDegree = atan2(txf.b, txf.a) * 180.0f / M_PI;
    
    return videoAngleInDegree;
}

+ (CGFloat)videoTrackOrientationRadian:(AVAssetTrack *)videoTrack {
    if (videoTrack == nil) {
        return 0;
    }
    
    CGAffineTransform txf = [videoTrack preferredTransform];
    return atan2(txf.b, txf.a);
}

+ (CGFloat)videoOrientationDegree:(AVAsset *)asset {
    NSArray * videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if ([videoTracks count] == 0) {
        return 0.0f;
    }
    
    AVAssetTrack * videoTrack = [videoTracks objectAtIndex:0];
    return [YMTinyVideoCompositionEditor videoTrackOrientationDegree:videoTrack];
}

+ (CGFloat)videoOrientationRadian:(AVAsset *)asset {
    CGFloat videoAngleInDegree = [YMTinyVideoCompositionEditor videoOrientationDegree:asset];
    CGFloat videoAngleInRadian = M_PI * videoAngleInDegree / 180.0;
    
    return videoAngleInRadian;
}

- (YMROrientation)videoOrientation {
    if (_videoOrientation == YMR_ORIENTATION_NOTFOUND) {
        _videoOrientation = [YMTinyVideoCompositionEditor videoOrientation:self.composition];
    }
    return _videoOrientation;
}

+ (YMROrientation)videoOrientation:(AVAsset *)asset {
    CGFloat videoAngleInDegree = [YMTinyVideoCompositionEditor videoOrientationDegree:asset];
    
    YMROrientation orientation = YMR_ORIENTATION_UP;
    switch ((int)videoAngleInDegree) {
        case 0:
            orientation = YMR_ORIENTATION_RIGHT;
            break;
        case 90:
            orientation = YMR_ORIENTATION_UP;
            break;
        case 180:
            orientation = YMR_ORIENTATION_LEFT;
            break;
        case -90:
            orientation	= YMR_ORIENTATION_DOWN;
            break;
        default:
            orientation = YMR_ORIENTATION_NOTFOUND;
            break;
    }
    
    return orientation;
}

@end
