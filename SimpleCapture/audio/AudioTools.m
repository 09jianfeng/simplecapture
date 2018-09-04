//
//  AudioTools.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/31.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "AudioTools.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioTools

+ (void)setAudioSessionSpeaker{
    BOOL enable = YES;
    
    AVAudioSession* session = [AVAudioSession sharedInstance];
    AVAudioSessionCategoryOptions options = session.categoryOptions;
    
    NSError* error = nil;
    if (enable) {
        options |= AVAudioSessionCategoryOptionDefaultToSpeaker;
        options |= AVAudioSessionCategoryOptionMixWithOthers;
    }
    else {
        options &= ~AVAudioSessionCategoryOptionDefaultToSpeaker;
    }
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:options
                   error:&error];
    if (error) {
        NSLog(@"<error> %@",error);
    }
    
    error = nil;
    [session setMode:AVAudioSessionModeDefault error:&error];
    if (error != nil) {
        NSLog(@"Could not set mode2 %@",error);
    }
}

@end
