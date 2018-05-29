//
//  AudioCapture.m
//  YYAudioDemo
//
//  Created by JFChen on 2018/5/8.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import "AudioCaptureSampleBuffer.h"
#import "AACEncoder.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface AudioCaptureSampleBuffer()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
@property (nonatomic , strong) AVCaptureSession *mCaptureSession; //负责输入和输出设备之间的数据传递
@property (nonatomic , strong) AVCaptureDeviceInput *mCaptureAudioDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (nonatomic , strong) AVCaptureAudioDataOutput *mCaptureAudioOutput;
@property (nonatomic , strong) AACEncoder *mAudioEncoder;
@end

@implementation AudioCaptureSampleBuffer{
    int frameID;
    dispatch_queue_t mCaptureQueue;
    dispatch_queue_t mEncodeQueue;
    VTCompressionSessionRef EncodingSession;
    CMFormatDescriptionRef  format;
    NSFileHandle *fileHandle;
    NSFileHandle *audioFileHandle;
}

- (void)startCapture{
    
    self.mAudioEncoder = [[AACEncoder alloc] init];
    
    self.mCaptureSession = [[AVCaptureSession alloc] init];
    self.mCaptureSession.sessionPreset = AVCaptureSessionPreset640x480;
    
    mCaptureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    mEncodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    AVCaptureDevice *inputCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == AVCaptureDevicePositionBack)
        {
            inputCamera = device;
        }
    }
    
    AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] lastObject];
    self.mCaptureAudioDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:nil];
    if ([self.mCaptureSession canAddInput:self.mCaptureAudioDeviceInput]) {
        [self.mCaptureSession addInput:self.mCaptureAudioDeviceInput];
    }
    self.mCaptureAudioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    if ([self.mCaptureSession canAddOutput:self.mCaptureAudioOutput]) {
        [self.mCaptureSession addOutput:self.mCaptureAudioOutput];
    }
    [self.mCaptureAudioOutput setSampleBufferDelegate:self queue:mCaptureQueue];
    
    
    NSString *audioFile = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.aac"];
    [[NSFileManager defaultManager] removeItemAtPath:audioFile error:nil];
    [[NSFileManager defaultManager] createFileAtPath:audioFile contents:nil attributes:nil];
    audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:audioFile];
    
    
    [self.mCaptureSession startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (captureOutput == self.mCaptureAudioOutput) {
        [self.mAudioEncoder encodeSampleBuffer:sampleBuffer completionBlock:^(NSData *encodedData, NSError *error) {
            [audioFileHandle writeData:encodedData];
        }];
    }
    else {
        NSLog(@"video output");
    }
}


@end
