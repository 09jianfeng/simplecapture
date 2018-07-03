//
//  YMTinyVideoMediaKit.h
//  YCloudRecorderDev
//
//  Created by 陈俊明 on 12/8/16.
//  Copyright © 2016 yy.com. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <AudioToolbox/AudioToolbox.h>

typedef NS_ENUM(NSInteger, YMVideoFormat) {
    YMVideoFormatUnknown        = 0,
    YMVideoFormatH263           = kCMVideoCodecType_H263,
    YMVideoFormatH264           = kCMVideoCodecType_H264,
    YMVideoFormatHEVC           = kCMVideoCodecType_HEVC,
    YMVideoFormat422YpCbCr8     = kCMVideoCodecType_422YpCbCr8,
    YMVideoFormatJPEG           = kCMVideoCodecType_JPEG,
    YMVideoFormatMPEG4          = kCMVideoCodecType_MPEG4Video,
};

extern NSString *const YMVideoFileTypeKey;
extern NSString *const YMVideoFormatKey;
extern NSString *const YMVideoResolutionKey;
extern NSString *const YMVideoFrameRateKey;
extern NSString *const YMVideoBitRateKey;
extern NSString *const YMVideoDurationKey;
extern NSString *const YMVideoFrameAmountKey;
extern NSString *const YMVideoFileSizeKey;

typedef NS_ENUM(NSInteger, YMAudioFileType) {
    YMAudioFileTypeUnknown          = 0,
    YMAudioFileTypeAIFF             = kAudioFileAIFFType,
    YMAudioFileTypeAIFC             = kAudioFileAIFCType,
    YMAudioFileTypeWAVE             = kAudioFileWAVEType,
    YMAudioFileTypeMP3              = kAudioFileMP3Type,
    YMAudioFileTypeAC3              = kAudioFileAC3Type,
    YMAudioFileTypeAAC_ADTS         = kAudioFileAAC_ADTSType,
    YMAudioFileTypeMPEG4            = kAudioFileMPEG4Type,
    YMAudioFileTypeM4A              = kAudioFileM4AType,
    YMAudioFileTypeM4B              = kAudioFileM4BType,
    YMAudioFileTypeCAF              = kAudioFileCAFType,
    YMAudioFileTypeAMR              = kAudioFileAMRType,
};

typedef NS_ENUM(NSInteger, YMAudioFormat) {
    YMAudioFormatUnknown = 0,
    YMAudioFormatLinearPCM = kAudioFormatLinearPCM,
    YMAudioFormatMPEG4AAC = kAudioFormatMPEG4AAC,
};

extern NSString *const YMAudioFileTypeKey;
extern NSString *const YMAudioFormatKey;
extern NSString *const YMAudioSampleRateKey;
extern NSString *const YMAudioBitRateKey;
extern NSString *const YMAudioDurationKey;
extern NSString *const YMAudioFileSizeKey;
extern NSString *const YMAudioBitDepthKey;
extern NSString *const YMAudioChannelKey;

/**
 媒体信息工具类
 
 用于获取音视频文件的媒体信息
 */
@interface YMTinyVideoMediaKit : NSObject

@end

@interface YMTinyVideoMediaKit (YMVideo)

/**
 视频编码格式
 
 以下为常用编码格式:
 
 YMVideoFormatUnknown
 
 YMVideoFormatH264
 
 YMVideoFormatJPEG
 
 @param audioPath 视频文件路径
 
 @return 成功返回视频编码格式，失败返回YMVideoFormatUnknown
 */
+ (YMVideoFormat)formatOfVideoAtPath:(NSString *)videoPath;

/**
 视频分辨率
 
 @param videoPath 视频文件路径
 
 @return 成功返回视频分辨率，失败返回值为0,0
 */
+ (CGSize)resolutionOfVideoAtPath:(NSString *)videoPath;

/**
 视频帧率，单位:fps
 
 @param videoPath 视频文件路径
 
 @return 成功返回视频帧率，失败返回0
 */
+ (CGFloat)frameRateOfVideoAtPath:(NSString *)videoPath;

/**
 视频码率，单位:bps
 
 @param videoPath 视频文件路径
 
 @return 成功返回视频码率，失败返回0
 */
+ (NSInteger)bitRateOfVideoAtPath:(NSString *)videoPath;

/**
 视频时长，单位:ms
 
 @param videoPath 视频文件路径
 
 @return 成功返回视频时长，失败返回0
 */
+ (CGFloat)durationOfVideoAtPath:(NSString *)videoPath;

/**
 视频帧数
 
 @param videoPath 视频文件路径
 
 @return 成功返回视频帧数，失败返回0
 */
+ (NSInteger)frameAmountOfVideoAtPath:(NSString *)videoPath;

/**
 视频文件大小，单位:b
 
 @param videoPath 视频文件路径
 
 @return 成功返回视频文件大小，失败返回0
 */
+ (NSInteger)fileSizeOfVideoAtPath:(NSString *)videoPath;

/**
 视频的音频编码格式
 
 @param videoPath 视频文件路径
 
 @return 成功返回音频编码格式，失败返回YMAudioFormatUnknown
 */
+ (YMAudioFormat)audioFormatOfVideoAtPath:(NSString *)videoPath;

/**
 视频的音频采样率，单位:hz
 
 @param videoPath 视频文件路径
 
 @return 成功返回音频采样率，失败返回0
 */
+ (NSInteger)audioSampleRateOfVideoAtPath:(NSString *)videoPath;

/**
 视频的音频码率，单位:bps
 
 @param videoPath 视频文件路径
 
 @return 成功返回音频码率，失败返回0
 */
+ (NSInteger)audioBitRateOfVideoAtPath:(NSString *)videoPath;

/**
 视频的音频通道数
 
 @param videoPath 视频文件路径
 
 @return 成功返回音频通道数，失败返回0
 */
+ (NSInteger)audioChannelOfVideoAtPath:(NSString *)videoPath;

+ (CGFloat)audioDurationOfVideoAtPath:(NSString *)videoPath;

/**
 视频属性字典
 
 YMVideoFileTypeKey         视频文件格式，YMVideoFileType*
 
 YMVideoFormatKey           视频编码格式，YMVideoFormat*
 
 YMVideoResolutionKey       视频分辨率
 
 YMVideoFrameRateKey        视频帧率，单位:fps
 
 YMVideoBitRateKey          视频码率，单位:bps
 
 YMVideoDurationKey         视频时长，单位:ms
 
 YMVideoFrameAmountKey      视频帧数
 
 YMVideoFileSizeKey         视频文件大小，单位:b
 
 YMVideoAudioFormatKey      视频中音频编码格式，YMAudioFormat*
 
 YMVideoAudioSampleRateKey  视频中音频采样率，单位:hz
 
 YMVideoAudioChannelKey     视频中音频通道数
 
 @param videoPath       视频文件路径
 
 @return 返回视频属性字典，成功则为视频属性对应值，失败则为等价于0的值
 */
+ (NSDictionary *)attributesOfVideoAtPath:(NSString *)videoPath;

@end

@interface YMTinyVideoMediaKit (YMAudio)

/**
 音频编码格式
 
 以下为常用编码格式:
 
 YMAudioFormatUnknown
 
 YMAudioFormatLinearPCM
 
 YMAudioFormatMPEG4AAC
 
 YMAudioFormatMPEGLayer3
 
 YMAudioFormatAMR
 
 @param audioPath 音频文件路径
 
 @return 成功返回音频编码格式，失败返回YMAudioFormatUnknown
 */
+ (YMAudioFormat)formatOfAudioAtPath:(NSString *)audioPath;

/**
 音频采样率，单位:hz
 
 @param audioPath 音频文件路径
 
 @return 成功返回音频采样率，失败返回0
 */
+ (NSInteger)sampleRateOfAudioAtPath:(NSString *)audioPath;

/**
 音频码率，单位:bps
 
 @param audioPath 音频文件路径
 
 @return 成功返回音频码率，失败返回0
 */
+ (NSInteger)bitRateOfAudioAtPath:(NSString *)audioPath;

/**
 音频时长，单位:ms
 
 @param audioPath 音频文件路径
 
 @return 成功返回音频文件时长，失败返回0
 */
+ (NSInteger)durationOfAudioAtPath:(NSString *)audioPath;

/**
 音频文件大小，单位:b
 
 @param audioPath 音频文件路径
 
 @return 成功返回音频文件大小，失败返回0
 */
+ (NSInteger)fileSizeOfAudioAtPath:(NSString *)audioPath;

/**
 音频文件格式
 
 以下为常用文件格式:
 
 YMAudioFileTypeUnknown
 
 YMAudioFileTypeAIFF
 
 YMAudioFileTypeAIFC
 
 YMAudioFileTypeWAVE
 
 YMAudioFileTypeMP3
 
 YMAudioFileTypeMPEG4
 
 YMAudioFileTypeM4A
 
 YMAudioFileTypeCAF
 
 YMAudioFileTypeAMR
 
 @param audioPath 音频文件路径
 
 @return 成功返回音频文件格式，失败返回YMAudioFileTypeUnknown
 */
+ (YMAudioFileType)fileTypeOfAudioAtPath:(NSString *)audioPath;

/**
 音频pcm位深
 
 @param audioPath 音频文件路径
 
 @return 音频pcm位深
 */
+ (NSInteger)bitDepthOfAudioAtPath:(NSString *)audioPath;

/**
 音频通道数
 
 @param audioPath 音频文件路径
 
 @return 成功返回音频通道数，失败返回0
 */
+ (NSInteger)channelOfAudioAtPath:(NSString *)audioPath;

/**
 音频属性字典
 
 YMAudioFileTypeKey     音频文件格式，YMAudioFileType*
 
 YMAudioFormatKey       音频编码格式，YMAudioFormat*
 
 YMAudioSampleRateKey   音频采样率，单位:hz
 
 YMAudioBitRateKey      音频码率，单位:bps
 
 YMAudioDurationKey     音频时长，单位:ms
 
 YMAudioFileSizeKey     音频文件大小，单位:b
 
 YMAudioBitDepthKey     音频pcm位深
 
 YMAudioChannelKey      音频通道数
 
 @param audioPath       音频文件路径
 
 @return 返回音频属性字典，成功则为音频属性对应值，失败则为等价于0的值
 */
+ (NSDictionary *)attributesOfAudioAtPath:(NSString *)audioPath;

@end
