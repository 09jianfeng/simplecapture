//
//  ViewController.m
//  SimpleCapture
//
//  Created by Yao Dong on 15/12/5.
//  Copyright © 2015年 duowan. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/UTCoreTypes.h>

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>


#import "VideoViewController.h"
#import "VideoCapture.h"
#import "ViewController.h"
#import	"KXMovieController.h"

@interface ViewController ()
{
    IBOutlet UISegmentedControl *_videoSizeOption;
    IBOutlet UISegmentedControl *_cameraPositionOption;
    
    IBOutlet UILabel *_bitrateLabel;
    IBOutlet UISlider *_bitrateSlider;
    
    IBOutlet UILabel *_fpsLabel;
    IBOutlet UISlider *_fpsSlider;
    
    IBOutlet UISwitch *_videoBeautyFilterSwitch;
    IBOutlet UISwitch *_stabilizationSwitch;
}
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _cameraPositionOption.selectedSegmentIndex = 0;
    
    _bitrateSlider.minimumValue = 1;
    _bitrateSlider.maximumValue = 60;
    _bitrateSlider.value = 6;
    
    _fpsSlider.minimumValue = 10;
    _fpsSlider.maximumValue = 60;
    _fpsSlider.value = 24;
    
    _videoBeautyFilterSwitch.on = YES;
    _stabilizationSwitch.on = NO;
    
    [self updateControlStatus];
}

- (void) updateControlStatus
{
    _bitrateLabel.text = [NSString stringWithFormat:@"Bitrate: %d kbps",
                          (int)_bitrateSlider.value * 100];
    
    _fpsLabel.text = [NSString stringWithFormat:@"FrameRate: %d fps",
                      (int)_fpsSlider.value];
    
    if(_cameraPositionOption.selectedSegmentIndex == 0) {
        if(_videoSizeOption.selectedSegmentIndex == 0) {
            _videoSizeOption.selectedSegmentIndex = 1;
        }
        [_videoSizeOption setEnabled:NO forSegmentAtIndex:0];
    } else {
        [_videoSizeOption setEnabled:YES forSegmentAtIndex:0];
    }
}

- (IBAction)onCameraPositionChanged:(id)sender
{
    [self updateControlStatus];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)onBitrateValueChanged:(id)sender
{
    [self updateControlStatus];
}

- (IBAction)onFpsValueChanged:(id)sender
{
    [self updateControlStatus];
}

- (IBAction)btnVideoPlayerPressed:(id)sender {
    
}
- (IBAction)kxmoviePlayBtnPressed:(id)sender {
    KXMovieController *kxmov = [KXMovieController new];
    [self presentViewController:kxmov animated:YES completion:nil];
}

-(IBAction)onStartVideoCaptureClicked:(id)sender
{
    VideoConfig config;
    config.cameraPosition = (int)_cameraPositionOption.selectedSegmentIndex;
    config.orientation = VideoOrientationPortrait;
    config.preset = (VideoCaptureSizePreset)_videoSizeOption.selectedSegmentIndex;
    config.bitrateInKbps = (int)_bitrateSlider.value * 100;
    config.frameRate = (int)_fpsSlider.value;
    config.enableBeautyFilter = _videoBeautyFilterSwitch.on;
    config.devicePixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    config.outputPixelFormatType = kCVPixelFormatType_32BGRA;
    config.enableStabilization = _stabilizationSwitch.on;

    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    VideoViewController *vc = [sb instantiateViewControllerWithIdentifier:@"VideoViewController"];
    [vc setConfig:config];
 
    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction)onSystemCameraClicked:(id)sender {
    UIImagePickerController *imgPicker = [[UIImagePickerController alloc] init];
    imgPicker.delegate = self;
    imgPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    imgPicker.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeMovie, nil];
    imgPicker.allowsEditing = NO;
    imgPicker.videoQuality = UIImagePickerControllerQualityTypeIFrame1280x720;
    imgPicker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    
    [self presentViewController:imgPicker animated:YES completion:nil];
}

@end
