//
//  YMCommon.h
//  yymediarecordersdk
//
//  Created by 陈俊明 on 1/4/18.
//  Copyright © 2018 yy.com. All rights reserved.
//

#ifndef YMCommon_h
#define YMCommon_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//完成回调 文件路径数组
typedef void(^YMTinyVideoCompletionArrayBlock)(NSArray<NSString *> *outputPathArray);
//完成回调
typedef void(^YMTinyVideoCompletionBlock)(NSString *outputPath);
//进度回调
typedef void(^YMTinyVideoProgressBlock)(CGFloat progress);
//失败回调
typedef void(^YMTinyVideoFailureBlock)(NSError *error);

typedef NS_ENUM(NSInteger, YMRecordingStatus) {
    YMRecordingStatusIdle = 0,
    YMRecordingStatusStartingRecording,
    YMRecordingStatusRecording,
    YMRecordingStatusPausing,
    YMRecordingStatusStoppingRecording,
    YMRecordingStatusError,
};


typedef NS_ENUM(NSUInteger, YMTinyVideoCaptureModel) {
    YMTinyVideoCaptureModel_Normal,
    YMTinyVideoCaptureModel_AR,
};

/**
 * 快慢拍模式
 */
typedef NS_ENUM(NSInteger, YMSpeedMode) {
    YMSpeedModeNormal = 0,                  //正常模式
    YMSpeedModeSlowX2 = 1,                  //慢2倍模式
    YMSpeedModeSlowX3 = 2,                  //慢3倍模式
    YMSpeedModeSlowX4 = 3,                  //慢4倍模式
    YMSpeedModeFastX2 = 4,                  //快2倍模式
    YMSpeedModeFastX3 = 5,                  //快3倍模式
    YMSpeedModeFastX4 = 6,                  //快4倍模式
};

/**
 截图图片格式
 
 YMScreenShotFormatJPG jpg格式
 
 YMScreenShotFormatPNG png格式
 */
typedef NS_ENUM(NSInteger, YMScreenShotFormat) {
    YMScreenShotFormatJPG = 1,
    YMScreenShotFormatPNG = 2,
};


/**
 图片方位信息
 
 参考jpg协议
 */
typedef NS_ENUM(NSInteger,YMTinyVideoImageOrientation)
{
    YMTinyVideoImageOrientation_up = 1,
    YMTinyVideoImageOrientation_left = 6,
    YMTinyVideoImageOrientation_down = 3,
    YMTinyVideoImageOrientation_right = 8,
};


/**
 聚焦和曝光模式
 
 YMFocusExposeNormalMode    有人脸对焦到人脸，没有人脸对焦到屏幕中心
 
 YMFocusExposeFaceMode      在Normal模式下不响应点击聚焦
 
 YMFocusExposeGlobalMode    测光默认状态，在中心点自动对焦
 */
typedef NS_ENUM(NSInteger, YMFocusExposeMode) {
    YMFocusExposeNormalMode = 0,
    YMFocusExposeFaceMode = 1,
    YMFocusExposeGlobalMode = 2,
};

// 限定小于3s的视频,不能有转场
#define YM_TINYVIDEO_MIN_TRANSITION_VIDEO_DURATION 3

/**
 * 转场动画类型
 */
typedef NS_ENUM(NSUInteger, YMTinyVideoTransitionType) {
    YM_TINYVIDEO_TRANSITION_NONE,
    YM_TINYVIDEO_TRANSITION_FADE,
    YM_TINYVIDEO_TRANSITION_FOLD,
    YM_TINYVIDEO_TRANSITION_WAVEGRAFFITI,
    YM_TINYVIDEO_TRANSITION_CROSSWARP,
    YM_TINYVIDEO_TRANSITION_RADIAL,
    YM_TINYVIDEO_TRANSITION_PINWHEEL,
    YM_TINYVIDEO_TRANSITION_CROSSZOOM,
    YM_TINYVIDEO_TRANSITION_CROSSROLL,
    YM_TINYVIDEO_TRANSITION_PIXELIZE,
    YM_TINYVIDEO_TRANSITION_WINSWITCH,
    YM_TINYVIDEO_TRANSITION_MAX,
};

typedef NS_ENUM(NSInteger, YMTinyVideoExposureMode){
    YMTinyVideoExposureModeAuto = 0,
    YMTinyVideoExposureModePoint = 1,
    YMTinyVideoExposureModeLock = 2,
};


typedef NS_ENUM(NSInteger ,YMRRotateMode) {
    // 顺时针方向，protrait位置为原始位置
    YMRRotateMode0,
    YMRRotateMode90,
    YMRRotateMode180,
    YMRRotateMode270,
    YMRRotateModeFlipHorizontal0,
    YMRRotateModeFlipVertical0,
};

typedef NS_ENUM(NSInteger, YMROrientation) {
    YMR_ORIENTATION_UP,
    YMR_ORIENTATION_DOWN,
    YMR_ORIENTATION_LEFT,
    YMR_ORIENTATION_RIGHT,
    YMR_ORIENTATION_NOTFOUND
};


#endif /* YMCommon_h */
