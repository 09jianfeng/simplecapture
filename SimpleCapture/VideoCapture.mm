//
//  VideoCapture.m
//  SimpleCapture
//
//  Created by Yao Dong on 16/1/22.
//  Copyright © 2016年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AVFoundation/AVFoundation.h>

#include <vector>

#import "SCCommon.h"
#import "BitrateMonitor.h"
#import "VideoCapture.h"
#import "VideoProcessor.h"
#import "VideoEncoder.h"

//#define ENABLE_SENSETIME_SDK

#ifdef ENABLE_SENSETIME_SDK
#include "../sensetimesdk/include/cv_face.h"

struct FaceDetectInfo
{
    CGRect rect;
    int pointsCount;
    CGPoint points[200];
};

@interface FaceDetectView : UIView
{
    CGContextRef context;
    std::vector<FaceDetectInfo> _faceInfos;
}
-(void)setFaceDetectInfo:(const std::vector<FaceDetectInfo> &) faceInfos;
@end

@implementation FaceDetectView

-(void)setFaceDetectInfo:(const std::vector<FaceDetectInfo> &) faceInfos
{
    _faceInfos = faceInfos;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    if (context) {
        CGContextClearRect(context, self.bounds) ;
    }
    context = UIGraphicsGetCurrentContext();
    
    for (const auto &fdi : _faceInfos) {
        int count = fdi.pointsCount;
        for(int i = 0; i < count; i++) {
            CGContextAddEllipseInRect(context, CGRectMake(fdi.points[i].x - 1 , fdi.points[i].y - 1 , 2 , 2));
        }
        CGContextAddRect(context, fdi.rect) ;
    }
    
    [[UIColor greenColor] set];
    CGContextSetLineWidth(context, 2);
    CGContextStrokePath(context);
}

@end

#endif //ENABLE_SENSETIME_SDK

struct CaptureStat {
    int captureFrameCount;
    int processFrameCount;
    int encodeFrameCount;
    int playFrameCount;
};

@interface VideoCapture ()<
    AVCaptureVideoDataOutputSampleBufferDelegate,
    VideoEncoderDelegate,
    VideoProcessorDelegate>
{
    VideoConfig _config;
    
    NSString *_capturePreset;
    CGSize _videoSize;
    AVCaptureVideoStabilizationMode _stablilizationMode;
    int _targetBitrate;
    
    //capture device
    AVCaptureSession *_captureSession;
    AVCaptureDevice *_videoCaptureDevice;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;

    //capture handler
    dispatch_queue_t _captureQueue;

    //processor handler
    VideoProcessor *_processor;
    dispatch_queue_t _processorQueue;

    //encoder
    VideoEncoder *_encoder;
    dispatch_queue_t _encodingQueue;
    
    //playback
    AVSampleBufferDisplayLayer *_playbackLayer;
    
    //bitrate and fps
    BitrateMonitor _bitrateMonitor;
    
    //background state
    BOOL _isAppInBackground;
    
#ifdef ENABLE_SENSETIME_SDK
    //face detect
    cv_handle_t _faceTracker;
    FaceDetectView *_faceDetectView;
#endif
    
    CaptureStat _stat;
}
@end

@implementation VideoCapture

- (id) init
{
    _captureQueue = dispatch_queue_create("capture queue", DISPATCH_QUEUE_SERIAL);
    _processorQueue = dispatch_queue_create("processor queue", DISPATCH_QUEUE_SERIAL);
    _encodingQueue = dispatch_queue_create("encoder queue", DISPATCH_QUEUE_SERIAL);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onApplicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onApplicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
#ifdef ENABLE_SENSETIME_SDK
    _faceTracker = cv_face_create_tracker_106(NULL, CV_FACE_SKIP_BELOW_THRESHOLD | CV_FACE_RESIZE_IMG_320W | CV_TRACK_MULTI_TRACKING);
    cv_face_track_106_set_detect_face_cnt_limit(_faceTracker, -1);
    
    cv_face_algorithm_info();
#endif
    
    [NSTimer scheduledTimerWithTimeInterval: 5.0
                                     target: self
                                   selector: @selector(onTick:)
                                   userInfo: nil repeats:YES];
    
    return [super init];
}

- (void)onTick:(NSTimer*)timer {
    NSLog(@"CaptureFrame: %d, ProcessFrame: %d, EncodeFrame: %d, PlayFrame: %d",
          _stat.captureFrameCount,
          _stat.processFrameCount,
          _stat.encodeFrameCount,
          _stat.playFrameCount);
}

- (void) setTapPosition:(CGPoint)position{
    
}

- (void)onApplicationWillEnterForeground:(NSNotification *)notification
{
    @synchronized(self) {
        NSLog(@"in forground");
        _isAppInBackground = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self resume];
        });
    }
}

- (void)onApplicationDidEnterBackground:(NSNotification *)notification
{
    @synchronized(self) {
        NSLog(@"in background");
        _isAppInBackground = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pause];
        });
    }
}

- (void) setConfig:(VideoConfig)config
{
    _config = config;

    switch (_config.preset) {
        case VideoCaptureSize1920x1080:
            _capturePreset = AVCaptureSessionPreset1920x1080;
            _videoSize = CGSizeMake(1080, 1920);
            break;
        case VideoCaptureSize1280x720:
            _capturePreset = AVCaptureSessionPreset1280x720;
            _videoSize = CGSizeMake(720, 1280);
            break;
        case VideoCaptureSize640x480:
            _capturePreset = AVCaptureSessionPreset640x480;
            _videoSize = CGSizeMake(480, 640);
            break;
            
        default:
            break;
    }
}

- (void) start
{
    [self startEncoder];
    [self startProcessor];
    [self startCapture];
}

- (void)pause {
    [_captureSession stopRunning];
    
    uint64_t b = GetTickCount64();
    dispatch_sync(_processorQueue, ^{
        [_encoder endEncode];
    });
    NSLog(@"Pause wait for %llu ms", GetTickCount64() - b);
}

- (void)resume {
    [_captureSession startRunning];
    
    uint64_t b = GetTickCount64();
    dispatch_sync(_processorQueue, ^{
        [_encoder beginEncode];
    });
    NSLog(@"Resume wait for %llu ms", GetTickCount64() - b);
}

- (void) stop
{
    [_captureSession stopRunning];
    [_processor stop];
    [_encoder endEncode];
}

- (CALayer *) playbackLayer
{
    return _playbackLayer;
}

- (void)printCaptureFormat:(AVCaptureDeviceFormat*)format
{
    CMVideoDimensions videoSize = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
    NSLog(@"Type %@, v_w: %d, v_h: %d, HDR: %d, Stable: %d maxZoom: %f, SubType: %8.8X",
          format.mediaType,
          videoSize.width,
          videoSize.height,
          format.isVideoHDRSupported,
          [format isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeAuto],
          format.videoMaxZoomFactor,
          (unsigned int)mediaSubType);
    for(AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
        NSLog(@"    minFrameRate: %f, maxFrameRate: %f", range.minFrameRate, range.maxFrameRate);
    }
}

- (AVCaptureDeviceFormat *) chooseBestVideoFormat
{
    AVCaptureDeviceFormat *bestFormat = nil;
    CGFloat requestFrameRate = _config.frameRate;
    CGFloat requestWidth = MAX(_videoSize.width, _videoSize.height);
    CGFloat requestHeight = MIN(_videoSize.width, _videoSize.height);
    
    for (AVCaptureDeviceFormat *vFormat in [_videoCaptureDevice formats]) {
        //[self printCaptureFormat:vFormat];
        
        AVFrameRateRange *range = vFormat.videoSupportedFrameRateRanges.firstObject;
        CMVideoDimensions videoSize = CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription);
        FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(vFormat.formatDescription);
        
        if(requestFrameRate > range.maxFrameRate) {
            continue;
        }
        if(requestWidth > videoSize.width) {
            continue;
        }
        if(requestHeight > videoSize.height) {
            continue;
        }
        if(mediaSubType != _config.devicePixelFormatType) {
            continue;
        }
        
        if(bestFormat == nil) {
            bestFormat = vFormat;
        }
    }
    
    return bestFormat;
}

- (void)printCaptureDeviceInfo:(AVCaptureDevice*)device {
    NSLog(@"hdrMode: %d, lowLight:%d, exposureMode:%d, wbMode:%d",
          (int)device.automaticallyAdjustsVideoHDREnabled,
          (int)device.automaticallyEnablesLowLightBoostWhenAvailable,
          (int)device.exposureMode,
          (int)device.whiteBalanceMode);
}

- (void) startCapture
{
    if(_config.cameraPosition == VideoCameraPositionFront) {
        _videoCaptureDevice = [self cameraWithPosition:AVCaptureDevicePositionFront];
    } else if(_config.cameraPosition == VideoCameraPositionBack) {
        _videoCaptureDevice = [self cameraWithPosition:AVCaptureDevicePositionBack];
    }
 
    //init capture session
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession beginConfiguration];

    NSError *error = nil;
    _captureSession.sessionPreset = _capturePreset;

    _videoInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoCaptureDevice error:&error];
    [_captureSession addInput:_videoInput];
    
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_config.outputPixelFormatType]
                                                               forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [_videoOutput setSampleBufferDelegate:self queue:_captureQueue];
    [_captureSession addOutput:_videoOutput];

    AVCaptureConnection *videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    [_captureSession commitConfiguration];
    
    //config capture device
    [_videoCaptureDevice lockForConfiguration:NULL];

    AVCaptureDeviceFormat *bestFormat = [self chooseBestVideoFormat];
    _videoCaptureDevice.activeFormat = bestFormat;
    _videoCaptureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, _config.frameRate);
    _videoCaptureDevice.activeVideoMinFrameDuration = CMTimeMake(1, _config.frameRate);
    
    [self printCaptureDeviceInfo:_videoCaptureDevice];
    
    if(bestFormat.isVideoHDRSupported) {
        _videoCaptureDevice.automaticallyAdjustsVideoHDREnabled = YES;
    }

    if(_videoCaptureDevice.isLowLightBoostSupported) {
        _videoCaptureDevice.automaticallyEnablesLowLightBoostWhenAvailable = YES;
    }

    if([_videoCaptureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        CGPoint exposurePoint = CGPointMake(0.5f, 0.5f);
        [_videoCaptureDevice setExposurePointOfInterest:exposurePoint];
        [_videoCaptureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }

    if([_videoCaptureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
        [_videoCaptureDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
    }

    [_videoCaptureDevice unlockForConfiguration];

    //config video connection
    if(_config.enableStabilization) {
        if([bestFormat isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeAuto]) {
//            [videoConnection setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeAuto];
            
//            [videoConnection setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeStandard];
            [videoConnection setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeCinematic];
            _stablilizationMode = videoConnection.activeVideoStabilizationMode;
            NSLog(@"kelvin test stabilization %ld",(long)_stablilizationMode);
        }
    }
    
    //init preview and playback layers
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    _capturePreviewLayer = previewLayer;
    
    _playbackLayer = [[AVSampleBufferDisplayLayer alloc] init];
    [_playbackLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];

    [_captureSession startRunning];
}

- (void) startProcessor
{
    _processor = [[VideoProcessor alloc] initWithSize:_videoSize];
    _processor.enableBeauty = _config.enableBeautyFilter;
    _processor.enableFlip = _config.cameraPosition == VideoCameraPositionFront ? YES : NO;
    [_processor setDelegate:self queue:_processorQueue];
    
    _processorPreviewView = _processor.previewView;
    
#ifdef ENABLE_SENSETIME_SDK
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    _faceDetectView = [[FaceDetectView alloc] initWithFrame:screenRect];
    [_processorPreviewView addSubview:_faceDetectView];
    _faceDetectView.backgroundColor = [UIColor clearColor] ;
#endif
}

- (void) startEncoder
{
    _encoder = [[VideoEncoder alloc] init];
    _encoder.videoSize = _videoSize;
    _encoder.frameRate = _config.frameRate;
    _encoder.bitrate = _config.bitrateInKbps;
    _encoder.pixelFormatType = _config.outputPixelFormatType;
    [_encoder setDelegate:self queue:_encodingQueue];
    [_encoder beginEncode];
}

- (void) setTargetBitrate:(int)bitrateInKbps
{
    _targetBitrate = bitrateInKbps;
    [_encoder setTargetBitrate:bitrateInKbps];
}

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

- (CVPixelBufferRef) createPixelBuffer:(size_t)width height:(size_t)height format:(OSType)format
{
    CFMutableDictionaryRef optionsDictionary = CFDictionaryCreateMutable(NULL, 0,
                                                                    &kCFTypeDictionaryKeyCallBacks,
                                                                    &kCFTypeDictionaryValueCallBacks);
    
    Boolean b = YES;
    CFNumberRef num = CFNumberCreate (NULL, kCFNumberSInt32Type, &b);
    CFDictionarySetValue(optionsDictionary, kCVPixelBufferOpenGLESCompatibilityKey, num);
    CFRelease(num);

    NSDictionary *dict = [NSDictionary dictionary];
    CFDictionarySetValue(optionsDictionary, kCVPixelBufferIOSurfacePropertiesKey, (void*)dict);
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn ret = CVPixelBufferCreate(kCFAllocatorDefault,
                                       width,
                                       height,
                                       format, //pixel format, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, etc.
                                       NULL, //optionsDictionary,
                                       &pixelBuffer);
    
    if(ret != kCVReturnSuccess) {
        NSLog(@"Create pixel buffer failed, ret=%d", ret);
    }
    
    return pixelBuffer;
}

- (void) printVideoFrameInfo:(CMSampleBufferRef) sampleBuf
{
    uint8_t *data = NULL;
    CMBlockBufferRef blockbuf = CMSampleBufferGetDataBuffer(sampleBuf);
    OSStatus status = CMBlockBufferGetDataPointer(blockbuf, 0, 0, 0, (char**)&data);
    CHECK_STATUS(status);
    
    size_t blockBufSize = (int)CMBlockBufferGetDataLength(blockbuf);
    
    uint8_t *nal = data;
    do {
        uint32_t nalType = nal[4];
        uint32_t nalSize = nal[0] << 24 | nal[1] << 16 | nal[2] << 8 | nal[3];
        
        const char *nalTypeString = NULL;
        switch (nalType) {
            case 0x06:
                nalTypeString = "SEI";
                break;
            case 0x25:
                nalTypeString = "I";
                break;
            case 0x21:
                nalTypeString = "P";
                break;
            case 0x01:
                nalTypeString = "B";
                break;
                
            default:
                break;
        }
        
        nal += nalSize + 4;
        
        //NSLog(@"FrameType: %s size: %d", nalTypeString, nalSize);
    } while(nal < data + blockBufSize);
}

#ifdef ENABLE_SENSETIME_SDK
-(void) drawFaceInfos:(const std::vector<FaceDetectInfo> *)faceInfos
{
    [_faceDetectView setFaceDetectInfo:*faceInfos];
}

- (void) detectFace:(CMSampleBufferRef) sampleBuffer
{
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    uint8_t *baseAddress = (uint8_t*)CVPixelBufferGetBaseAddress(pixelBuffer);
    
    cv_face_106_t *pFaceRectID = NULL ;
    int iCount = 0;
    
    int iWidth  = (int)CVPixelBufferGetWidth(pixelBuffer);
    int iHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    cv_result_t iRet = CV_OK;
    
    iRet = cv_face_track_106(_faceTracker, baseAddress, CV_PIX_FMT_BGRA8888, iWidth, iHeight, iWidth * 4, CV_FACE_UP, &pFaceRectID, &iCount);
    
    if(1 && iRet == CV_OK && iCount > 0) {
        auto faceInfos = new std::vector<FaceDetectInfo>();
        for(int i = 0; i < iCount; i++) {
            cv_face_106_t rectIDMain = pFaceRectID[i];
            cv_pointf_t *facePoints = rectIDMain.points_array;
            FaceDetectInfo faceInfo;
            CGFloat scale = _faceDetectView.frame.size.height / iHeight;

            for(int i = 0; i < rectIDMain.points_count; i++) {
                faceInfo.points[i].x = (iWidth / 2 - facePoints[i].x) * scale + _faceDetectView.frame.size.width / 2;
                faceInfo.points[i].y = facePoints[i].y * scale;
            }
            faceInfo.pointsCount = rectIDMain.points_count;
            
            faceInfo.rect = CGRectMake((iWidth / 2 - rectIDMain.rect.right) * scale + _faceDetectView.frame.size.width / 2,
                                       rectIDMain.rect.top * scale,
                                       (rectIDMain.rect.right - rectIDMain.rect.left) * scale,
                                       (rectIDMain.rect.bottom - rectIDMain.rect.top) * scale);
            faceInfos->push_back(faceInfo);
            
            //NSLog(@"%d, %d, %d, %d",
              //    rectIDMain.yaw, rectIDMain.pitch, rectIDMain.roll, rectIDMain.eye_dist);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self drawFaceInfos:faceInfos];
            delete faceInfos;
        });
    }
    
    cv_face_release_tracker_106_result(pFaceRectID, iCount);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}
#endif

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    @synchronized(self) {
        if(!_isAppInBackground) {
#ifdef ENABLE_SENSETIME_SDK
            //uint64_t begin = GetTickCount64();
            [self detectFace:sampleBuffer];
            //NSLog(@"Face detect time: %lld", GetTickCount64() - begin);
#endif
            _stat.captureFrameCount++;
            CFRetain(sampleBuffer);
            [_processor process:sampleBuffer];
        }
    }
    
}

- (void) processorOutput:(CMSampleBufferRef)sampleBuf
{
    if(sampleBuf) {
        _stat.processFrameCount++;
        
        [_encoder encode:sampleBuf];
        CFRelease(sampleBuf);
    } else {
        NSLog(@"processor output is nil");
    }
}

- (void) encoderOutput:(CMSampleBufferRef)sampleBuffer frameCont:(FrameContext *)frameCont
{
    _stat.encodeFrameCount++;
    [self printVideoFrameInfo:sampleBuffer];

    if(_playbackLayer.readyForMoreMediaData) {
        CMTime pts = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
        CMTime delay = CMTimeMake(_config.frameRate / 5, _config.frameRate); //play back delay, 4 frames time
        CMTime newPts = CMTimeAdd(pts, delay);
        CMSampleBufferSetOutputPresentationTimeStamp(sampleBuffer, newPts);

        [_playbackLayer enqueueSampleBuffer:sampleBuffer];
        if(_playbackLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            [_playbackLayer flushAndRemoveImage];
        } else {
            _stat.playFrameCount++;
        }
    } else {
        NSLog(@"playback layer not ready!");
    }
    
    size_t sampleSize = CMSampleBufferGetTotalSampleSize(sampleBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        _bitrateMonitor.appendDataSize((int)sampleSize);
        self.actuallyBitrate = _bitrateMonitor.actuallyBitrate();
        self.actuallyFps = _bitrateMonitor.actuallyFps();
    });
}

- (NSString*) videoInfo
{
    NSString *infoString = [NSString stringWithFormat:@"Video Size: %dx%d\nConfig Bitrate: %d kbps\nTarget Bitrate: %d kbps\nFrame rate: %d fps\nLowLightBoost: %@\nHDR: %@\nStabilizationMode: %ld",
                            (int)_videoSize.width,
                            (int)_videoSize.height,
                            _config.bitrateInKbps,
                            _targetBitrate,
                            _config.frameRate,
                            _videoCaptureDevice.isLowLightBoostSupported ? @"ON" : @"OFF",
                            _videoCaptureDevice.isVideoHDREnabled ? @"ON" : @"OFF",
                            (long)_stablilizationMode];
    
    return infoString;
}

-(void) dealloc
{
    NSLog(@"capture dealloc");
#ifdef ENABLE_SENSETIME_SDK
    cv_face_destroy_tracker_106(_faceTracker);
#endif
}


@end
