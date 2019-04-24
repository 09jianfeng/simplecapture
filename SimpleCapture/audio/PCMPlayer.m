//
//  PCMPlayer.m
//  SimpleCapture
//
//  Created by JFChen on 2018/5/25.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "PCMPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <assert.h>

#define INPUT_BUS 1   //audiounit的 bus 1输入在Remote IO 默认是关闭的，在录音的状态下 需要把bus 1设置成开启状态。bus1（element0）代表的是麦克风采集组件.
#define OUTPUT_BUS 0  //audiounit 播放音频文件就是在bus 0传送数据。也就是说bus0（element0）代表的是扬声器。bus0的scope代表的是扬声器的scope_Input，跟scope_Output。

@implementation PCMPlayer
{
    AudioUnit audioUnit;
    NSInputStream *inputSteam;
}

- (void)play {
    [self initPlayer];
    AudioOutputUnitStart(audioUnit);
}


- (double)getCurrentTime {
    Float64 timeInterval = 0;
    if (inputSteam) {
        
    }
    
    return timeInterval;
}



- (void)initPlayer {
    // open pcm stream
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"pcm"];
    inputSteam = [NSInputStream inputStreamWithURL:url];
    if (!inputSteam) {
        NSLog(@"打开文件失败 %@", url);
    }
    else {
        [inputSteam open];
    }
    
    OSStatus status = noErr;
    
    // set audio session
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    {// 设置 audioUnit， remoteIO类型
        AudioComponentDescription audioDesc;
        audioDesc.componentType = kAudioUnitType_Output;
        audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
        audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        audioDesc.componentFlags = 0;
        audioDesc.componentFlagsMask = 0;
        
        AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
        AudioComponentInstanceNew(inputComponent, &audioUnit);
    }
    
    // format 设置输入给扬声器的声音格式
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = 44100; // 采样率
    outputFormat.mFormatID         = kAudioFormatLinearPCM; // PCM格式
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger; // 整形
    outputFormat.mFramesPerPacket  = 1; // 每packet只有1个帧
    outputFormat.mChannelsPerFrame = 1; // 声道数
    outputFormat.mBytesPerFrame    = 2; // 每帧只有2个byte 声道*位深*Packet数
    outputFormat.mBytesPerPacket   = 2; // 每个Packet只有2个byte
    outputFormat.mBitsPerChannel   = 16; // 位深
    [self printAudioStreamBasicDescription:outputFormat];
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status) {
        NSLog(@"AudioUnitSetProperty eror with status:%d", status);
    }
    
    
    // render callback。 播放回调用
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
    
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result %d", result);
}


static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    PCMPlayer *player = (__bridge PCMPlayer *)inRefCon;
    
    ioData->mBuffers[0].mDataByteSize = (UInt32)[player->inputSteam read:ioData->mBuffers[0].mData maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];;
    NSLog(@"out size: %d", ioData->mBuffers[0].mDataByteSize);
    
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    return noErr;
}


- (void)stop {
    AudioOutputUnitStop(audioUnit);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayToEnd:)]) {
        __strong typeof (PCMPlayer) *player = self;
        [self.delegate onPlayToEnd:player];
    }
    
    [inputSteam close];
}

- (void)dealloc {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
}


- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}

@end
