//
//  AVAssetDecodeEncode.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "AVAssetDecodeEncode.h"
#import "YMTinyVideoCompositionEditor.h"

#define YM_TINYVIDEO_NORMAL_FPS 30
#define YM_TINYVIDEO_PLAYER_FPS 60

@interface AVAssetDecodeEncode()
@property (nonatomic, assign, readwrite) float progress;
@property (nonatomic, strong) AVAssetReader * reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput * videoOutput;
@property (nonatomic, strong) AVAssetReaderVideoCompositionOutput * videoCompositionOutput;
@property (nonatomic, strong) AVAssetReaderAudioMixOutput * audioOutput;
@property (nonatomic, strong) AVAssetWriter * writer;
@property (nonatomic, strong) AVAssetWriterInput * videoInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor * videoPixelBufferAdaptor;
@property (nonatomic, strong) AVAssetWriterInput * audioInput;
@property (nonatomic, strong) dispatch_queue_t inputQueue;
@property (nonatomic, copy) void (^completionHandler)(void);
@property (nonatomic, strong) NSArray<AudioItem *> *audioItems;
@end

@implementation AVAssetDecodeEncode{
    NSError *_error;
    NSTimeInterval _duration;
    CMTime _lastSamplePresentationTime;
    
    CMTime _firstValidTime;
    CMTime _offsetTime;
    NSInteger _frameCount;
    NSInteger _frameInterval;
    
    NSArray<VideoItem *> *_videoItems;
}

- (instancetype)initWithVideoItems:(NSArray<VideoItem *> *)videoItems audioItems:(NSArray<AudioItem *> *)audioItems {
    self = [super init];
    if (self != nil) {
        _videoItems = videoItems;
        NSURL *assetUrl = [VideoFileKit pathToFileUrl:_videoItems.firstObject.videoPath];
        _originAsset = [AVAsset assetWithURL:assetUrl];
        _audioItems = audioItems;
        _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
        _offsetTime = kCMTimeInvalid;
        _firstValidTime = kCMTimeInvalid;
        _lastSamplePresentationTime = kCMTimeZero;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelExport) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)exportCropAsynchronouslyWithCompletionHandler:(void (^)(void))handler avasset:(AVAsset *)videoAVAsset{
    NSLog(@"called");
    NSParameterAssert(handler != nil);
    //[self cancelExport];
    self.completionHandler = handler;
    
    if (!self.outputURL) {
        _error = [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorExportFailed userInfo:@
                  {
                  NSLocalizedDescriptionKey: @"Output URL not set"
                  }];
        handler();
        NSLog(@"Output URL not set");
        return;
    }
    
    _videoItems.firstObject.rotateAngle = self.rotateAngle;
    
    YMTinyVideoCompositionEditor * compositionEditor = [[YMTinyVideoCompositionEditor alloc] initWithVideoItems:_videoItems audioItems:_audioItems];
    [compositionEditor buildCropAVComposition:_outputSize cropRect:_cropRect fps:[self getActualFrameRate]];
    self.videoComposition = compositionEditor.videoComposition;
    self.audioMix = compositionEditor.audioMix;
    
    
    [self doExport:compositionEditor.composition useGL:NO handler:handler];
}

- (void)doExport:(AVAsset *)asset useGL:(BOOL)useGL handler:(void (^)(void))handler {
    NSError * readerError = nil;
    self.reader = [AVAssetReader.alloc initWithAsset:asset error:&readerError];
    if (readerError) {
        _error = readerError;
        handler();
        NSLog(@"reader init failed");
        return;
    }
    
    NSError * writerError = nil;
    self.writer = [AVAssetWriter assetWriterWithURL:self.outputURL fileType:self.outputFileType error:&writerError];
    if (writerError) {
        _error = writerError;
        handler();
        NSLog(@"writer init failed");
        return;
    }
    
    self.reader.timeRange = self.timeRange;
    self.writer.shouldOptimizeForNetworkUse = self.shouldOptimizeForNetworkUse;
    self.writer.metadata = self.metadata;
    
    NSArray * videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    NSMutableArray<AVAssetTrack *> * validVideoTracks = [[NSMutableArray alloc] initWithCapacity:1];
    for (AVAssetTrack * track in videoTracks) {
        if (CMTimeCompare(track.timeRange.start, kCMTimeInvalid) != 0 && CMTimeCompare(track.timeRange.duration, kCMTimeInvalid) != 0) {
            NSLog(@"called");
            [validVideoTracks addObject:track];
        }
    }
    
    CGSize renderSize;
    if (validVideoTracks.count) {
        renderSize = (validVideoTracks.firstObject).naturalSize;
    } else {
        _error = [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorExportFailed userInfo:@
                  {
                  NSLocalizedDescriptionKey: @"valid video count is zero"
                  }];
        handler();
        NSLog(@"valid video count is zero");
        return;
    }
    
    NSLog(@"called");
    
    if (CMTIME_IS_VALID(self.timeRange.duration) && !CMTIME_IS_POSITIVE_INFINITY(self.timeRange.duration)) {
        _duration = CMTimeGetSeconds(self.timeRange.duration);
    } else {
        _duration = CMTimeGetSeconds(asset.duration);
    }
    
    //
    // Video output
    //
    if (validVideoTracks.count > 0) {
        self.videoInputSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),};
        if (_videoComposition == nil) {
            self.videoOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:validVideoTracks.firstObject outputSettings:self.videoInputSettings];
            self.videoOutput.alwaysCopiesSampleData = NO;
            if ([self.reader canAddOutput:self.videoOutput]) {
                [self.reader addOutput:self.videoOutput];
            }
        } else {
            self.videoCompositionOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:validVideoTracks videoSettings:self.videoInputSettings];
            self.videoCompositionOutput.videoComposition = _videoComposition;
            self.videoCompositionOutput.alwaysCopiesSampleData = NO;
            if ([self.reader canAddOutput:self.videoCompositionOutput]) {
                [self.reader addOutput:self.videoCompositionOutput];
            }
        }
        
        //
        // Video input
        //
        AVAssetTrack * videoTrack = validVideoTracks.firstObject;
        self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:self.videoSettings];
        self.videoInput.expectsMediaDataInRealTime = NO;
        self.videoInput.transform = videoTrack.preferredTransform;
        if ([self.writer canAddInput:self.videoInput]) {
            [self.writer addInput:self.videoInput];
        }
        
        NSDictionary * pixelBufferAttributes = @ {
            (id)kCVPixelBufferPixelFormatTypeKey: (useGL ? @(kCVPixelFormatType_32BGRA) : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)),
            (id)kCVPixelBufferWidthKey: @(renderSize.width),
            (id)kCVPixelBufferHeightKey: @(renderSize.height),
            @"IOSurfaceOpenGLESTextureCompatibility": @YES,
            @"IOSurfaceOpenGLESFBOCompatibility": @YES,
        };
        self.videoPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoInput sourcePixelBufferAttributes:pixelBufferAttributes];
    }
    
    //
    //Audio output
    //
    NSArray * audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    NSMutableArray<AVAssetTrack *> * validAudioTracks = [[NSMutableArray alloc] initWithCapacity:1];
    for (AVAssetTrack * track in audioTracks) {
        if (CMTimeCompare(track.timeRange.start, kCMTimeInvalid) != 0 && CMTimeCompare(track.timeRange.duration, kCMTimeInvalid) != 0) {
            [validAudioTracks addObject:track];
        }
    }
    
    if (validAudioTracks.count > 0) {
        self.audioOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:validAudioTracks audioSettings:nil];
        self.audioOutput.alwaysCopiesSampleData = NO;
        self.audioOutput.audioMix = self.audioMix;
        if ([self.reader canAddOutput:self.audioOutput]) {
            [self.reader addOutput:self.audioOutput];
        }
    } else {
        // Just in case this gets reused
        self.audioOutput = nil;
    }
    //
    // Audio input
    //
    if (self.audioOutput) {
        self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:self.audioSettings];
        self.audioInput.expectsMediaDataInRealTime = NO;
        if ([self.writer canAddInput:self.audioInput]) {
            [self.writer addInput:self.audioInput];
        }
    }
    
    BOOL isStartWriting =  [self.writer startWriting];
    BOOL isStartReading =  [self.reader startReading];
    
    if (!isStartReading || !isStartWriting) {
        NSLog(@"reader isStartReadering: %d, error:%@ writer isStartWriting: %d,error %@",isStartReading, self.reader.error,isStartReading, self.writer.error);
    }
    
    CGFloat startTime = self.timeRange.start.value * 1.0 / self.timeRange.start.timescale;
    if (validVideoTracks.count > 0) {
        [self.writer startSessionAtSourceTime:CMTimeMakeWithSeconds(startTime, (validVideoTracks.firstObject).naturalTimeScale)];
    } else {
        [self.writer startSessionAtSourceTime:CMTimeMakeWithSeconds(startTime, (validAudioTracks.firstObject).naturalTimeScale)];
    }
    
    __block BOOL videoCompleted = NO;
    __block BOOL audioCompleted = NO;
    __weak typeof(self) wself = self;
    
    self.inputQueue = dispatch_queue_create("VideoEncoderInputQueue", DISPATCH_QUEUE_SERIAL);
    if (validVideoTracks.count > 0) {
        [self.videoInput requestMediaDataWhenReadyOnQueue:self.inputQueue usingBlock:^{
            @autoreleasepool {
                AVAssetReaderOutput * videoOutput = (_videoComposition == nil ? wself.videoOutput : wself.videoCompositionOutput);
                if (![wself encodeReadySamplesFromOutput:videoOutput useGL:useGL toInput:wself.videoInput]) {
                    @synchronized(wself) {
                        videoCompleted = YES;
                        if (audioCompleted) {
                            [wself finish:handler];
                        }
                    }
                }
            }
        }];
    } else {
        videoCompleted = YES;
    }
    
    if (!self.audioOutput) {
        audioCompleted = YES;
    } else {
        [self.audioInput requestMediaDataWhenReadyOnQueue:self.inputQueue usingBlock:^{
            @autoreleasepool {
                if (![wself encodeReadySamplesFromOutput:wself.audioOutput useGL:NO toInput:wself.audioInput]) {
                    @synchronized(wself) {
                        audioCompleted = YES;
                        if (videoCompleted) {
                            [wself finish:handler];
                        }
                    }
                }
            }
        }];
    }
}

- (BOOL)encodeReadySamplesFromOutput:(AVAssetReaderOutput *)output useGL:(BOOL)useGL toInput:(AVAssetWriterInput *)input {
    while (input.isReadyForMoreMediaData) {
        CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
        if (sampleBuffer) {
            BOOL error = NO;
            
            if (self.reader.status != AVAssetReaderStatusReading || self.writer.status != AVAssetWriterStatusWriting) {
                NSLog(@"reader status : %zi , writer status: %zi",(long)self.reader.status,self.writer.status);
                error = YES;
            }
            
            if (!error) {
                if (self.videoOutput == output || self.videoCompositionOutput == output) {
                    BOOL canAppendBuffer = YES;
                    CMTime nowTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                    if (CMTIME_IS_INVALID(_firstValidTime)) {
                        _offsetTime = CMTimeSubtract(nowTime, self.timeRange.start);
                        _frameInterval = nowTime.timescale / [self getActualFrameRate];
                        
                        _firstValidTime = nowTime;
                        _frameCount++;
                        
                    } else {
                        if (_lastSamplePresentationTime.timescale != nowTime.timescale) {
                            _frameInterval = nowTime.timescale / [self getActualFrameRate];
                        }
                        
                        CMTime subtract = CMTimeSubtract(nowTime, _firstValidTime);
                        if (subtract.value / _frameInterval < _frameCount) {
                            canAppendBuffer = NO;
                        } else {
                            _frameCount++;
                        }
                    }
                    
                    _lastSamplePresentationTime = nowTime;
                    self.progress = _duration == 0 ? 1 : CMTimeGetSeconds(_lastSamplePresentationTime) / (CMTimeGetSeconds(self.reader.timeRange.start)+ CMTimeGetSeconds(self.reader.timeRange.duration));
                    if (canAppendBuffer) {
                        CMTime actualTime = CMTimeSubtract(_lastSamplePresentationTime, _offsetTime);
                        CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
                        
                        /*
                        if (useGL) {
                            CVPixelBufferRef glPixelBuffer = [_gpuProcess processPixelBuffer:pixelBuffer pts:CMTimeGetSeconds(actualTime)];
                            if (glPixelBuffer != nil) {
                                pixelBuffer = [YMTinyVideoAVAssetKit copyPixelBuffer:glPixelBuffer];
                            }
                        }*/
                        
                        if (![self.videoPixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:actualTime]) {
                            NSLog(@"writer video samplerbuffer error");
                            error = YES;
                        }
                        if (useGL) {
                            if (pixelBuffer != nil) {
                                CVPixelBufferRelease(pixelBuffer);
                            }
                        }
                    }
                } else {
                    if (![input appendSampleBuffer:sampleBuffer]) {
                        NSLog(@"writer audio samplerbuffer error");
                        error = YES;
                    }
                }
            }
            CFRelease(sampleBuffer);
            
            if (error) {
                return NO;
            }
        } else {
            [input markAsFinished];
            return NO;
        }
    }
    
    return YES;
}

- (CGFloat)getActualFrameRate {
    CGFloat trackFrameRate = 0.0f;
    if (self.videoSettings) {
        NSDictionary * videoCompressionProperties = self.videoSettings[AVVideoCompressionPropertiesKey];
        if (videoCompressionProperties){
            trackFrameRate = [videoCompressionProperties[AVVideoExpectedSourceFrameRateKey] floatValue];
        }
    }
    
    if (trackFrameRate == 0.0f) {
        NSLog(@"trackFrameRate still zero, make it 30");
        trackFrameRate = YM_TINYVIDEO_PLAYER_FPS;
    }
    
    if (trackFrameRate > YM_TINYVIDEO_PLAYER_FPS) {
        NSLog(@"trackFrameRate is bigger than 30, it was %f", trackFrameRate);
        trackFrameRate = YM_TINYVIDEO_PLAYER_FPS;
    }
    
    NSLog(@"trackFrameRate %f", trackFrameRate);
    
    return trackFrameRate;
}

- (void)finish:(void (^)(void))handler {
    // Synchronized block to ensure we never cancel the writer before calling finishWritingWithCompletionHandler
    if (self.reader.status == AVAssetReaderStatusCancelled || self.writer.status == AVAssetWriterStatusCancelled) {
        NSLog(@"do finish cancel");
        return;
    }
    
    if (CMTimeCompare(_lastSamplePresentationTime, kCMTimeZero) == 0) {
        _error = [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorExportFailed userInfo:@
                  {
                  NSLocalizedDescriptionKey: @"export error"
                  }];
        NSLog(@"export error");
        handler();
        return;
    }
    
    if (self.writer.status == AVAssetWriterStatusFailed) {
        [self complete];
    } else {
        NSLog(@"finish writing");
        CMTime endTime = CMTimeAdd(_lastSamplePresentationTime, CMTimeMake(_frameInterval, [self getActualFrameRate]));
        [self.writer endSessionAtSourceTime:endTime];
        [self.writer finishWritingWithCompletionHandler:^{
            [self complete];
        }];
    }
}

- (void)complete {
    if (self.writer.status == AVAssetWriterStatusFailed || self.writer.status == AVAssetWriterStatusCancelled) {
        [NSFileManager.defaultManager removeItemAtURL:self.outputURL error:nil];
        NSLog(@"complete writer status %ld", (long)self.writer.status);
    }
    
    if (self.writer.status == AVAssetWriterStatusCompleted) {
        if (self.progress < 1.0f) {
            self.progress = 1.0f;
        }
    }
    
    if (self.completionHandler) {
        self.completionHandler();
        self.completionHandler = nil;
    }
}

- (NSError *)error {
    if (_error) {
        return _error;
    } else {
        return self.writer.error ? : self.reader.error;
    }
}

- (AVAssetExportSessionStatus)status {
    switch (self.writer.status) {
        default:
        case AVAssetWriterStatusUnknown:
            return AVAssetExportSessionStatusUnknown;
        case AVAssetWriterStatusWriting:
            return AVAssetExportSessionStatusExporting;
        case AVAssetWriterStatusFailed:
            return AVAssetExportSessionStatusFailed;
        case AVAssetWriterStatusCompleted:
            return AVAssetExportSessionStatusCompleted;
        case AVAssetWriterStatusCancelled:
            return AVAssetExportSessionStatusCancelled;
    }
}

- (void)cancelExport {
    [self.writer cancelWriting];
    [self.reader cancelReading];
    [self complete];
    [self reset];
}

- (void)reset {
    _error = nil;
    self.progress = 0;
    self.reader = nil;
    self.videoOutput = nil;
    self.videoCompositionOutput = nil;
    self.audioOutput = nil;
    self.writer = nil;
    self.videoInput = nil;
    self.videoPixelBufferAdaptor = nil;
    self.audioInput = nil;
    self.inputQueue = nil;
    self.completionHandler = nil;
    _firstValidTime = kCMTimeInvalid;
    _offsetTime = kCMTimeInvalid;
    _frameInterval = 0;
    _frameCount = 0;
}
@end
