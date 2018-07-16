//
//  YUVFileTransform.h
//  SimpleCapture
//
//  Created by JFChen on 2017/3/31.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>

typedef struct _VTSourceFrameFlags
{
    bool eos;
    bool bos;
    uint32_t pts;
    void * outdata;
    
} VTSourceFrameFlags;

@protocol YUVFileTransformDelegate <NSObject>

- (void)getYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)actuallyBitrate:(int)bitrate frameRate:(int)frameRate;

@end



@interface YUVFileTransform : NSObject
@property(nonatomic, assign) int whDenominator;
@property(nonatomic, assign) int bitrate;

@property(nonatomic, weak) id<YUVFileTransformDelegate> delegate;

- (void)encoderStartWithInputFileName:(NSString *)inputFile;

@end
