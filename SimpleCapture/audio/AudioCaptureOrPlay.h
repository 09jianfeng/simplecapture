//
//  AudioCaptureOrPlay.h
//  SimpleCapture
//
//  Created by JFChen on 2018/5/25.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AudioCaptureOrPlayDelegate <NSObject>

- (void)captureData:(Byte *)bytes size:(NSUInteger)size;
- (void)playAudioData:(Byte *)bytes size:(NSUInteger)size;
@end

@interface AudioCaptureOrPlay : NSObject
@property(nonatomic, weak) id<AudioCaptureOrPlayDelegate> audioDelegate;

+ (void)setAudioSessionLouderSpeaker;

- (void)stop;

- (void)startCapture;
- (void)startPlay;
@end
