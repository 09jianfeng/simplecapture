//
//  MultiDrawMetalLayer.h
//  yyvideolib
//
//  Created by YYInc on 2017/11/22.
//  Copyright © 2017年 yy. All rights reserved.
//

#if (TARGET_IPHONE_SIMULATOR)
// 在模拟器的情况下
#else

#import <QuartzCore/QuartzCore.h>
#import <VideoToolbox/VideoToolbox.h>
#import "OpenGLContianerDelegate.h"
#import "MetalRenderLayer.h"

@interface MutilVideoViewCoordinateInfo:NSObject

// 以view的左上角为原点，并非屏幕左上角
@property int viewX;
// 以view的左上角为原点，并非屏幕左上角
@property int viewY;
// 客户端不必还是会openglX openglY的值
@property int openglX;
@property int openglY;
@property int width;
@property int height;

// metal 的坐标值
@property float metalX;
@property float metalY;
@property float metalWidth;
@property float metalHeight;
// 从0开始算
@property int index;

-(NSString*) printInfo;
-(BOOL) isTheSame:(MutilVideoViewCoordinateInfo*) info;
+(id) initWithMutilVideoViewCoordinateInfo:(MutilVideoViewCoordinateInfo *)viewCoordinate;
-(void) resetValueWithMutilVideoViewCoordinateInfo:(MutilVideoViewCoordinateInfo *)viewCoordinate;
@end;



@interface MultiDrawMetalLayer : CAMetalLayer<OpenGLContianerDelegate>

- (instancetype)initWithFrame:(CGRect)frame Capacity:(int) capacity;
- (void)setFrame:(CGRect)frame;
- (void)setFillMode:(MetalVideoFillModeType)fillMode;
- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer ViewCoordinate:(MutilVideoViewCoordinateInfo*) viewCoordinate;
-(void) removePixelBufferAtIndex:(int)index;
-(CVPixelBufferRef) pixelBufferAtIndex:(int) index;
-(void)setBackgroudPixelBuffer:(CVPixelBufferRef)bgPixeBuffer ViewCoordinate:(MutilVideoViewCoordinateInfo*)viewCoordinate;



@end

#endif
