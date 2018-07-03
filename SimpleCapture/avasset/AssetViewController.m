//
//  AssetViewController.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "AssetViewController.h"
#import "YZYPhotoPicker.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import "VideoItem.h"
#import "AVAssetDecodeEncode.h"

@interface AssetViewController ()

@end

@implementation AssetViewController{
    AVAssetDecodeEncode* _encoder;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)handleVideoWithURL:(NSURL *)url phasset:(PHAsset *)phasset{
    VideoItem *videoItem = [[VideoItem alloc] init];
    videoItem.videoPath = url.path;
    _encoder = [[AVAssetDecodeEncode alloc] initWithVideoItems:@[videoItem] audioItems:nil];
    _encoder.outputFileType = AVFileTypeMPEG4;
    _encoder.outputURL = [NSURL URLWithString:[NSTemporaryDirectory() stringByAppendingPathComponent:[url.path lastPathComponent]]];
    _encoder.shouldOptimizeForNetworkUse = YES;
    
    CMTime startTime = CMTimeMakeWithSeconds(0, _encoder.originAsset.duration.timescale);
    CMTime endTime = CMTimeMakeWithSeconds(0 + phasset.duration, _encoder.originAsset.duration.timescale);
    
    int width = (int)phasset.pixelWidth;
    int height = (int)phasset.pixelHeight;
    int maxBitrate = 3000;
    int iframes = 6;
    int fps = 25;
    
    _encoder.timeRange = CMTimeRangeFromTimeToTime(startTime, endTime);
    _encoder.outputSize = CGSizeMake(width, height);
    _encoder.cropRect = CGRectMake(0, 0, width, height);
    _encoder.rotateAngle = 0;
    _encoder.videoSettings = @{
                               AVVideoCodecKey: AVVideoCodecH264,
                               AVVideoWidthKey: @(width),
                               AVVideoHeightKey: @(height),
                               AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
                               AVVideoCompressionPropertiesKey: @{
                                       AVVideoAverageBitRateKey: @(maxBitrate),
                                       AVVideoMaxKeyFrameIntervalKey: @(iframes),
                                       AVVideoExpectedSourceFrameRateKey : @(fps),
                                       },
                               };
    
    _encoder.audioSettings = @{
                               AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                               AVNumberOfChannelsKey: @1,
                               AVSampleRateKey: @44100,
                               };
    

}

- (IBAction)seleteVideoBtnPressed:(id)sender {
    YZYPhotoPicker *photoPicker = [[YZYPhotoPicker alloc] init];
    photoPicker.isImgType = NO;
    [photoPicker showPhotoPickerWithController:self maxSelectCount:1 completion:^(NSArray *imageSources, BOOL isImgType) {
        NSInteger i = 0;
        if (isImgType) { // 如果是UIImage
            for (UIImage *img in imageSources) {
                UIImageView *imgView = [[UIImageView alloc] initWithFrame: CGRectMake(i % 3 * 105, i / 3 * 105, 100, 100)];
                imgView.image = img;
                i ++;
            }
        } else {
            for (id asset in imageSources) {
                PHAsset *phasset = (PHAsset*)asset;
                PHVideoRequestOptions *options = [[PHVideoRequestOptions  alloc] init];
                options.version                = PHImageRequestOptionsVersionCurrent;
                options.deliveryMode           = PHVideoRequestOptionsDeliveryModeAutomatic;
                
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                PHImageManager        *manager = [PHImageManager defaultManager];
                [manager requestAVAssetForVideo:phasset
                                        options:options
                                  resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info)
                 {
                     AVURLAsset *avurl = (AVURLAsset*)asset;
                     if (avurl) {
                         NSLog(@"%s url:%@",__FUNCTION__, avurl.URL);
                     }
                     [self handleVideoWithURL:avurl.URL phasset:phasset];
                     dispatch_semaphore_signal(semaphore);
                 }];
                
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            }
        }
    }];
}

@end
