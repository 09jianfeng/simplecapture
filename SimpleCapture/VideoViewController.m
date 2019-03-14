//
//  VideoViewController.m
//  SimpleCapture
//
//  Created by Yao Dong on 16/1/24.
//  Copyright © 2016年 duowan. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>

#import "VideoViewController.h"
#import "VideoCapture.h"
#import "AudioCapture.h"

@interface VideoViewController ()
{
    IBOutlet UILabel *_statusLabel;
    IBOutlet UISegmentedControl *_segmentedControl;
    IBOutlet UILabel *_bitrateLabel;
    IBOutlet UIStepper *_bitrateStepper;
    
    VideoConfig _config;
    VideoCapture *_videoCapture;
    AudioCapture *_audioCapture;
    NSTimer *_statusTimer;
}
@end

@implementation VideoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _statusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(onStatusTimeout:) userInfo:nil repeats:YES];
    _bitrateLabel.text = [NSString stringWithFormat:@"%d kbps", _config.bitrateInKbps];
    _bitrateStepper.minimumValue = 50;
    _bitrateStepper.maximumValue = _config.bitrateInKbps * 2;
    _bitrateStepper.stepValue = 50;
    _bitrateStepper.value = _config.bitrateInKbps;
    
    _audioCapture = [[AudioCapture alloc] init];
    [_audioCapture start];
    
    _videoCapture = [[VideoCapture alloc] init];
    [_videoCapture setConfig:_config];
    
    [_videoCapture start];
    
    _videoCapture.capturePreviewLayer.frame = self.view.frame;
    [self.view.layer insertSublayer:_videoCapture.capturePreviewLayer atIndex:0];

    _videoCapture.playbackLayer.frame = self.view.frame;
    [self.view.layer insertSublayer: _videoCapture.playbackLayer atIndex:0];
    
    CGRect rc = self.view.frame;
    _videoCapture.processorPreviewView.frame = rc;
    [self.view addSubview:_videoCapture.processorPreviewView];
    [self.view sendSubviewToBack:_videoCapture.processorPreviewView];

    _segmentedControl.selectedSegmentIndex = 1;
    [self onSegmentedControlClicked:nil];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gestureTap:)];
    [self.view addGestureRecognizer:tapGesture];
}

- (void)gestureTap:(UITapGestureRecognizer *)gesture{
    CGPoint position = [gesture locationInView:self.view];
    NSLog(@"tap position %@",NSStringFromCGPoint(position));
    [_videoCapture setTapPosition:position];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    NSLog(@"video view disappear!");
}

-(void)setConfig:(VideoConfig)config
{
    _config = config;
}

- (void)onStatusTimeout:(NSTimer*)theTimer
{
    _statusLabel.text = [NSString stringWithFormat:@"Bitrate:%d kbps, FPS:%d", _videoCapture.actuallyBitrate / 1000, _videoCapture.actuallyFps];
}

- (IBAction)onBitrateChanged:(id)sender
{
    _bitrateLabel.text = [NSString stringWithFormat:@"%d kbps", (int)_bitrateStepper.value];    
    [_videoCapture setTargetBitrate:(int)_bitrateStepper.value];
}

- (IBAction)onSegmentedControlClicked:(id)sender
{
    switch (_segmentedControl.selectedSegmentIndex) {
        case 0:
            _videoCapture.capturePreviewLayer.hidden = NO;
            _videoCapture.processorPreviewView.hidden = YES;
            _videoCapture.playbackLayer.hidden = YES;
            break;
        case 1:
            _videoCapture.capturePreviewLayer.hidden = YES;
            _videoCapture.processorPreviewView.hidden = NO;
            _videoCapture.playbackLayer.hidden = YES;
            break;
        case 2:
            _videoCapture.capturePreviewLayer.hidden = YES;
            _videoCapture.processorPreviewView.hidden = YES;
            _videoCapture.playbackLayer.hidden = NO;
            break;
            
        default:
            break;
    }
}

- (IBAction)onInfo:(id)sender
{
    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Video Info"
                                                         message:_videoCapture.videoInfo
                                                        delegate:nil
                                               cancelButtonTitle:@"Close"
                                               otherButtonTitles:nil];
    [errorAlert show];
}

-(IBAction)onClose:(id)sender
{
    [_audioCapture stop];
    [_videoCapture stop];
    [_videoCapture.processorPreviewView removeFromSuperview];
    [_videoCapture.capturePreviewLayer removeFromSuperlayer];
    [_videoCapture.playbackLayer removeFromSuperlayer];

    [_statusTimer invalidate];
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)dealloc
{
    NSLog(@"video view dealloc");
    _videoCapture = nil;
}

@end
