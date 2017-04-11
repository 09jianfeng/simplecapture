//
//  AudioCapture.m
//  SimpleCapture
//
//  Created by Yao Dong on 16/2/13.
//  Copyright © 2016年 duowan. All rights reserved.
//

#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AudioCapture.h"

@interface AudioCapture ()
{
    AVAudioSession *_audioSession;
    AUGraph _auGraph;
    AudioUnit _remoteIOUnit;
    AUNode _remoteIONode;
}
@end

static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) {
        return;
    }
    
    char str[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else {
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    }
    
    NSLog(@"Error: %s (%s)", operation, str);
}

@implementation AudioCapture

static OSStatus auRenderCallback(void *							inRefCon,
                                 AudioUnitRenderActionFlags *	ioActionFlags,
                                 const AudioTimeStamp *			inTimeStamp,
                                 UInt32							inBusNumber,
                                 UInt32							inNumberFrames,
                                 AudioBufferList * __nullable	ioData)
{
    AudioCapture *p = (__bridge AudioCapture*)inRefCon;
    
    OSStatus renderErr = AudioUnitRender(p->_remoteIOUnit, ioActionFlags,
                                         inTimeStamp, 1, inNumberFrames, ioData);

    return renderErr;
}

- (void) startAudioUnit
{
    _audioSession = [AVAudioSession sharedInstance];
    
    NSError *error = nil;
    // set Category for Play and Record
    [_audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [_audioSession setPreferredSampleRate:(double)_sampleRate error:&error];
    
    //init RemoteIO
    CheckError(NewAUGraph(&_auGraph), "couldn't NewAUGraph");
    CheckError(AUGraphOpen(_auGraph), "couldn't AUGraphOpen");

    //init nodes
    AudioComponentDescription componentDesc;
    componentDesc.componentType = kAudioUnitType_Output;
    componentDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    componentDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    componentDesc.componentFlags = 0;
    componentDesc.componentFlagsMask = 0;
    
    CheckError(AUGraphAddNode(_auGraph, &componentDesc, &_remoteIONode), "couldn't add remote io node");
    CheckError(AUGraphNodeInfo(_auGraph, _remoteIONode,NULL, &_remoteIOUnit), "couldn't get remote io unit from node");
    
    //set BUS
    UInt32 oneFlag = 1;
    UInt32 busZero = 0;
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Output,
                                    busZero,
                                    &oneFlag,
                                    sizeof(oneFlag)),"couldn't kAudioOutputUnitProperty_EnableIO with kAudioUnitScope_Output");

    UInt32 busOne = 1;
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    busOne,
                                    &oneFlag,
                                    sizeof(oneFlag)),"couldn't kAudioOutputUnitProperty_EnableIO with kAudioUnitScope_Input");
    
    //init audio stream desciption
    AudioStreamBasicDescription effectDataFormat;
    UInt32 propSize = sizeof(effectDataFormat);
    CheckError(AudioUnitGetProperty(_remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    0,
                                    &effectDataFormat,
                                    &propSize),"couldn't get kAudioUnitProperty_StreamFormat with kAudioUnitScope_Output");
    
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    1,
                                    &effectDataFormat,
                                    propSize),"couldn't set kAudioUnitProperty_StreamFormat with kAudioUnitScope_Output");
    
    CheckError(AudioUnitSetProperty(_remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    0,
                                    &effectDataFormat,
                                    propSize),"couldn't set kAudioUnitProperty_StreamFormat with kAudioUnitScope_Input");
    
    AURenderCallbackStruct inputProc;
    inputProc.inputProc = auRenderCallback;
    inputProc.inputProcRefCon = (__bridge void *)(self);
    CheckError(AUGraphSetNodeInputCallback(_auGraph, _remoteIONode, 0, &inputProc), "Error setting io output callback");
    //
    CheckError(AUGraphInitialize(_auGraph), "couldn't AUGraphInitialize");
    CheckError(AUGraphUpdate(_auGraph, NULL), "couldn't AUGraphUpdate");
    CheckError(AUGraphStart(_auGraph), "couldn't AUGraphStart");
}

-(void)stopAudioUnit
{
    CheckError(AUGraphStop(_auGraph), "couldn't AUGraphStop");
}

-(id)init
{
    _sampleRate = 44100;
    _isVOIP = NO;
    
    return [super init];
}

-(void) start
{
    [self startAudioUnit];
}

-(void) stop
{
    [self stopAudioUnit];
}

@end
