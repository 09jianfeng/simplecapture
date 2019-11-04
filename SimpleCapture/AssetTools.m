//
//  AssetTools.m
//  SimpleCapture
//
//  Created by JFChen on 2019/5/30.
//  Copyright © 2019 duowan. All rights reserved.
//

#import "AssetTools.h"
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@implementation AssetTools

#pragma mark - 音频与视频的合并
+ (void)mixVideoAndAudioWithVieoPath:(NSURL *)videoPath
                           audioPath:(NSURL *)audioPath
                      needVideoVoice:(BOOL)needVideoVoice
                         videoVolume:(CGFloat)videoVolume
                         audioVolume:(CGFloat)audioVolume
                      outPutFileName:(NSString *)fileName
                     complitionBlock:(CompletionBlock)completionBlock
{
    if (videoPath == nil) {
        return;
    }
    if (audioPath == nil) {
        return;
    }
    if (videoVolume > 1.0) {
        videoVolume = 1.0f;
    }
    if (videoVolume < 0.0) {
        videoVolume = 0.0f;
    }
    if (audioVolume > 1.0) {
        audioVolume = 1.0f;
    }
    if (audioVolume < 0.0) {
        audioVolume = 0.0f;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        AVAsset *asset      = [AVAsset assetWithURL:videoPath];
        AVAsset *audioAsset = [AVAsset assetWithURL:audioPath];
        
        CMTime duration = asset.duration;
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero, duration);
        
        AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        AVAssetTrack *audioAssetTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
        
        AVMutableComposition *composition = [[AVMutableComposition alloc]init];
        
        /** 视频素材加入视频轨道 */
        AVMutableCompositionTrack *videoCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [videoCompositionTrack insertTimeRange:video_timeRange ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];
        
        /** 音频素材加入音频轨道 */
        AVMutableCompositionTrack *audioCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [audioCompositionTrack insertTimeRange:video_timeRange ofTrack:audioAssetTrack atTime:kCMTimeZero error:nil];
        
        /** 是否加入视频原声 */
        AVMutableCompositionTrack *originalAudioCompositionTrack = nil;
        if (needVideoVoice) {
            AVAssetTrack *originalAudioAssetTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            originalAudioCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [originalAudioCompositionTrack insertTimeRange:video_timeRange ofTrack:originalAudioAssetTrack atTime:kCMTimeZero error:nil];
        }
        
        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetMediumQuality];
        
        /** 设置输出路径 */
        NSURL *outputPath = [self exporterPathWithFileName:fileName];
        exporter.outputURL = outputPath;
        exporter.outputFileType = AVFileTypeQuickTimeMovie;
        exporter.shouldOptimizeForNetworkUse = YES;
        
        /** 音量控制 */
        exporter.audioMix = [self buildAudioMixWithVideoTrack:originalAudioCompositionTrack
                                                  VideoVolume:videoVolume
                                                   audioTrack:audioCompositionTrack
                                                  audioVolume:audioVolume
                                                       atTime:kCMTimeZero];
        
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                switch ([exporter status]) {
                        
                    case AVAssetExportSessionStatusFailed: {
                        NSLog(@"合成失败：%@",[[exporter error] description]);
                        completionBlock(NO,outputPath);
                    }
                        break;
                        
                    case AVAssetExportSessionStatusCancelled: {
                        completionBlock(NO,outputPath);
                    }
                        break;
                        
                    case AVAssetExportSessionStatusCompleted: {
                        completionBlock(YES,outputPath);
                    }
                        break;
                        
                    default: {
                        completionBlock(NO,outputPath);
                    }
                        break;
                }
            });
            
            
        }];
        
    });
    
    
}

#pragma mark - 调节合成的音量
+ (AVAudioMix *)buildAudioMixWithVideoTrack:(AVCompositionTrack *)videoTrack
                                VideoVolume:(float)videoVolume
                                 audioTrack:(AVCompositionTrack *)audioTrack
                                audioVolume:(float)audioVolume
                                     atTime:(CMTime)volumeRange
{
    
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    
    AVMutableAudioMixInputParameters *videoParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:videoTrack];
    [videoParameters setVolume:videoVolume atTime:volumeRange];
    
    AVMutableAudioMixInputParameters *audioParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrack];
    [audioParameters setVolume:audioVolume atTime:volumeRange];
    
    audioMix.inputParameters = @[videoParameters,audioParameters];
    
    return audioMix;
}

#pragma mark - 视频输出路径
+ (NSURL *)exporterPathWithFileName:(NSString *)outPutfileName
{
    NSString *fileName = [NSString stringWithFormat:@"%@.mp4",outPutfileName];
    
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *directoryName = @"editVideo";
    
    BOOL createDir = [self createDirWihtName:directoryName];
    
    if (createDir) {
        NSString *directory = [cachePath stringByAppendingPathComponent:directoryName];
        NSString *outputFilePath = [directory stringByAppendingPathComponent:fileName];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:outputFilePath]) {
            
            [[NSFileManager defaultManager] removeItemAtPath:outputFilePath error:nil];
        }
        
        return [NSURL fileURLWithPath:outputFilePath];
    }
    
    return nil;
}

/** 创建文件夹 */
+ (BOOL)createDirWihtName:(NSString *)name
{
    if (!name) {
        return NO;
    }
    
    NSString      *cachePath    = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    NSString      *directory    = [cachePath stringByAppendingPathComponent:name];
    // 创建目录
    BOOL res = [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return res;
}


#pragma mark - 音频与音频的合并
+ (void)mixOriginalAudio:(NSURL *)originalAudioPath
     originalAudioVolume:(float)originalAudioVolume
             bgAudioPath:(NSURL *)bgAudioPath
           bgAudioVolume:(float)bgAudioVolume
          outPutFileName:(NSString *)fileName
         completionBlock:(CompletionBlock)completionBlock
{
    if (originalAudioPath == nil) {
        return;
    }
    if (bgAudioPath == nil) {
        return;
    }
    if (originalAudioVolume > 1.0) {
        originalAudioVolume = 1.0f;
    }
    if (originalAudioVolume < 0) {
        originalAudioVolume = 0.0f;
    }
    if (bgAudioVolume > 1.0) {
        bgAudioVolume = 1.0f;
    }
    if (bgAudioVolume < 0) {
        bgAudioVolume = 0.0f;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        AVURLAsset *originalAudioAsset = [AVURLAsset assetWithURL:originalAudioPath];
        AVURLAsset *bgAudioAsset       = [AVURLAsset assetWithURL:bgAudioPath];
        
        AVMutableComposition *compostion   = [AVMutableComposition composition];
        
        AVMutableCompositionTrack *originalAudio = [compostion addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:0];
        [originalAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, originalAudioAsset.duration) ofTrack:[originalAudioAsset tracksWithMediaType:AVMediaTypeAudio].firstObject atTime:kCMTimeZero error:nil];
        
        AVMutableCompositionTrack *bgAudio = [compostion addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:0];
        [bgAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, bgAudioAsset.duration) ofTrack:[bgAudioAsset tracksWithMediaType:AVMediaTypeAudio].firstObject atTime:kCMTimeZero error:nil];
        
        /** 得到对应轨道中的音频声音信息，并更改 */
        AVMutableAudioMixInputParameters *originalAudioParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:originalAudio];
        [originalAudioParameters setVolume:originalAudioVolume atTime:kCMTimeZero];
        
        AVMutableAudioMixInputParameters *bgAudioParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:bgAudio];
        [originalAudioParameters setVolume:bgAudioVolume atTime:kCMTimeZero];
        
        /** 赋给对应的类 */
        AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
        audioMix.inputParameters = @[originalAudioParameters,bgAudioParameters];
        
        AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:compostion presetName:AVAssetExportPresetAppleM4A];
        
        /** 设置输出路径 */
        NSURL *outputPath = [self exporterAudioPathWithFileName:fileName];
        
        session.audioMix       = audioMix;
        session.outputURL      = outputPath;
        session.outputFileType = AVFileTypeAppleM4A;
        session.shouldOptimizeForNetworkUse = YES;
        
        [session exportAsynchronouslyWithCompletionHandler:^{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                switch ([session status]) {
                        
                    case AVAssetExportSessionStatusFailed: {
                        NSLog(@"合成失败：%@",[[session error] description]);
                        completionBlock(NO,outputPath);
                    }
                        break;
                        
                    case AVAssetExportSessionStatusCancelled: {
                        completionBlock(NO,outputPath);
                    }
                        break;
                        
                    case AVAssetExportSessionStatusCompleted: {
                        completionBlock(YES,outputPath);
                        
                    }
                        break;
                        
                    default: {
                        completionBlock(NO,outputPath);
                    }
                        break;
                }
                
            });
            
            
        }];
        
    });
    
    
    
}

#pragma mark - 音频输出路径
+ (NSURL *)exporterAudioPathWithFileName:(NSString *)outPutfileName
{
    NSString *fileName = [NSString stringWithFormat:@"%@.m4a",outPutfileName];
    
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *directoryName = @"editAudio";
    
    BOOL createDir = [self createDirWihtName:directoryName];
    
    if (createDir) {
        NSString *directory = [cachePath stringByAppendingPathComponent:directoryName];
        NSString *outputFilePath = [directory stringByAppendingPathComponent:fileName];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:outputFilePath]) {
            
            [[NSFileManager defaultManager] removeItemAtPath:outputFilePath error:nil];
        }
        
        return [NSURL fileURLWithPath:outputFilePath];
    }
    
    return nil;
}


#pragma mark - 剪辑音视频
+ (void)cutMediaWithMediaType:(LYZMediaType)mediaType
                    mediaPath:(NSURL *)mediaPath
                    startTime:(CGFloat)startTime
                      endTime:(CGFloat)endTime
               outPutFileName:(NSString *)fileName
              complitionBlock:(CompletionBlock)completionBlock
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        AVAsset *asset = [AVAsset assetWithURL:mediaPath];
        
        AVAssetExportSession *exporter;
        
        if (mediaType == LYZMediaTypeAudio) {
            
            exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
            
        } else if (mediaType == LYZMediaTypeVideo) {
            
            exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetPassthrough];
        }
        
        /** 剪辑(设置导出的时间段) */
        CMTime start = CMTimeMakeWithSeconds(startTime, asset.duration.timescale);
        CMTime duration = CMTimeMakeWithSeconds(endTime - startTime,asset.duration.timescale);
        exporter.timeRange = CMTimeRangeMake(start, duration);
        
        NSURL *outputPath;
        
        if (mediaType == LYZMediaTypeAudio) {
            
            exporter.outputFileType = AVFileTypeAppleM4A;
            outputPath = [self exporterAudioPathWithFileName:fileName];
            exporter.outputURL = [self exporterAudioPathWithFileName:fileName];
            
        } else if (mediaType == LYZMediaTypeVideo) {
            
            exporter.outputFileType = AVFileTypeAppleM4V;
            outputPath = [self exporterPathWithFileName:fileName];
            exporter.outputURL = [self exporterPathWithFileName:fileName];
        }
        
        exporter.shouldOptimizeForNetworkUse = YES;
        
        /** 合成后的回调 */
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                switch ([exporter status]) {
                        
                    case AVAssetExportSessionStatusFailed: {
                        NSLog(@"合成失败：%@",[[exporter error] description]);
                        completionBlock(NO,outputPath);
                    }
                        break;
                        
                    case AVAssetExportSessionStatusCancelled: {
                        completionBlock(NO,outputPath);
                    }
                        break;
                        
                    case AVAssetExportSessionStatusCompleted: {
                        completionBlock(YES,outputPath);
                    }
                        break;
                        
                    default: {
                        completionBlock(NO,outputPath);
                    }
                        break;
                }
                
            });
            
            
        }];
    });
    
    
    
}

#pragma mark - 添加水印
+ (void)writeImageAsMovie:(UIImage *)image
                     watermark:(UIImage *)watermark
                        toPath:(NSString*)path
                          size:(CGSize)size
                      duration:(double)duration
                           fps:(int)fps
             withCallbackBlock:(void(^)(BOOL success))callbackBlock
{
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    
    NSError *error = nil;
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                           fileType:AVFileTypeMPEG4
                                                              error:&error];
    if (error) {
        if (callbackBlock) {
            callbackBlock(NO);
        }
        return;
    }
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoSettings = @{AVVideoCodecKey: AVVideoCodecH264,
                                    AVVideoWidthKey: [NSNumber numberWithInt:size.width],
                                    AVVideoHeightKey: [NSNumber numberWithInt:size.height]};
    
    AVAssetWriterInput* writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                         outputSettings:videoSettings];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                     sourcePixelBufferAttributes:nil];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    [videoWriter addInput:writerInput];
    
    //Start a session:
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    CVPixelBufferRef buffer;
    CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &buffer);
    
    CMTime presentTime = CMTimeMake(0, fps);
    
    while (1)
    {
        if(writerInput.readyForMoreMediaData){
            buffer = [AssetTools pixelBufferFromCGImage:[image CGImage] watermark:[watermark CGImage] size:size];
            BOOL appendSuccess = [AssetTools appendToAdapter:adaptor
                                                                  pixelBuffer:buffer
                                                                       atTime:presentTime
                                                                    withInput:writerInput];
            
            NSAssert(appendSuccess, @"Failed to append");
            
            CMTime endTime = CMTimeMakeWithSeconds(duration, fps);
            BOOL appendSuccess2 = [AssetTools appendToAdapter:adaptor
                                                                   pixelBuffer:buffer
                                                                        atTime:endTime
                                                                     withInput:writerInput];
            
            NSAssert(appendSuccess2, @"Failed to append");
            
            
            //Finish the session:
            [writerInput markAsFinished];
            
            [videoWriter finishWritingWithCompletionHandler:^{
                NSLog(@"Successfully closed video writer");
                if (videoWriter.status == AVAssetWriterStatusCompleted) {
                    if (callbackBlock) {
                        callbackBlock(YES);
                    }
                } else {
                    if (callbackBlock) {
                        callbackBlock(NO);
                    }
                }
            }];
            CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
            break;
        }
    }
}

+ (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image
                                 watermark:(CGImageRef)watermark
                                      size:(CGSize)imageSize
{
    NSDictionary *options = @{(id)kCVPixelBufferCGImageCompatibilityKey: @YES,
                              (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES};
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, imageSize.width,
                                          imageSize.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, imageSize.width,
                                                 imageSize.height, 8, 4*imageSize.width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    
    CGContextDrawImage(context, CGRectMake(0 + (imageSize.width-CGImageGetWidth(image))/2,
                                           (imageSize.height-CGImageGetHeight(image))/2,
                                           CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    if (watermark) {
        CGContextDrawImage(context, CGRectMake(0 + (imageSize.width-CGImageGetWidth(watermark))/2,
                                               (imageSize.height-CGImageGetHeight(watermark))/2,
                                               CGImageGetWidth(watermark),
                                               CGImageGetHeight(watermark)), watermark);
    }
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

+ (BOOL)appendToAdapter:(AVAssetWriterInputPixelBufferAdaptor*)adaptor
            pixelBuffer:(CVPixelBufferRef)buffer
                 atTime:(CMTime)presentTime
              withInput:(AVAssetWriterInput*)writerInput
{
    while (!writerInput.readyForMoreMediaData) {
        usleep(1);
    }
    
    return [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
}

#pragma mark - 截取视频
+ (void)trimVideoWithVideoUrlStr:(NSURL *)videoUrl captureVideoWithStartTime:(double)start endTime:(double)end outputPath:(NSURL *)outputURL completion:(void(^)(NSURL *outputURL,NSError *error))completionHandle {
    CMTime startTime = CMTimeMakeWithSeconds(start, 1);
    CMTime videoDuration = CMTimeMakeWithSeconds(end - start, 1);
    CMTimeRange videoTimeRange = CMTimeRangeMake(startTime, videoDuration);
    
    AVAssetExportSession *session = [AVAssetExportSession exportSessionWithAsset:[AVAsset assetWithURL:videoUrl] presetName:AVAssetExportPresetMediumQuality];
    session.outputURL = outputURL;
    session.outputFileType = AVFileTypeMPEG4;
    session.timeRange = videoTimeRange;
    session.shouldOptimizeForNetworkUse = YES;
    [session exportAsynchronouslyWithCompletionHandler:^{
        if (completionHandle) {
            if (session.error) {
                completionHandle(nil,session.error);
            }else {
                completionHandle(outputURL,nil);
            }
        }
    }];
}

#pragma mark - 重设视频分辨率
+ (void)resizeVideoWithAssetURL:(NSURL *)assetURL outputURL:(NSURL *)outputURL preferSize:(CGSize)preferSize doneHandler:(void(^)(NSURL *outputURL,NSError *error))doneHandler {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:assetURL options:nil];
    
    AVAssetTrack *assetVideoTrack = nil;
    AVAssetTrack *assetAudioTrack = nil;
    
    if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
        assetVideoTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
    }
    if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] != 0) {
        assetAudioTrack = [asset tracksWithMediaType:AVMediaTypeAudio][0];
    }
    
    NSError *error = nil;
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    if (assetVideoTrack) {
        AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:assetVideoTrack atTime:kCMTimeZero error:&error];
    }
    if (assetAudioTrack) {
        AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:assetAudioTrack atTime:kCMTimeZero error:&error];
    }
    
    AVMutableVideoComposition *mutableVideoComposition = [AVMutableVideoComposition videoComposition];
    mutableVideoComposition.renderSize = preferSize;
    mutableVideoComposition.frameDuration = CMTimeMake(1, 24);
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, [mixComposition duration]);
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:(mixComposition.tracks)[0]];
    BOOL isPortrait_ = [AssetTools isVideoPortrait:asset];
    CGAffineTransform t = CGAffineTransformIdentity;
    if (isPortrait_) {
        t = CGAffineTransformRotate(t, M_PI_2);
        t = CGAffineTransformTranslate(t, 0, -preferSize.width);
    }
    preferSize = isPortrait_ ? CGSizeMake(preferSize.height, preferSize.width):preferSize;
    t = CGAffineTransformScale(t, preferSize.width / assetVideoTrack.naturalSize.width, preferSize.height / assetVideoTrack.naturalSize.height);
    [layerInstruction setTransform:t  atTime:kCMTimeZero];
    
    instruction.layerInstructions = @[layerInstruction];
    mutableVideoComposition.instructions = @[instruction];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputURL.path]) {
        [[NSFileManager defaultManager] removeItemAtPath:outputURL.path error:&error];
    }
    
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exportSession.videoComposition = mutableVideoComposition;
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        if (exportSession.status == AVAssetExportSessionStatusCompleted) {
            doneHandler(outputURL,nil);
        }else {
            doneHandler(nil,exportSession.error);
        }
    }];
}

+ (BOOL)isVideoPortrait:(AVAsset *)asset {
    BOOL isPortrait = NO;
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([tracks    count] > 0) {
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        
        CGAffineTransform t = videoTrack.preferredTransform;
        // Portrait
        if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0)
        {
            isPortrait = YES;
        }
        // PortraitUpsideDown
        if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0)  {
            
            isPortrait = YES;
        }
        // LandscapeRight
        if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0)
        {
            isPortrait = NO;
        }
        // LandscapeLeft
        if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0)
        {
            isPortrait = NO;
        }
    }
    return isPortrait;
}
@end
