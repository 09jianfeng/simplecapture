//
//  AccompanimentPlay.m
//  SimpleCapture
//
//  Created by JFChen on 2018/5/25.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "AccompanimentPlay.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>

#define INPUT_BUS 1
#define OUTPUT_BUS 0
#define CONST_BUFFER_SIZE 2048*2*10

@implementation AccompanimentPlay{
    AudioUnit audioUnit;
    AudioBufferList *buffList;
    
    NSInputStream *inputSteam_left;
    NSInputStream *inputStream_right;
    Byte *buffer;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)start{
    [ self initAudioUnit];
    AudioOutputUnitStart(audioUnit);

}

- (void)stop{
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    
    if (buffList != NULL) {
        if (buffList->mBuffers[0].mData) {
            free(buffList->mBuffers[0].mData);
            buffList->mBuffers[0].mData = NULL;
        }
        free(buffList);
        buffList = NULL;
    }
    
    [inputSteam_left close];
    AudioComponentInstanceDispose(audioUnit);
}

- (void)initAudioUnit {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"pcm"];
    inputSteam_left = [NSInputStream inputStreamWithURL:url];
    if (!inputSteam_left) {
        NSLog(@"打开文件失败 %@", url);
    }
    else {
        [inputSteam_left open];
    }
    
    url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"pcm"];
    inputStream_right = [NSInputStream inputStreamWithURL:url];
    if (!inputStream_right) {
        NSLog(@"打开文件失败 %@",url);
    }else{
        [inputStream_right open];
    }
    
    NSError *error = nil;
    OSStatus status = noErr;
    
    // audio session
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error) {
        NSLog(@"setCategory error:%@", error);
    }
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.05 error:&error];
    if (error) {
        NSLog(@"setPreferredIOBufferDuration error:%@", error);
    }
    
    {// 伴奏右声道播放
        buffer = malloc(CONST_BUFFER_SIZE);
        // audio unit new
        AudioComponentDescription audioDesc;
        audioDesc.componentType = kAudioUnitType_Output;
        audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
        audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        audioDesc.componentFlags = 0;
        audioDesc.componentFlagsMask = 0;
        AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
        status = AudioComponentInstanceNew(inputComponent, &audioUnit);
        if (status != noErr) {
            NSLog(@"AudioUnitGetProperty error, ret: %d", status);
        }
        
        // set format
        AudioStreamBasicDescription inputFormat;
        inputFormat.mSampleRate = 44100;
        inputFormat.mFormatID = kAudioFormatLinearPCM;
        inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
        inputFormat.mFramesPerPacket = 1;
        inputFormat.mChannelsPerFrame = 2;
        inputFormat.mBytesPerPacket = 2;
        inputFormat.mBytesPerFrame = 2;
        inputFormat.mBitsPerChannel = 16;
        
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      OUTPUT_BUS,
                                      &inputFormat,
                                      sizeof(inputFormat));
        
        if (status != noErr) {
            NSLog(@"AudioUnitGetProperty error, ret: %d", status);
        }
        
        AURenderCallbackStruct playCallback;
        playCallback.inputProc = PlayCallback;
        playCallback.inputProcRefCon = (__bridge void *)self;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Input,
                                      OUTPUT_BUS,
                                      &playCallback,
                                      sizeof(playCallback));
        if (status != noErr) {
            NSLog(@"AudioUnitGetProperty error, ret: %d", status);
        }
    }
    
    {// 录制PCM
        // buffer list
        uint32_t numberBuffers = 1;
        buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + (numberBuffers - 1) * sizeof(AudioBuffer));
        buffList->mNumberBuffers = numberBuffers;
        buffList->mBuffers[0].mNumberChannels = 1;
        buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
        buffList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
        
        for (int i =1; i < numberBuffers; ++i) {
            buffList->mBuffers[i].mNumberChannels = 1;
            buffList->mBuffers[i].mDataByteSize = CONST_BUFFER_SIZE;
            buffList->mBuffers[i].mData = malloc(CONST_BUFFER_SIZE);
        }
        
        // enable record
        UInt32 flag = 1;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      INPUT_BUS,
                                      &flag,
                                      sizeof(flag));
        if (status != noErr) {
            NSLog(@"AudioUnitGetProperty error, ret: %d", status);
        }
     
        AudioStreamBasicDescription outputFormat;
        outputFormat.mSampleRate = 44100;
        outputFormat.mFormatID = kAudioFormatLinearPCM;
        outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
        outputFormat.mFramesPerPacket = 1;
        outputFormat.mChannelsPerFrame = 1;
        outputFormat.mBytesPerPacket = 2;
        outputFormat.mBytesPerFrame = 2;
        outputFormat.mBitsPerChannel = 16;

         status = AudioUnitSetProperty(audioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     INPUT_BUS,
                                     &outputFormat,
                                     sizeof(outputFormat));
         if (status != noErr) {
             NSLog(@"AudioUnitGetProperty error, ret: %d", status);
         }
        
        // set callback
        AURenderCallbackStruct recordCallback;
        recordCallback.inputProc = RecordCallback;
        recordCallback.inputProcRefCon = (__bridge void *)self;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Output,
                                      INPUT_BUS,
                                      &recordCallback,
                                      sizeof(recordCallback));
        if (status != noErr) {
            NSLog(@"AudioUnitGetProperty error, ret: %d", status);
        }
    }
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result %d", result);
}



#pragma mark - callback

static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    AccompanimentPlay *vc = (__bridge AccompanimentPlay *)inRefCon;
    vc->buffList->mNumberBuffers = 1;
    OSStatus status = AudioUnitRender(vc->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, vc->buffList);
    if (status != noErr) {
        NSLog(@"AudioUnitRender error:%d", status);
    }
    
    NSLog(@"size1 = %d", vc->buffList->mBuffers[0].mDataByteSize);
    [vc writePCMData:vc->buffList->mBuffers[0].mData size:vc->buffList->mBuffers[0].mDataByteSize];
    
    return noErr;
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    AccompanimentPlay *vc = (__bridge AccompanimentPlay *)inRefCon;
    
    {//录制的声音在左声道
        memcpy(ioData->mBuffers[0].mData, vc->buffList->mBuffers[0].mData, vc->buffList->mBuffers[0].mDataByteSize);
        ioData->mBuffers[0].mDataByteSize = vc->buffList->mBuffers[0].mDataByteSize;
    }
    
    {//伴奏在右声道
        NSInteger bytes = CONST_BUFFER_SIZE < ioData->mBuffers[1].mDataByteSize*2 ? CONST_BUFFER_SIZE : ioData->mBuffers[1].mDataByteSize*2; //
        bytes = [vc->inputSteam_left read:vc->buffer maxLength:bytes];
        
        for (int i = 0; i < bytes; ++i) {
            ((Byte*)ioData->mBuffers[1].mData)[i/2] = vc->buffer[i];
        }
        ioData->mBuffers[1].mDataByteSize = (UInt32)bytes / 2;
        
        if (ioData->mBuffers[1].mDataByteSize < ioData->mBuffers[0].mDataByteSize) {
            ioData->mBuffers[0].mDataByteSize = ioData->mBuffers[1].mDataByteSize;
        }
        
        NSLog(@"size2 = %d", ioData->mBuffers[0].mDataByteSize);
    }
    
    return noErr;
}

- (void)writePCMData:(Byte *)buffer size:(int)size {
    static FILE *file = NULL;
    NSString *path = [NSTemporaryDirectory() stringByAppendingString:@"/record.pcm"];
    if (!file) {
        file = fopen(path.UTF8String, "w");
    }
    fwrite(buffer, size, 1, file);
}

@end
