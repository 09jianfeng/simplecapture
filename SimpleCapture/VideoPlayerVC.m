//
//  VideoPlayerVC.m
//  SimpleCapture
//
//  Created by JFChen on 17/3/22.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "VideoPlayerVC.h"
#import "Masonry.h"
#import <PhotosUI/PhotosUI.h>
#import "VideoPlayerVC+EvtRe.h"

@interface VideoPlayerVC () <VideoFileDecoderDelegate>
@end

@implementation VideoPlayerVC

- (void)dealloc{
    [_decoder invalidDecoder];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self controllerSetting];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self controllerSetting];
    }
    return self;
}

- (void)controllerSetting{
    _decoder = [VideoFileDecoder new];
    _decoder.delegate = self;
}

- (void)awakeFromNib{
    [super awakeFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addVideoSubView];
}

- (void)addVideoSubView{
    _videoView = [UIView new];
    _videoView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_videoView];
    [_videoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.view);
        make.top.mas_equalTo(self.view.mas_top).mas_offset(50);
        make.width.mas_equalTo(self.view).multipliedBy(0.8);
        make.height.mas_equalTo(self.view).multipliedBy(0.3);
    }];
    
    _videoLayer = [[AAPLEAGLLayer alloc] initWithFrame:CGRectZero];
    [_videoView.layer addSublayer:_videoLayer];
    
    UIButton *chooseFileBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.view addSubview:chooseFileBtn];
    [chooseFileBtn addTarget:self action:@selector(btnFileChoosed:) forControlEvents:UIControlEventTouchUpInside];
    [chooseFileBtn setTitle:@"选择文件" forState:UIControlStateNormal];
    [chooseFileBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(100);
        make.height.mas_equalTo(50);
        make.left.equalTo(self.view).offset(20);
        make.top.equalTo(_videoView.mas_bottom).offset(20);
    }];
    
    UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.view addSubview:playBtn];
    [playBtn setTitle:@"开始编码解码" forState:UIControlStateNormal];
    [playBtn addTarget:self action:@selector(btnPlayVideoPressed:) forControlEvents:UIControlEventTouchUpInside];
    [playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(100);
        make.height.mas_equalTo(50);
        make.right.equalTo(self.view).mas_offset(-30);
        make.top.equalTo(_videoView.mas_bottom).offset(20);
    }];
    
    UILabel *fileNameLabel = [UILabel new];
    fileNameLabel.numberOfLines = 2;
    fileNameLabel.lineBreakMode = NSLineBreakByCharWrapping;
    fileNameLabel.tag = 10002;
    fileNameLabel.backgroundColor = [UIColor grayColor];
    [self.view addSubview:fileNameLabel];
    [fileNameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(20);
        make.right.equalTo(self.view).offset(-20);
        make.top.equalTo(chooseFileBtn.mas_bottom).offset(20);
        make.height.mas_equalTo(50);
    }];
    
    
    UILabel *sliBitLabel = [UILabel new];
    sliBitLabel.text = @"600kB";
    sliBitLabel.tag = 20001;
    self.bitRate = 600;
    [self.view addSubview:sliBitLabel];
    [sliBitLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(20);
        make.right.equalTo(self.view).offset(20);
        make.height.mas_equalTo(30);
        make.top.equalTo(fileNameLabel.mas_bottom).offset(20);
    }];
    
    UISlider *sliderBitrate = [UISlider new];
    sliderBitrate.minimumValue = 100;
    sliderBitrate.maximumValue = 6000;
    sliderBitrate.value = 600;
    [self.view addSubview:sliderBitrate];
    [sliderBitrate mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(20);
        make.right.equalTo(self.view).offset(-20);
        make.top.equalTo(sliBitLabel.mas_bottom).offset(10);
        make.height.mas_equalTo(20);
    }];
    [sliderBitrate addTarget:self action:@selector(sliderBitChange:) forControlEvents:UIControlEventValueChanged];
    
    UILabel *sliDenomi = [UILabel new];
    sliDenomi.tag = 20002;
    sliDenomi.text = @"1/3";
    self.whnomen = 3;
    [self.view addSubview:sliDenomi];
    [sliDenomi mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(20);
        make.right.equalTo(self.view).offset(20);
        make.height.mas_equalTo(30);
        make.top.equalTo(sliderBitrate).offset(20);
    }];
    
    UISlider *sliderDenominater = [UISlider new];
    sliderDenominater.minimumValue = 1;
    sliderDenominater.maximumValue = 50;
    sliderDenominater.value = 3;
    [self.view addSubview:sliderDenominater];
    [sliderDenominater mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(20);
        make.right.equalTo(self.view).offset(-20);
        make.top.equalTo(sliDenomi.mas_bottom).offset(10);
        make.height.mas_equalTo(20);
    }];
    [sliderDenominater addTarget:self action:@selector(sliderDenomChange:) forControlEvents:UIControlEventValueChanged];
    
    UIButton *webSeverBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.view addSubview:webSeverBtn];
    [webSeverBtn setTitle:@"开启http服务" forState:UIControlStateNormal];
    [webSeverBtn addTarget:self action:@selector(btnWebSeverStart:) forControlEvents:UIControlEventTouchUpInside];
    [webSeverBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(100);
        make.height.mas_equalTo(50);
        make.left.equalTo(self.view).mas_offset(10);
        make.bottom.equalTo(self.view.mas_bottom).mas_offset(-20);
    }];
    
    UILabel *urlLable = [[UILabel alloc] init];
    urlLable.numberOfLines = 2;
    urlLable.lineBreakMode = NSLineBreakByCharWrapping;
    urlLable.tag = 10001;
    urlLable.backgroundColor = [UIColor grayColor];
    [self.view addSubview:urlLable];
    [urlLable mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(webSeverBtn.mas_right).mas_offset(5);
        make.top.equalTo(webSeverBtn.mas_top);
        make.height.equalTo(webSeverBtn.mas_height);
        make.right.equalTo(self.view.mas_right).mas_offset(-10);
    }];
    
    _labelBitRate = [[UILabel alloc] init];
    _labelBitRate.text = @"实际码率:";
    _labelBitRate.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_labelBitRate];
    [_labelBitRate mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view);
        make.bottom.equalTo(webSeverBtn.mas_top);
        make.height.mas_equalTo(50);
        make.width.equalTo(self.view).multipliedBy(0.5);
    }];

    _labelFrameRate = [UILabel new];
    _labelFrameRate.text = @"实际帧率:";
    _labelFrameRate.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_labelFrameRate];
    [_labelFrameRate mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.view);
        make.bottom.equalTo(webSeverBtn.mas_top);
        make.height.mas_equalTo(50);
        make.width.equalTo(self.view).multipliedBy(0.5);
    }];
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    _videoLayer.frame = _videoView.bounds;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - videofiledecoderdelegate

- (void)outPutPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
       _videoLayer.pixelBuffer = pixelBuffer;
        CVPixelBufferRelease(pixelBuffer);
    });
}

#pragma mark - controlevent

- (IBAction)btnClosePressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
