//
//  VideoPlayerVC.h
//  SimpleCapture
//
//  Created by JFChen on 17/3/22.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoFileDecoder.h"
#import "AAPLEAGLLayer.h"
#import "GCDWebDAVServer.h"
#import "YUVFileTransform.h"

@class YUVFileReader;
@class FBKVOController;

@interface VideoPlayerVC : UIViewController

@property(nonatomic, strong) VideoFileDecoder *decoder;
@property(nonatomic, strong) AAPLEAGLLayer *videoLayer;
@property(nonatomic, strong) UIView *videoView;
@property(nonatomic, strong) GCDWebServer* webServer;
@property(nonatomic, strong) YUVFileReader *yuvfilere;
@property(nonatomic, strong) VideoFileDecoder *fileDeco;
@property(nonatomic, strong) FBKVOController *kvoController;
@property(nonatomic, strong) YUVFileTransform *fileHandler;
@property(nonatomic, strong) UILabel *labelBitRate;
@property(nonatomic, strong) UILabel *labelFrameRate;

@property(nonatomic, assign) int bitRate;
@property(nonatomic, assign) int whnomen;
@end
