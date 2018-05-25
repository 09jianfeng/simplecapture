//
//  GPUImageYUVConvter.h
//  GPUImage
//
//  Created by ericking on 8/3/15.
//  Copyright (c) 2015 Brad Larson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPUImageContext.h"
#import "GPUImageOutput.h"

@interface GPUImageYUVConvter : GPUImageOutput
{
    BOOL audioEncodingIsFinished, videoEncodingIsFinished;
    
    CADisplayLink *displayLink;
    CMTime previousFrameTime, processingFrameTime;
    CFAbsoluteTime previousActualFrameTime;
    BOOL keepLooping;
    
    GLuint luminanceTexture, chrominanceTexture;
    
    GLProgram *yuvConversionProgram;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    const GLfloat *_preferredConversion;
    
    BOOL isFullYUVRange;
    
    int imageBufferWidth, imageBufferHeight;
}

@property(readwrite, nonatomic) BOOL runBenchmark;
@property (readonly, nonatomic) BOOL videoEncodingIsFinished;


- (void)yuvConversionSetup;
- (void)processYUVFrame:(CMSampleBufferRef)yuvSampleBuffer;
@end