//
//  VideoProcessor.m
//  SimpleCapture
//
//  Created by Yao Dong on 16/2/7.
//  Copyright © 2016年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPUImage.h"
#include "SCCommon.h"
#import "VideoProcessor.h"

@interface FilterListHelper : NSObject
{
    GPUImageOutput *_lastFilter;
}
@property GPUImageOutput *firstFilter;
-(void)appendFilter:(GPUImageOutput*)filter;
-(void)appendTwoFilters:(id<GPUImageInput>)filter1 filter2:(id<GPUImageInput>)filter2;
@end

@implementation FilterListHelper

-(void)appendFilter:(GPUImageFilter *)filter
{
    NSAssert(_firstFilter != nil, @"");

    if(_lastFilter == nil) {
        _lastFilter = self.firstFilter;
    }
    
    [_lastFilter addTarget:filter];
    _lastFilter = filter;
}

-(void)appendTwoFilters:(id<GPUImageInput>)filter1 filter2:(id<GPUImageInput>)filter2
{
    if(_lastFilter) {
        [_lastFilter addTarget:filter1];
        [_lastFilter addTarget:filter2];
    } else {
        NSAssert(FALSE, @"no last filter");
    }
}

@end

@interface VideoProcessor()
{
    id<VideoProcessorDelegate> _processorDelegate;
    dispatch_queue_t _callbackQueue;

    GPUImageFilter *_sourceFilter;
    GPUImageFilter *_swapColorFilter;
    GPUImageBeautyFilter *_beautyFilter;
    GPUImageView *_imageView;
    GPUImageRawDataOutput *_rawDataOutput;
    GPUImageLanczosResamplingFilter *_scaleFilter;
    GPUImageBoxBlurFilter *_blurFilter;
    GPUImageSharpenFilter *_sharpenFilter;
}
@end

NSString *shaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate).bgra;
 }
 );

@implementation VideoProcessor

-(id) initWithSize:(CGSize)size
{
    _imageView = [[GPUImageView alloc] init];
    [_imageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
    
    _swapColorFilter = [[GPUImageFilter alloc] initWithFragmentShaderFromString:shaderString];
    _beautyFilter = [[GPUImageBeautyFilter alloc] init];
    
    _rawDataOutput = [[GPUImageRawDataOutput alloc] initWithImageSize:size resultsInBGRAFormat:YES];
    
    _scaleFilter = [[GPUImageLanczosResamplingFilter alloc] init];
    
    _blurFilter = [[GPUImageBoxBlurFilter alloc] init];
    _blurFilter.blurRadiusInPixels = 1.0;
    
    _sharpenFilter = [[GPUImageSharpenFilter alloc] init];
    _sharpenFilter.sharpness = 1.0;
    
    NSLog(@"Processor init");
    
    return [super init];
}

-(void)buildFilterList:(GPUImageOutput *)firstFilter
{
    if(_enableFlip) {
        [_swapColorFilter setInputRotation:kGPUImageFlipHorizonal atIndex:0];
    }
    
    FilterListHelper *filterHelper = [[FilterListHelper alloc] init];
    filterHelper.firstFilter = firstFilter;
    [filterHelper appendFilter:_swapColorFilter];
    if(_enableBeauty) {
        //[_beautyFilter forceProcessingAtSize:CGSizeMake(640, 1280)];
        [filterHelper appendFilter:_beautyFilter];
    }
    [filterHelper appendTwoFilters:_imageView filter2:_rawDataOutput];
}

-(void)clearFilterList:(GPUImageOutput*)firstFilter
{
    for (GPUImageOutput *filter in firstFilter.targets) {
        if([filter respondsToSelector:@selector(targets)]) {
            [self clearFilterList:filter];
            [filter removeAllTargets];
        }
    }
}

NSString *const gpuYUVFullRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
const GLfloat gpuColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

- (CVOpenGLESTextureRef)activeAndBindTexture:(GLenum)textureUnit imageBuffer:(CVImageBufferRef)imageBuffer textureFormat:(GLint)textureFormat width:(int)width height:(int)height planeIndex:(size_t)planeIndex textureName:(GLuint*)textureName;
{
    CVOpenGLESTextureRef textureRef = NULL;
    glActiveTexture(textureUnit);
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], imageBuffer, NULL, GL_TEXTURE_2D, textureFormat, width, height, textureFormat, GL_UNSIGNED_BYTE, planeIndex, &textureRef);
    
    *textureName = CVOpenGLESTextureGetName(textureRef);
    glBindTexture(GL_TEXTURE_2D, *textureName);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    return textureRef;
}

-(CMSampleBufferRef)processBGRASample:(CMSampleBufferRef)sampleBuf
{
    [GPUImageContext useImageProcessingContext];
    
    CVPixelBufferRef imageBuf = CMSampleBufferGetImageBuffer(sampleBuf);
    int imageWidth  = (int)CVPixelBufferGetWidth(imageBuf);
    int imageHeight = (int)CVPixelBufferGetHeight(imageBuf);
    
    GLuint rgbTexture = 0;
    
    CVOpenGLESTextureRef rgb = [self activeAndBindTexture:GL_TEXTURE4 imageBuffer:imageBuf textureFormat:GL_RGBA width:imageWidth height:imageHeight planeIndex:0 textureName:&rgbTexture];
    
    GPUImageTextureInput *textureInput = [[GPUImageTextureInput alloc] initWithTexture:rgbTexture
                                                                                  size:CGSizeMake(imageWidth, imageHeight)];
    
    [self buildFilterList:textureInput];
    
    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuf);
    [textureInput processTextureWithFrameTime:currentTime];
    
    [self clearFilterList:textureInput];
    
    CFRelease(rgb);
    
    CMSampleTimingInfo sampleTiming;
    CMSampleBufferGetSampleTimingInfo(sampleBuf, 0, &sampleTiming);
    CVPixelBufferRef newPixelBuf = [_rawDataOutput getPBFromRenderTarget];

    CMVideoFormatDescriptionRef formatDesc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,
                                                 newPixelBuf,
                                                 &formatDesc);

    CMSampleBufferRef newSampleBuf = NULL;
    OSStatus status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                             newPixelBuf,
                                             formatDesc,
                                             &sampleTiming,
                                             &newSampleBuf);
    
    CHECK_STATUS(status);
    
    CFRelease(sampleBuf);
    
    return newSampleBuf;
}

-(CMSampleBufferRef)process420FSample:(CMSampleBufferRef)sampleBuf
{
    [GPUImageContext useImageProcessingContext];
    
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuf);
    int bufferWidth  = (int)CVPixelBufferGetWidth(imageBuffer);
    int bufferHeight = (int)CVPixelBufferGetHeight(imageBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    GLuint luminanceTexture, chrominanceTexture;
    
    CVOpenGLESTextureRef luminance = [self activeAndBindTexture:GL_TEXTURE4 imageBuffer:imageBuffer textureFormat:GL_LUMINANCE		 width:bufferWidth height:bufferHeight planeIndex:0 textureName:&luminanceTexture];
    CVOpenGLESTextureRef chrominance = [self activeAndBindTexture:GL_TEXTURE5 imageBuffer:imageBuffer textureFormat:GL_LUMINANCE_ALPHA width:bufferWidth/2 height:bufferHeight/2 planeIndex:1 textureName:&chrominanceTexture];
    
    GLProgram *yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];
    
    if (!yuvConversionProgram.initialized) {
        [yuvConversionProgram addAttribute:@"position"];
        [yuvConversionProgram addAttribute:@"inputTextureCoordinate"];
        
        if (![yuvConversionProgram link]) {
            yuvConversionProgram = nil;
        }
    }
    
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    
    yuvConversionPositionAttribute 			= [yuvConversionProgram attributeIndex:@"position"];
    yuvConversionTextureCoordinateAttribute = [yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
    yuvConversionLuminanceTextureUniform 	= [yuvConversionProgram uniformIndex:@"luminanceTexture"];
    yuvConversionChrominanceTextureUniform 	= [yuvConversionProgram uniformIndex:@"chrominanceTexture"];
    yuvConversionMatrixUniform 				= [yuvConversionProgram uniformIndex:@"colorConversionMatrix"];
    
    glEnableVertexAttribArray(yuvConversionPositionAttribute);
    glEnableVertexAttribArray(yuvConversionTextureCoordinateAttribute);
    
    [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
    
    GPUImageFramebufferCache *cache = [GPUImageContext sharedFramebufferCache];
    GPUImageFramebuffer *outputFramebuffer = [cache fetchFramebufferForSize:CGSizeMake(bufferWidth, bufferHeight)
                                                             textureOptions:_sourceFilter.outputTextureOptions
                                                                onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(yuvConversionLuminanceTextureUniform, 4);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(yuvConversionChrominanceTextureUniform, 5);
    
    glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, gpuColorConversion601FullRange);
    
    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [GPUImageFilter textureCoordinatesForRotation:kGPUImageNoRotation]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    [_sourceFilter setInputFramebuffer:outputFramebuffer atIndex:0];
    
    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuf);
    [_sourceFilter newFrameReadyAtTime:currentTime atIndex:0];
    
    CFRelease(luminance);
    CFRelease(chrominance);
    
    [outputFramebuffer unlock];
    
    CFRetain(sampleBuf);
    return sampleBuf;
}

-(void)process:(CMSampleBufferRef)sampleBuffer
{
    dispatch_sync([GPUImageContext sharedContextQueue], ^{
        CMSampleBufferRef newSampleBuf = NULL;
        CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        OSType formatType = CVPixelBufferGetPixelFormatType(imageBuffer);
        if(formatType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            newSampleBuf = [self process420FSample:sampleBuffer];
        } else if(formatType == kCVPixelFormatType_32BGRA) {
            newSampleBuf = [self processBGRASample:sampleBuffer];
        }
        
        dispatch_async(_callbackQueue, ^{
            [_processorDelegate processorOutput:newSampleBuf];
        });
    });
}

-(void)setDelegate:(id<VideoProcessorDelegate>)processorDelegate queue:(dispatch_queue_t)processorCallbackQueue
{
    _processorDelegate = processorDelegate;
    _callbackQueue = processorCallbackQueue;
}

-(UIView*) previewView
{
    //NSLog(@"return image view");
    return _imageView;
}

-(void)dealloc
{
    //NSLog(@"processor dealloc");
}

-(void)stop
{
    _processorDelegate = nil;
    //NSLog(@"Stop processor");
}

@end
