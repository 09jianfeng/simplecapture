//
//  YMTinyVideoMediaKit.m
//  YCloudRecorderDev
//
//  Created by 陈俊明 on 12/8/16.
//  Copyright © 2016 yy.com. All rights reserved.
//

#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTType.h>
#import "YMTinyVideoMediaKit.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "VideoFileKit.h"

@implementation YMTinyVideoMediaKit

NSString *const YMVideoFormatKey = @"videoFormat";
NSString *const YMVideoResolutionKey = @"videoResolution";
NSString *const YMVideoFrameRateKey = @"videoFrameRate";
NSString *const YMVideoBitRateKey = @"videoBitRate";
NSString *const YMVideoDurationKey = @"videoDuration";
NSString *const YMVideoFrameAmountKey = @"videoFrameAmount";
NSString *const YMVideoFileSizeKey = @"videoFileSize";
NSString *const YMVideoAudioFormatKey = @"videoAudioFormat";
NSString *const YMVideoAudioSampleRateKey = @"videoAudioSampleRate";
NSString *const YMVideoAudioBitRateKey = @"videoAudioBitRate";
NSString *const YMVideoAudioChannelKey = @"videoAudioChannel";
NSString *const YMVideoAudioDurationKey = @"videoAudioDuration";

NSString *const YMAudioFileTypeKey = @"audioFileType";
NSString *const YMAudioFormatKey = @"audioFormat";
NSString *const YMAudioSampleRateKey = @"audioSampleRate";
NSString *const YMAudioBitRateKey = @"audioBitRate";
NSString *const YMAudioDurationKey = @"audioDuration";
NSString *const YMAudioFileSizeKey = @"audioFileSize";
NSString *const YMAudioBitDepthKey = @"audioBitDepth";
NSString *const YMAudioChannelKey = @"audioChannel";

static NSMutableDictionary *internalDict;

+ (NSDictionary *)cacheAttributeDictOfID:(NSString *)fileID {
    if (!internalDict) {
        internalDict = [NSMutableDictionary dictionary];
    }
 
    return internalDict[fileID];
}

@end

@implementation YMTinyVideoMediaKit (YMVideo)

+ (YMVideoFormat)formatOfVideoAtPath:(NSString *)videoPath {
    NSNumber *videoFormat = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoFormatKey];
    return [videoFormat integerValue];
}

+ (CGSize)resolutionOfVideoAtPath:(NSString *)videoPath {
    NSNumber *videoResolution = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoResolutionKey];
    return [videoResolution CGSizeValue];
}

+ (CGFloat)frameRateOfVideoAtPath:(NSString *)videoPath {
    NSNumber *videoFrameRate = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoFrameRateKey];
    return [videoFrameRate floatValue];
}

+ (NSInteger)bitRateOfVideoAtPath:(NSString *)videoPath {
    NSNumber *videoBitRate = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoBitRateKey];
    return [videoBitRate integerValue];
}

+ (CGFloat)durationOfVideoAtPath:(NSString *)videoPath {
    NSNumber *videoDuration = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoDurationKey];
    return [videoDuration floatValue];
}

+ (NSInteger)frameAmountOfVideoAtPath:(NSString *)videoPath {
    NSNumber *videoDuration = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoFrameAmountKey];
    return [videoDuration integerValue];
}

+ (NSInteger)fileSizeOfVideoAtPath:(NSString *)videoPath {
    NSNumber *videoFileSize = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoFileSizeKey];
    return [videoFileSize integerValue];
}

+ (YMAudioFormat)audioFormatOfVideoAtPath:(NSString *)videoPath {
    NSNumber *audioFormat = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoAudioFormatKey];
    return (YMAudioFormat)[audioFormat integerValue];
}

+ (NSInteger)audioSampleRateOfVideoAtPath:(NSString *)videoPath {
    NSNumber *audioSampleRate = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoAudioSampleRateKey];
    return [audioSampleRate integerValue];
}

+ (NSInteger)audioBitRateOfVideoAtPath:(NSString *)videoPath {
    NSNumber *audioBitRate = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoAudioBitRateKey];
    return [audioBitRate integerValue];
}

+ (NSInteger)audioChannelOfVideoAtPath:(NSString *)videoPath {
    NSNumber *audioChannel = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoAudioChannelKey];
    return [audioChannel integerValue];
}

+ (CGFloat)audioDurationOfVideoAtPath:(NSString *)videoPath {
    NSNumber *audioDuration = [YMTinyVideoMediaKit attributesOfVideoAtPath:videoPath][YMVideoAudioDurationKey];
    return [audioDuration floatValue];
}

+ (NSDictionary *)attributesOfVideoAtPath:(NSString *)videoPath {
    NSString *videoID = [VideoFileKit idOfFileAtPath:videoPath];
    
    if (videoID) {
        NSDictionary *cacheAttributeDict = [YMTinyVideoMediaKit cacheAttributeDictOfID:videoID];
    
        if (cacheAttributeDict) {
            return cacheAttributeDict;
        }
    }
    
    NSDictionary *mediaInfoDict = nil;
    
    YMVideoFormat videoFormat = YMVideoFormatUnknown;
    CGSize videoResolution = CGSizeZero;
    CGFloat videoFrameRate = 0.0f;
    NSInteger videoBitRate = 0;
    CGFloat videoDuration = 0;
    NSInteger videoFrameAmount = 0;
    NSInteger videoFileSize = 0;
    YMAudioFormat videoAudioFormat = YMAudioFormatUnknown;
    NSInteger videoAudioSampleRate = 0;
    NSInteger videoAudioBitRate = 0;
    NSInteger videoAudioChannel = 0;
    CGFloat videoAudioDuration = 0;
    
    if (videoPath) {
        NSDictionary * options = @{AVURLAssetPreferPreciseDurationAndTimingKey:@(YES)};
        NSURL *videoURL = [VideoFileKit pathToFileUrl:videoPath];
        AVURLAsset *videoAsset = [[AVURLAsset alloc] initWithURL:videoURL options:options];
        // 视频分辨率、帧率、码率
        NSArray *videoTrackArray = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        if ([videoTrackArray count] > 0) {
            AVAssetTrack *videoTrack = [videoTrackArray objectAtIndex:0];
            
            videoResolution = videoTrack.naturalSize;
            videoFrameRate = videoTrack.nominalFrameRate;
            videoBitRate = (NSInteger)videoTrack.estimatedDataRate;
            // 视频时长
            CMTime videoAssetTime = videoTrack.timeRange.duration;
            videoDuration = CMTimeGetSeconds(videoAssetTime) * 1000;
            // 视频帧数
            // timescale通常为600，表示1s含600个单位数据，取值为600是因为它是常见帧率15，24，25，30的公倍数
            // value表示在timescale基准下一共含有的数据量，故获取帧数则需要将基准调整为帧率，如1s含15个单位数据（15帧）
            // 故最终获取方法为:value/(timescale/frameRate)
            videoFrameAmount = videoAssetTime.value / (videoAssetTime.timescale / videoFrameRate);
            
            videoFormat = CMVideoFormatDescriptionGetCodecType((CMFormatDescriptionRef)videoTrack.formatDescriptions.firstObject);
        }
        // 视频文件大小
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSDictionary *attributeDict = [fileManager attributesOfItemAtPath:videoPath
                                                                    error:nil];
        if (attributeDict) {
            videoFileSize = (NSInteger)attributeDict.fileSize;
        }
        
        NSArray *audioTrackArray = [videoAsset tracksWithMediaType:AVMediaTypeAudio];
        if ([audioTrackArray count] > 0) {
            AVAssetTrack *audioTrack = [audioTrackArray objectAtIndex:0];
            videoAudioDuration = CMTimeGetSeconds(audioTrack.timeRange.duration) * 1000;
            CMFormatDescriptionRef descriptionRef = (__bridge CMFormatDescriptionRef)(audioTrack.formatDescriptions[0]);
            const AudioStreamBasicDescription *description = CMAudioFormatDescriptionGetStreamBasicDescription(descriptionRef);
            if(description){
                videoAudioFormat = (YMAudioFormat)description->mFormatID;
                videoAudioSampleRate = description->mSampleRate;
                videoAudioChannel = description->mChannelsPerFrame;
            }
            videoAudioBitRate = audioTrack.estimatedDataRate;
        }
    }
    
    mediaInfoDict = @{
                      YMVideoResolutionKey:[NSValue valueWithCGSize:videoResolution],
                      YMVideoFrameRateKey:@(videoFrameRate),
                      YMVideoBitRateKey:@(videoBitRate),
                      YMVideoDurationKey:@(videoDuration),
                      YMVideoFrameAmountKey:@(videoFrameAmount),
                      YMVideoFileSizeKey:@(videoFileSize),
                      YMVideoFormatKey:@(videoFormat),
                      YMVideoAudioFormatKey:@(videoAudioFormat),
                      YMVideoAudioSampleRateKey:@(videoAudioSampleRate),
                      YMVideoAudioBitRateKey:@(videoAudioBitRate),
                      YMVideoAudioChannelKey:@(videoAudioChannel),
                      YMVideoAudioDurationKey:@(videoAudioDuration),
                      };
    
    if (videoID) {
        internalDict[videoID] = mediaInfoDict;
    }
    
    return mediaInfoDict;
}

@end

@implementation YMTinyVideoMediaKit (YMAudio)

+ (YMAudioFormat)formatOfAudioAtPath:(NSString *)audioPath {
    NSNumber *audioFormat = [YMTinyVideoMediaKit attributesOfAudioAtPath:audioPath][YMAudioFormatKey];
    return [audioFormat integerValue];
}

+ (NSInteger)sampleRateOfAudioAtPath:(NSString *)audioPath {
    NSNumber *audioSampleRate = [YMTinyVideoMediaKit attributesOfAudioAtPath:audioPath][YMAudioSampleRateKey];
    return [audioSampleRate integerValue];
}

+ (NSInteger)bitRateOfAudioAtPath:(NSString *)audioPath {
    NSNumber *audioBitRate = [YMTinyVideoMediaKit attributesOfAudioAtPath:audioPath][YMAudioBitRateKey];
    return [audioBitRate integerValue];
}

+ (NSInteger)durationOfAudioAtPath:(NSString *)audioPath {
    NSNumber *audioDuration = [YMTinyVideoMediaKit attributesOfAudioAtPath:audioPath][YMAudioDurationKey];
    return [audioDuration integerValue];
}

+ (NSInteger)fileSizeOfAudioAtPath:(NSString *)audioPath {
    NSNumber *audioFileSize = [YMTinyVideoMediaKit attributesOfAudioAtPath:audioPath][YMAudioFileSizeKey];
    return [audioFileSize integerValue];
}

+ (YMAudioFileType)fileTypeOfAudioAtPath:(NSString *)audioPath {
    NSNumber *audioFileType = [YMTinyVideoMediaKit attributesOfAudioAtPath:audioPath][YMAudioFileTypeKey];
    return [audioFileType integerValue];
}

+ (NSInteger)bitDepthOfAudioAtPath:(NSString *)audioPath {
    NSNumber *audioBitDepth = [YMTinyVideoMediaKit attributesOfAudioAtPath:audioPath][YMAudioBitDepthKey];
    return [audioBitDepth integerValue];
}

+ (NSInteger)channelOfAudioAtPath:(NSString *)audioPath {
    NSNumber *audioChannel = [YMTinyVideoMediaKit attributesOfAudioAtPath:audioPath][YMAudioChannelKey];
    return [audioChannel integerValue];
}

+ (NSDictionary *)attributesOfAudioAtPath:(NSString *)audioPath {
    NSString *audioID = [VideoFileKit idOfFileAtPath:audioPath];
    
    if (audioID) {
        NSDictionary *cacheAttributeDict = [YMTinyVideoMediaKit cacheAttributeDictOfID:audioID];
    
        if (cacheAttributeDict) {
            return cacheAttributeDict;
        }
    }
    
    NSDictionary *mediaInfoDict = nil;
    
    YMAudioFileType audioFileType = YMAudioFileTypeUnknown;
    YMAudioFormat audioFormat = YMAudioFormatUnknown;
    NSInteger audioSampleRate = 0;
    NSInteger audioBitRate = 0;
    NSInteger audioDuration = 0;
    NSInteger audioFileSize = 0;
    NSInteger audioBitDepth = 0;
    NSInteger audioChannel = 0;
    
    if (audioPath) {
        NSURL *audioURL = [VideoFileKit pathToFileUrl:audioPath];
        AudioFileID audioFileID;
        OSStatus status = AudioFileOpenURL((__bridge CFURLRef)audioURL, kAudioFileReadPermission, 0, &audioFileID);
        
        if(status == noErr){

            // 文件格式
            UInt32 fileType;
            UInt32 fileTypeSize = sizeof(fileType);
            status = AudioFileGetProperty(audioFileID, kAudioFilePropertyFileFormat, &fileTypeSize, &fileType);
            if(status == noErr){
                audioFileType = fileType;
            }
            
            // 码率
            UInt32 bitRate;
            UInt32 bitRateSize = sizeof(bitRate);
            status = AudioFileGetProperty(audioFileID, kAudioFilePropertyBitRate, &bitRateSize, &bitRate);
            if(status == noErr){
                audioBitRate = bitRate;
            }
            
            // 位深
            UInt32 bitDepth;
            UInt32 bitDepthSize = sizeof(bitDepth);
            status = AudioFileGetProperty(audioFileID, kAudioFilePropertySourceBitDepth, &bitDepthSize, &bitDepth);
            if(status == noErr){
                audioBitDepth = bitDepth;
            }
            
            // 时长
            Float64 duration;
            UInt32 durationSize = sizeof(duration);
            status = AudioFileGetProperty(audioFileID, kAudioFilePropertyEstimatedDuration, &durationSize, &duration);
            if(status == noErr){
                audioDuration = duration * 1000;
            }
            
            // 编码格式、采样率、通道数
            AudioStreamBasicDescription basicDescription;
            UInt32 basicDescriptionSize = sizeof(basicDescription);
            status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &basicDescriptionSize, &basicDescription);
            if(status == noErr){
                audioFormat = basicDescription.mFormatID;
                audioSampleRate = basicDescription.mSampleRate;
                audioChannel = basicDescription.mChannelsPerFrame;
            }
            
            AudioFileClose(audioFileID);
            
            // 文件大小
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSDictionary *attributeDict = [fileManager attributesOfItemAtPath:audioPath
                                                                        error:nil];
            if(attributeDict){
                audioFileSize = (NSInteger)attributeDict.fileSize;
            }
            
        }
    }
    
    mediaInfoDict = @{
                      YMAudioFormatKey:@(audioFormat),
                      YMAudioSampleRateKey:@(audioSampleRate),
                      YMAudioBitRateKey:@(audioBitRate),
                      YMAudioDurationKey:@(audioDuration),
                      YMAudioFileSizeKey:@(audioFileSize),
                      YMAudioFileTypeKey:@(audioFileType),
                      YMAudioBitDepthKey:@(audioBitDepth),
                      YMAudioChannelKey:@(audioChannel),
                      };
    
    if(audioID){
        internalDict[audioID] = mediaInfoDict;
    }
    
    return mediaInfoDict;
}

@end
