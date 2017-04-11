//
//  VideoPlayerVC+EvtRe.m
//  SimpleCapture
//
//  Created by JFChen on 17/3/24.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "VideoPlayerVC+EvtRe.h"
#import "YUVFileReader.h"
#include "SCCommon.h"
#include "VideoFileDecoder.h"
#import "FileChooseVC.h"
#import "KVOController.h"
#import "VideoTool.h"
#import "YUVFileTransform.h"

@interface VideoPlayerVC()<YUVFileTransformDelegate>
@end

@implementation VideoPlayerVC (EvtRe)

#pragma mark - btnEvent
- (void)btnPlayVideoPressed:(id)sender{
    /*
    NSString *videoPath = [[NSBundle mainBundle] resourcePath];
    videoPath = [videoPath stringByAppendingString:@"/resource.bundle/video.mp4"];
    [self.decoder decodeVideoWithVideoPath:videoPath];
    */
    
    UILabel *fileNameLab = [self.view viewWithTag:10002];
    [self previewLayerWithFileName:fileNameLab.text];
}

- (void)btnWebSeverStart:(id)sender{
    // Create server
    self.webServer = [[GCDWebDAVServer alloc] initWithUploadDirectory:[YUVFileReader documentPath]];
    [self.webServer start];
    
    UILabel *urlLabel = [self.view viewWithTag:10001];
    urlLabel.text = [NSString stringWithFormat:@"WebDAV URL:%@",self.webServer.serverURL.absoluteString];
    NSLog(@"Visit %@ in your WebDAV client", self.webServer.serverURL);
}

- (void)btnFileChoosed:(id)sender{
    UILabel *fileNameLab = [self.view viewWithTag:10002];
    
    NSArray *dataSource = [YUVFileReader videoFilesPathInOri];
    FileChooseVC *fileVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"FileChooseVC"];
    fileVC.dataSource = dataSource;
    [self presentViewController:fileVC animated:YES completion:nil];
    
    self.kvoController = [FBKVOController controllerWithObserver:self];
    [self.kvoController observe:fileVC keyPath:@"chooseFileName" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew block:^(VideoPlayerVC *clockView, FileChooseVC *clock, NSDictionary *change) {
        
        NSString *fileName = change[NSKeyValueChangeNewKey];
        fileNameLab.text = [NSString stringWithFormat:@"%@",fileName];
        self.yuvfilere = nil;
        self.fileDeco = nil;
    }];
}

- (void)sliderBitChange:(id)sender{
    UISlider *slider = (UISlider *)sender;
    UILabel *label = [self.view viewWithTag:20001];
    label.text = [NSString stringWithFormat:@"%dKB",(int)slider.value];
    self.bitRate = (int)slider.value;
}


- (void)sliderDenomChange:(id)sender{
    UISlider *slider = (UISlider *)sender;
    UILabel *label = [self.view viewWithTag:20002];
    label.text = [NSString stringWithFormat:@"1/%d",(int)slider.value];
    self.whnomen = (int)slider.value;
}

#pragma mark - preview
- (void)previewLayerWithFileName:(NSString *)fileName{
    self.fileHandler = [YUVFileTransform new];
    self.fileHandler.delegate = self;
    self.fileHandler.bitrate = self.bitRate;
    self.fileHandler.whDenominator = self.whnomen;
    [self.fileHandler encoderStartWithInputFileName:fileName];
}

#pragma mark - YUVFileTransformDelegate

- (void)getYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
       self.videoLayer.pixelBuffer = pixelBuffer;
        CVPixelBufferRelease(pixelBuffer);
    });
}

@end
