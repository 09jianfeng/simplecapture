//
//  M4aPlayer.m
//  SimpleCapture
//
//  Created by JFChen on 2020/8/10.
//  Copyright © 2020 duowan. All rights reserved.
//

#import "M4aPlayer.h"

@implementation M4aPlayer

+ (AVAsset *)getAssetWithPath:(NSURL *)audioPath{
    AVAsset *audioAsset = [AVAsset assetWithURL:audioPath];
    return audioAsset;
}

//从资源轨道中读取样本
+ (NSData *)readAudioSamplesFromAsset:(AVAsset *)asset sampleRate:(int *)sampleRate channel:(int *)channel{

    NSError *error = nil;

    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];

    if (!assetReader) {
        NSLog(@"Error creating asset reader: %@", [error localizedDescription]);
        return nil;
    }

    //获取资源中找到的第一个音频轨道
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    CMAudioFormatDescriptionRef formatDesc = (__bridge CMAudioFormatDescriptionRef)track.formatDescriptions[0];
    const AudioStreamBasicDescription *basicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc);
    *sampleRate = basicDesc->mSampleRate;
    *channel = basicDesc->mChannelsPerFrame;
    
    /*
     *从资源轨道读取音频样本时使用的解压设置
     *kAudioFormatLinearPCM 样本需要以未压缩的格式被读取
     *little-endian字节序(小端序)
     *有符号整型
     *16位
     */
    NSDictionary *outputSettings = @{
        AVFormatIDKey               : @(kAudioFormatLinearPCM),
        AVLinearPCMIsBigEndianKey   : @NO,
        AVLinearPCMIsFloatKey       : @NO,
        AVLinearPCMBitDepthKey      : @(16)
    };

    //创建trackOutput，作为AVAssetReader的输出
    AVAssetReaderTrackOutput *trackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:outputSettings];
    [assetReader addOutput:trackOutput];
    //开始预收取样本数据
    [assetReader startReading];

    NSMutableData *sampleData = [NSMutableData data];

    while (assetReader.status == AVAssetReaderStatusReading) {

        CMSampleBufferRef sampleBuffer = [trackOutput copyNextSampleBuffer];
        
        if (sampleBuffer) {
            //获取音频样本
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBuffer);
            //确定长度，并创建一个16位的带符号的整型数组来保存音频赝本
            size_t length = CMBlockBufferGetDataLength(blockBufferRef);
            SInt16 sampleBytes[length];
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, sampleBytes);
            //数组内容附加在NSData实例后
            [sampleData appendBytes:sampleBytes length:length];

            //指定样本buffer已经处理和不可再继续使用
            CMSampleBufferInvalidate(sampleBuffer);
            CFRelease(sampleBuffer);
        }
    }

    //数据读取成功
    if (assetReader.status == AVAssetReaderStatusCompleted) {
        return sampleData;
    } else {
        NSLog(@"Failed to read audio samples from asset");
        return nil;
    }
}


@end
