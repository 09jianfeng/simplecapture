//
//  AudioCaptureOrPlay.m
//  SimpleCapture
//
//  Created by JFChen on 2018/5/25.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "AudioCaptureOrPlay.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>
#import <UIKit/UIKit.h>

#define INPUT_BUS 1
#define OUTPUT_BUS 0
#define CONST_BUFFER_SIZE 2048*2*10

@implementation AudioCaptureOrPlay{
    AudioUnit audioUnit;
    AudioBufferList *buffList;
    uint32_t numberBuffers;
    uint32_t sampleRate;
    AVAudioSession *session;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        numberBuffers = 1; //channel number
        sampleRate = 8000;
        
        session = [AVAudioSession sharedInstance];
        [ self initAudioUnit];
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self
                   selector:@selector(handleInterruptionNotificationYYAudio:)
                       name:AVAudioSessionInterruptionNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(handleRouteChangeNotificationYYAudio:)
                       name:AVAudioSessionRouteChangeNotification
                     object:nil];
        // TODO(tkchin): Maybe listen to SilenceSecondaryAudioHintNotification.
        [center addObserver:self
                   selector:@selector(handleMediaServicesWereLostYYAudio:)
                       name:AVAudioSessionMediaServicesWereLostNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(handleMediaServicesWereResetYYAudio:)
                       name:AVAudioSessionMediaServicesWereResetNotification
                     object:nil];
          
              [center addObserver:self
                   selector:@selector(handleSilenceSecondaryAudioHintNotificationYYAudio:)
                       name:AVAudioSessionSilenceSecondaryAudioHintNotification
                     object:nil];
          
          [center addObserver:self
                     selector:@selector(handleApplicationWillEnterForegroundYYAudio:)
                         name:UIApplicationWillEnterForegroundNotification
                       object:nil];
          
          [center addObserver:self
                     selector:@selector(handleApplicationWillEnterBackgroundYYAudio:)
                         name:UIApplicationDidEnterBackgroundNotification
                       object:nil];
    }
    return self;
}

+ (void)setAudioSessionLouderSpeaker{
    NSError* error = nil;
    BOOL enable = NO;
    
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setMode:AVAudioSessionModeDefault error:&error];
    
    AVAudioSessionCategoryOptions options = session.categoryOptions;
    if (error != nil) {
        NSLog(@"AudioCaptureOrPlay Could not set mode2 %@",error);
    }
    
    if (enable) {
        options |= AVAudioSessionCategoryOptionDefaultToSpeaker;
        options |= AVAudioSessionCategoryOptionMixWithOthers;
    }
    else {
        options &= ~AVAudioSessionCategoryOptionDefaultToSpeaker;
    }
    options |= AVAudioSessionCategoryOptionAllowBluetooth;
    
        if (error) {
        NSLog(@"AudioCaptureOrPlay <error> %@",error);
    }
    
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
    withOptions:options
          error:&error];
}


+ (void)setAudioSessionLouderSpeaker2{
    NSError* error = nil;
    BOOL enable = NO;
    
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setMode:AVAudioSessionModeVoiceChat error:&error];
    
    AVAudioSessionCategoryOptions options = session.categoryOptions;
    if (error != nil) {
        NSLog(@"AudioCaptureOrPlay Could not set mode2 %@",error);
    }
    
    if (enable) {
        options |= AVAudioSessionCategoryOptionDefaultToSpeaker;
        options |= AVAudioSessionCategoryOptionMixWithOthers;
    }
    else {
        options &= ~AVAudioSessionCategoryOptionDefaultToSpeaker;
    }
    options |= AVAudioSessionCategoryOptionAllowBluetooth;
    
        if (error) {
        NSLog(@"AudioCaptureOrPlay <error> %@",error);
    }
    
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
    withOptions:options
          error:&error];
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
    
    AudioComponentInstanceDispose(audioUnit);
}

- (void)initAudioUnit {
    [AudioCaptureOrPlay setAudioSessionLouderSpeaker];
    
    NSError *error = nil;
    OSStatus status = noErr;
    
    // audio session
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [[AVAudioSession sharedInstance] setPreferredSampleRate:(double)sampleRate error:&error];
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.05 error:&error];
    // audio unit new
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    // enable record
    UInt32 flag = 1;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  INPUT_BUS,
                                  &flag,
                                  sizeof(flag));
    // enable play
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  OUTPUT_BUS,
                                  &flag,
                                  sizeof(flag));
    
    //echo cancellation open
    UInt32 echoCancellation = 0;
    UInt32 size = sizeof(echoCancellation);
    status = AudioUnitSetProperty(audioUnit,
                    kAUVoiceIOProperty_BypassVoiceProcessing,
                    kAudioUnitScope_Global,
                    1,
                    &echoCancellation,
                    size);
    
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error kAUVoiceIOProperty_BypassVoiceProcessing, ret: %d", status);
    }
    
    //kAUVoiceIOProperty_VoiceProcessingEnableAGC
    UInt32 agc = 0;
    status = AudioUnitGetProperty(audioUnit,
                    kAUVoiceIOProperty_VoiceProcessingEnableAGC,
                    kAudioUnitScope_Global,
                    0,
                    &agc,
                    &size);
    
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error kAUVoiceIOProperty_VoiceProcessingEnableAGC, ret: %d", status);
    }
    
    //kAUVoiceIOProperty_MuteOutput
//    agc = 1;
//    status = AudioUnitSetProperty(audioUnit,
//                    kAUVoiceIOProperty_MuteOutput,
//                    kAudioUnitScope_Global,
//                    1,
//                    &agc,
//                    4);
//
//    if (status != noErr) {
//        NSLog(@"AudioUnitGetProperty error kAUVoiceIOProperty_MuteOutput, ret: %d", status);
//    }
}

- (void)startCapture{
    OSStatus status = noErr;
    {// 录制PCM
        // numberBuffers代表录制的声道数
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
        AudioStreamBasicDescription outputFormat;
        outputFormat.mSampleRate = sampleRate;
        outputFormat.mFormatID = kAudioFormatLinearPCM;
        outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
        outputFormat.mFramesPerPacket = 1;
        outputFormat.mChannelsPerFrame = numberBuffers;
        outputFormat.mBytesPerPacket = 2;
        outputFormat.mBytesPerFrame = 2;
        outputFormat.mBitsPerChannel = 16;
        
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      INPUT_BUS,
                                      &outputFormat,
                                      sizeof(outputFormat));
        // set callback. inputCallback: 是采集的回掉
        AURenderCallbackStruct recordCallback;
        recordCallback.inputProc = RecordCallback;
        recordCallback.inputProcRefCon = (__bridge void *)self;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Output,
                                      INPUT_BUS,
                                      &recordCallback,
                                      sizeof(recordCallback));
    }
    AudioUnitInitialize(audioUnit);
    AudioOutputUnitStart(audioUnit);
    
    [AudioCaptureOrPlay setAudioSessionLouderSpeaker];
}

- (void)startPlay{
    OSStatus status = noErr;
    {// 播放
        // set format
        AudioStreamBasicDescription inputFormat;
        inputFormat.mSampleRate = sampleRate;
        inputFormat.mFormatID = kAudioFormatLinearPCM;
        //双声道需要添加 kAudioFormatFlagIsNonInterleaved 这个 flags。
        /*
         这个就是bufferlist[1]什么时候用到的解释
         双声道需要添加 kAudioFormatFlagIsNonInterleaved 这个 flags。如果是这个值，则需要用到bufferlist[1]
                 inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;

         如果只想用buffer[0]，那么就用packed的方式。然后双声道数据交错放进去
         kLinearPCMFormatFlagIsPacked
         **/
        inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
        inputFormat.mFramesPerPacket = 1;
        inputFormat.mChannelsPerFrame = numberBuffers; //双声道，设置为2。playCallback中的 ioData bufferDataList才有两个声道。
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
        
        //render callback是播放的回调用。
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
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result %d", result);
    
    AudioOutputUnitStart(audioUnit);
    
    [AudioCaptureOrPlay setAudioSessionLouderSpeaker2];
}

#pragma mark - callback

static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    AudioCaptureOrPlay *vc = (__bridge AudioCaptureOrPlay *)inRefCon;
    
    
    AudioBuffer buffer;
    buffer.mData = NULL;
    buffer.mDataByteSize = 0;
    buffer.mNumberChannels = 1;
    
    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0] = buffer;
    //把数据写入buffList。
    OSStatus status = AudioUnitRender(vc->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &buffers);
    if (status != noErr) {
        NSLog(@"AudioUnitRender error:%d", status);
    }
    
    [vc.audioDelegate captureData:buffers.mBuffers[0].mData size:buffers.mBuffers[0].mDataByteSize];
    return noErr;
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    AudioCaptureOrPlay *vc = (__bridge AudioCaptureOrPlay *)inRefCon;
    
    [vc.audioDelegate playAudioData:ioData->mBuffers[0].mData size:ioData->mBuffers[0].mDataByteSize];
    
//    static Float64 lastTime = 0;
//    NSLog(@"ioActionFlags：%d inTimeStamp:%f inBusNumber:%d inNumberFrames:%d size1 = %d", *ioActionFlags, inTimeStamp->mSampleTime - lastTime, inBusNumber , inNumberFrames, ioData->mBuffers[0].mDataByteSize);
//    lastTime = inTimeStamp->mSampleTime;
    //NSLog(@"dataSize:%d",ioData->mBuffers[0].mDataByteSize);
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



#pragma mark - Notifications

- (void)handleInterruptionNotificationYYAudio:(NSNotification *)notification
{
  NSNumber *typeNumber =
      notification.userInfo[AVAudioSessionInterruptionTypeKey];
  AVAudioSessionInterruptionType type =
      (AVAudioSessionInterruptionType)typeNumber.unsignedIntegerValue;
  switch (type) {
    case AVAudioSessionInterruptionTypeBegan:
          NSLog(@"AudioCapture: inter began");
      {
          AudioOutputUnitStop(audioUnit);
//          AudioComponentInstanceDispose(audioUnit);
      }
      break;
    case AVAudioSessionInterruptionTypeEnded: {
      //[self updateAudioSessionAfterEvent];
      NSNumber *optionsNumber =
          notification.userInfo[AVAudioSessionInterruptionOptionKey];
      AVAudioSessionInterruptionOptions options =
          optionsNumber.unsignedIntegerValue;
      BOOL shouldResume =
          options & AVAudioSessionInterruptionOptionShouldResume;
      NSLog(@"AudioSeesion CallBack interrupt end, shouldResume %d.", shouldResume);
        
        AudioOutputUnitStart(audioUnit);
        
      break;
    }
  }
}

- (void)handleRouteChangeNotificationYYAudio:(NSNotification *)notification
{
  // Get reason for current route change.
  NSNumber *reasonNumber =
      notification.userInfo[AVAudioSessionRouteChangeReasonKey];
  AVAudioSessionRouteChangeReason reason =
      (AVAudioSessionRouteChangeReason)reasonNumber.unsignedIntegerValue;
  NSLog(@"Audio route changed:");
  switch (reason) {
    case AVAudioSessionRouteChangeReasonUnknown:
      NSLog(@"Audio route changed: ReasonUnknown");
      break;
    case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
      NSLog(@"Audio route changed: NewDeviceAvailable");
      break;
    case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
      NSLog(@"Audio route changed: OldDeviceUnavailable");
      break;
    case AVAudioSessionRouteChangeReasonCategoryChange:
      NSLog(@"Audio route changed: CategoryChange to :%@",
             session.category);
      break;
    case AVAudioSessionRouteChangeReasonOverride:
      NSLog(@"Audio route changed: Override");
      break;
    case AVAudioSessionRouteChangeReasonWakeFromSleep:
      NSLog(@"Audio route changed: WakeFromSleep");
      break;
    case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
      NSLog(@"Audio route changed: NoSuitableRouteForCategory");
      break;
    case AVAudioSessionRouteChangeReasonRouteConfigurationChange:
      NSLog(@"Audio route changed: RouteConfigurationChange");
      break;
  }
  AVAudioSessionRouteDescription *previousRoute =
      notification.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
  // Log previous route configuration.
  NSLog(@"Previous route: %@\nCurrent route:%@",
         previousRoute, session.currentRoute);
//  [self notifyDidChangeRouteWithReason:reason previousRoute:previousRoute];
}

- (void)handleMediaServicesWereLostYYAudio:(NSNotification *)notification
{
  NSLog(@"Media services were lost.");
  //[self updateAudioSessionAfterEvent];
//  [self notifyMediaServicesWereLost];
}

- (void)handleMediaServicesWereResetYYAudio:(NSNotification *)notification
{
  NSLog(@"Media services were reset.");
  //[self updateAudioSessionAfterEvent];
//  [self notifyMediaServicesWereReset];
}

- (void)handleApplicationWillEnterForegroundYYAudio:(UIApplication *)application
{
    NSLog(@"Audio will enter foreground");
//    [self notifyApplicationWillEnterForegroundYYAudio];
}

- (void)handleApplicationWillEnterBackgroundYYAudio:(UIApplication *)application
{
    NSLog(@"Audio did enter background");
//    [self notifyApplicationWillEnterBackgroundYYAudio];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //echo cancellation open
//        UInt32 echoCancellation = 1;
//        UInt32 size = sizeof(echoCancellation);
//        int status = AudioUnitSetProperty(self->audioUnit,
//                        kAUVoiceIOProperty_BypassVoiceProcessing,
//                        kAudioUnitScope_Global,
//                        1,
//                        &echoCancellation,
//                        size);
//
//        if (status != noErr) {
//            NSLog(@"AudioUnitGetProperty error kAUVoiceIOProperty_BypassVoiceProcessing, ret: %d", status);
//        }else{
//            NSLog(@"Audio close echo");
//        }
        
        [self startCapture];
    });
}

- (void)handleSilenceSecondaryAudioHintNotificationYYAudio:(NSNotification *)notification
{
    NSNumber *typeNumber =
      notification.userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey];
  AVAudioSessionSilenceSecondaryAudioHintType type =
      (AVAudioSessionSilenceSecondaryAudioHintType)typeNumber.unsignedIntegerValue;
  switch (type) {
    case AVAudioSessionSilenceSecondaryAudioHintTypeBegin:
      break;
    case AVAudioSessionSilenceSecondaryAudioHintTypeEnd:
      break;
  }
}


@end
