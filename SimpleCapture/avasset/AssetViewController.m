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

typedef void (^YMTinyVideoTranscodeCompleteBlock)(void);
typedef void (^YMTinyVideoTranscodeProgressBlock)(CGFloat progress);
typedef void (^YMTinyVideoTranscodeFailureBlock)(NSError * err);

@interface AssetViewController ()
@property (nonatomic, copy) YMTinyVideoTranscodeProgressBlock progressBlock;
@property (nonatomic, copy) YMTinyVideoTranscodeCompleteBlock completeBlock;
@property (nonatomic, copy) YMTinyVideoTranscodeFailureBlock failureBlock;
@property (weak, nonatomic) IBOutlet UILabel *labelProgress;
@property (weak, nonatomic) IBOutlet UILabel *labelTimeCost;
@property (weak, nonatomic) IBOutlet UILabel *labelVTProgress;
@property (weak, nonatomic) IBOutlet UILabel *labelVTCost;
@end

@implementation AssetViewController{
    AVAssetDecodeEncode* _encoder;
    int _beginTime;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    YMTinyVideoTranscodeCompleteBlock compleBlock = ^{
        
        int now = [[[NSDate alloc] init] timeIntervalSince1970];
        NSLog(@"____ complete");
        dispatch_async(dispatch_get_main_queue(), ^{
            _labelTimeCost.text = [NSString stringWithFormat:@"%ds",now - _beginTime];
        });
    };
    
    YMTinyVideoTranscodeProgressBlock progress = ^(CGFloat progress){
        NSLog(@"____ progress %f",progress);
        dispatch_async(dispatch_get_main_queue(), ^{
            _labelProgress.text = [NSString stringWithFormat:@"%f",progress];
        });
    };
    
    YMTinyVideoTranscodeFailureBlock failture = ^(NSError * err){
        NSLog(@"____ failture %@",err);
    };

    self.completeBlock = compleBlock;
    self.progressBlock = progress;
    self.failureBlock = failture;
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
    int timeIntel = [[[NSDate alloc] init] timeIntervalSince1970];
    _encoder.outputURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%d_%@",timeIntel,[url.path lastPathComponent]]]];
    _encoder.shouldOptimizeForNetworkUse = YES;
    
    CMTime startTime = CMTimeMakeWithSeconds(0, _encoder.originAsset.duration.timescale);
    
    int duration = phasset.duration;//这一步非常必须
    CMTime endTime = CMTimeMakeWithSeconds(duration, _encoder.originAsset.duration.timescale);
    
    int width = (int)phasset.pixelWidth;
    int height = (int)phasset.pixelHeight;
    int maxBitrate = 8388608;
    int iframes = 100000;
    int fps = 24;
    
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
    
    [self addObserver];
    
    _beginTime = [[[NSDate alloc] init] timeIntervalSince1970];
    [_encoder exportCropAsynchronouslyWithCompletionHandler:^{
        if (_encoder.status == AVAssetExportSessionStatusCompleted) {
            NSLog(@"Asset Transcode Completed");
            if (_completeBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _completeBlock();
                });
            }
        } else if (_encoder.status == AVAssetExportSessionStatusCancelled) {
            NSLog(@"Asset Transcode Cancelled");
            //} else {
            if (_failureBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _failureBlock(_encoder.error);
                });
            }
            NSLog(@"Asset transcode failed with error: %@", _encoder.error);
        } else if (_encoder.status == AVAssetExportSessionStatusFailed) {
            NSLog(@"Asset Transcode failed");
            if (_failureBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _failureBlock(_encoder.error);
                });
            }
            NSLog(@"Asset transcode failed with error: %@", _encoder.error);
        } else {
            NSLog(@"should not call this status %zi ", _encoder.status);
        }
    } avasset:(AVAsset *)phasset];
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

- (IBAction)btnVideoToolboxPressed:(id)sender {
}

- (void)cancel {
    dispatch_async(dispatch_get_main_queue(), ^{
    	[_encoder cancelExport];
    });
}


#pragma mark - kvo

- (void)addObserver{
    [_encoder addObserver:self forKeyPath:@"progress" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];
}

- (void)removeObserver{
    [_encoder removeObserver:self forKeyPath:@"progress" context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    NSNumber * old = [change objectForKey:NSKeyValueChangeOldKey];
    NSNumber * new = [change objectForKey:NSKeyValueChangeNewKey];
    
    if ([old isEqual:new]) {
        // No change in value - don't bother with any processing.
        return;
    }
    
    if ([keyPath isEqualToString:@"progress"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.progressBlock){
                self.progressBlock(new.floatValue);
            }

        });
    }
}

- (void)dealloc {
    if (_encoder) {
        [self removeObserver];
    }
}
@end
