//
//  PixelBufferConvertTool.h
//  yyvideolib
//
//  Created by YYInc on 2017/11/25.
//  Copyright © 2017年 yy. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <time.h>
#include <sys/time.h>

typedef NS_ENUM(NSInteger, YVLVideoPixelFormat) {
    kVLVideoPixelFormat_I420,
    kVLVideoPixelFormat_BGRA,
    kVLVideoPixelFormat_NV12,
};

typedef NS_ENUM(NSInteger, YVLVideoPixelRotation) {
    kVLVideoPixelRotate_ClockWise0,
    kVLVideoPixelRotate_ClockWise90,
    kVLVideoPixelRotate_ClockWise180,
    kVLVideoPixelRotate_ClockWise270,
};

@interface PixelBufferConvertTool : NSObject
+ (CVPixelBufferRef) imageToYUVPixelBuffer:(UIImage *)image;


/**
 顺时针旋转pixelBuffer

 @param pixelBuffer src Pixelbuffer
 @param rotation YVLVideoPixelRotation 顺时针旋转角度 0，90，180，270四个角度
 @return 角度为0时，返回pixelBuffer本身。使用其它角度，将返回新创建的CVPixelBuffer
 */
- (CVPixelBufferRef) rotatePixelBufferOfBGRA8888:(CVPixelBufferRef) pixelBuffer Rotation:(YVLVideoPixelRotation) rotation;


/**
 将内存中的数据转换成CVPixelBufferRef

 @param buffer Rawdata数据
 @param format YVLVideoPixelFormat .I420 or NV12 or BGRA
 @param width RawData所指向的图像内容的宽度
 @param height RawData所指向的图像内容的高度
 @return 返回的CVPixelBuffer.不再使用时需要调用CVPixelBufferRelease释放
 */
- (CVPixelBufferRef) createPixelBuffer:(uint8_t*)buffer BufferFormat:(YVLVideoPixelFormat)format Width:(int)width Height:(int)height;
@end
