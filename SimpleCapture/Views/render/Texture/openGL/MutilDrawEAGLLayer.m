//
//  MutilDrawEAGLLayer.m
//  yyvideolib
//
//  Created by JFChen on 2017/11/13.
//  Copyright © 2017年 yy. All rights reserved.
//

#import "MutilDrawEAGLLayer.h"
#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>
#include <AVFoundation/AVFoundation.h>
#import <UIKit/UIScreen.h>
#include <OpenGLES/EAGL.h>
#include <OpenGLES/ES2/gl.h>
#import "MGLCommon.h"
#include <OpenGLES/ES2/glext.h>
#import <UIKit/UIKit.h>
#import <sys/time.h>

// 屏幕的渲染FPS
#define RENDER_RATE 30
#define MAX_CAPACITY 9

// Uniform index.
enum
{
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_ROTATION_ANGLE,
    UNIFORM_RANGEOFFSET,
    
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};


// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
static const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

static const GLfloat kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

static const GLfloat kColorConversion709FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.183, 1.816,
    1.540,    -0.459, 0.0,
};

@interface MutilDrawEAGLLayer ()
{
    // The pixel dimensions of the CAEAGLLayer.
    GLint _backingWidth;
    GLint _backingHeight;
    
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    GLuint _frameBufferHandle;
    GLuint _colorBufferHandle;
    
    const GLfloat *_preferredConversion;
    CGSize normalizedSamplingSize ;
    CGRect  viewFrame;
    GLint uniforms[NUM_UNIFORMS];
    
    BOOL _justInBackground;
    BOOL _justRestored;
    uint32_t _timeRestoreFromBackground;
    BOOL _finishInit;
    
    int _capacity;//index从0开始计算
    VideoFillModeType _fillMode;
    
    CVPixelBufferRef _bgPixelBuf;
    
    CVPixelBufferRef pixelList[MAX_CAPACITY];
    
    MutilVideoViewCoordinateInfo* _bgViewCoordinate;
    
    NSLock* _lockObj;
    
    BOOL _backgroundChanged;
}
@property GLuint program;
@property CADisplayLink *displayLink;
@property NSMutableDictionary *viewCoordinateInfoDictionary;
@property BOOL isStopDisplayLink;
@property int systemVersion;
@property BOOL isInBackground;
@property EAGLContext *openglContext;
@property dispatch_queue_t renderQueue;
@end

@implementation MutilDrawEAGLLayer

- (instancetype)init{
    return [self initWithFrame:CGRectZero Capacity:9];
}

- (id)initWithFrame:(CGRect)frame Capacity:(int) capacity
{
    self = [super init];
    if (self) {
        NSLog(@"create MutilDrawEAGLLayer!");
        CGFloat scale = [[UIScreen mainScreen] scale];
        self.contentsScale = scale;
        self.opaque = YES;
        self.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:YES]};
        
        _renderQueue = dispatch_queue_create("com.yy.yyvideo.MutilDrawEAGLLayer", DISPATCH_QUEUE_SERIAL);
        
        _capacity = capacity;
        _backgroundChanged = NO;
        _isStopDisplayLink = NO;
        _justInBackground = NO;
        _timeRestoreFromBackground = 0;
        _justRestored = NO;
        _displayLink = nil;
        // Set the context into which the frames will be drawn.
        
        [self setFrame:frame];
        
        _lockObj = [[NSLock alloc] init];
        _viewCoordinateInfoDictionary = [[NSMutableDictionary alloc] initWithCapacity:_capacity];
        for (int i = 0; i < _capacity; i++) {
            pixelList[i] = NULL;
        }
        
        // Set the default conversion to BT.601, which is the standard for SDTV.
        _preferredConversion = kColorConversion601;
        _systemVersion = [[[UIDevice currentDevice] systemVersion] intValue];
        
        __weak typeof(self) weakSelf = self;
        dispatch_sync(_renderQueue, ^{
            [weakSelf setupGL];
        });
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerBecomeActiveFromBackground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerWillResignActiveToBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        _finishInit = YES;
    }
    
    return self;
}

- (void)layerBecomeActiveFromBackground:(NSNotification *)sender
{
    [_lockObj lock];
    _isInBackground = NO;
    [self resumeDisplayLink];
    NSLog(@"");
    [_lockObj unlock];
    __weak typeof(self) weakSelf = self;
    dispatch_sync(_renderQueue, ^{
        [weakSelf resetRenderBuffer ];
    });
}

- (void)layerWillResignActiveToBackground:(NSNotification *)sender
{
    [_lockObj lock];
    _isInBackground = YES;
    [self pauseDisplayLink];
    NSLog(@"");
    [_lockObj unlock];
    
}

- (void)layerDidEnterBackground:(NSNotification *)sender
{
    [_lockObj lock];
    _isInBackground = YES;
    [self pauseDisplayLink];
    NSLog(@"");
    [_lockObj unlock];
}

-(void)setxMode:(VideoFillModeType)md;
{
    _fillMode = md;
}

-(void) removePixelBufferAtIndex:(int)index
{
    //index从0开始计算
    if (index > (_capacity - 1) || index < 0) {
        return;
    }
    
    [_lockObj lock];
    {
        _backgroundChanged = YES;
        CVPixelBufferRef pixelBuffer = pixelList[index];
        if (pixelBuffer) {
            // 先释放再替换
            CVPixelBufferRelease(pixelBuffer);
            pixelList[index] = NULL;
            [_viewCoordinateInfoDictionary removeObjectForKey:@(index)];
            
            int validCount = 0;
            for (int pixelIndex = 0; pixelIndex < _capacity; pixelIndex++) {
                if (pixelList[pixelIndex]) {
                    validCount++;
                }
            }
            
            NSLog(@"remove pixelbuffer at index:%d, validCount:%d", index, validCount);
        }
    }
    [_lockObj unlock];
    
    __weak typeof(self) weakSelf = self;
    dispatch_sync(_renderQueue, ^{
        [weakSelf render];
    });
}

-(CVPixelBufferRef) pixelBufferAtIndex:(int) index
{
    //index从0开始计算
    if (index > (_capacity - 1) || index < 0) {
        return NULL;
    }
    CVPixelBufferRef pixelBuffer;
    [_lockObj lock];
    pixelBuffer = pixelList[index];
    CVPixelBufferRetain(pixelBuffer);
    [_lockObj unlock];
    return pixelBuffer;
}

-(void)setBackgroudPixelBuffer:(CVPixelBufferRef)bgPixeBuffer ViewCoordinate:(MutilVideoViewCoordinateInfo*)viewCoordinate
{
    [_lockObj lock];
    CVPixelBufferRef retainBuffer = NULL;
    if (bgPixeBuffer) {
        retainBuffer = CVPixelBufferRetain(bgPixeBuffer);
    }
    if (_bgPixelBuf) {
        CVPixelBufferRelease(_bgPixelBuf);
    }
    _backgroundChanged = YES;
    _bgPixelBuf = retainBuffer;
    _bgViewCoordinate = viewCoordinate;
    [_lockObj unlock];
}

- (void)setPixelBuffer:(CVPixelBufferRef)pb ViewCoordinate:(MutilVideoViewCoordinateInfo *)viewCoordinate
{
    if (!_finishInit) {
        NSLog(@"_finish init is false,set pixelbuffer faild");
        return;
    }
    
    if (_isInBackground) {
        return;
    }
    //index从0开始计算
    if (viewCoordinate.index > (_capacity - 1) || viewCoordinate.index < 0) {
        NSLog(@"view coordinate index error. %d", viewCoordinate.index);
        return ;
    }
    
    [_lockObj lock];
    {
        CVPixelBufferRef oldPixelBuffer = pixelList[viewCoordinate.index];
        if(oldPixelBuffer) {
            CVPixelBufferRelease(oldPixelBuffer);
        }
        
        pixelList[viewCoordinate.index] = CVPixelBufferRetain(pb);
        // 视频位置的索引
        int index = viewCoordinate.index;
        MutilVideoViewCoordinateInfo* originalViewCoordinate = [_viewCoordinateInfoDictionary objectForKey:@(index)];
        if (originalViewCoordinate) {
            if (![originalViewCoordinate isTheSame:viewCoordinate]) {
                _backgroundChanged = YES;
                [originalViewCoordinate resetValueWithMutilVideoViewCoordinateInfo:viewCoordinate];
                [_viewCoordinateInfoDictionary setObject:originalViewCoordinate forKey:@(index)];
            }
        } else {
            originalViewCoordinate = [MutilVideoViewCoordinateInfo initWithMutilVideoViewCoordinateInfo:viewCoordinate];
            [_viewCoordinateInfoDictionary setObject:originalViewCoordinate forKey:@(index)];
        }
    }
    [_lockObj unlock];
    
    if (!self.displayLink && !_isStopDisplayLink)
    {
        @synchronized(self) {
            if (!self.displayLink && !_isStopDisplayLink) {
                __weak typeof(self) weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf initDisplayLink];
                });
            }
        }
    }
}

-(void) initDisplayLink {
    if (!self.displayLink && !_isStopDisplayLink) {
        NSLog(@"start display link");
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
#if (!defined(__IPHONE_10_0) || (__IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_10_0))
        _displayLink.frameInterval = 60 / RENDER_RATE;
#else
        if ([_displayLink respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
            if (@available(iOS 10.0, *)) {
                _displayLink.preferredFramesPerSecond = RENDER_RATE;
            } else {
                _displayLink.frameInterval = 60 / RENDER_RATE;
            }
        } else {
            _displayLink.frameInterval = 60 / RENDER_RATE;
        }
#endif
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

-(void) deinitDisplayLink {
    NSLog(@"stop displayLink");
    self.isStopDisplayLink = YES;
    self.displayLink.paused = YES;
    [self.displayLink invalidate];
    self.displayLink = nil;
}

-(void) pauseDisplayLink
{
    _displayLink.paused = YES;
}

-(void) resumeDisplayLink
{
    _displayLink.paused = NO;
}

-(void) displayLinkCallback:(CADisplayLink*) sender {
    __weak typeof(self) weakSelf = self;
    dispatch_sync(_renderQueue, ^{
        [weakSelf render];
    });
}

-(void) render
{
    [_lockObj lock];
    if (self.isInBackground || self.isStopDisplayLink) {
        NSLog(@"do not render screen with opengles while appp is in background mode, inbackgroud %d, stop display link %x", self.isInBackground, self.isStopDisplayLink);
        [_lockObj unlock];
        return ;
    }
    
    {
        if (_bgPixelBuf && _bgViewCoordinate && _backgroundChanged) {
            [self renderPixelBuffer:_bgPixelBuf ViewCoordinate:_bgViewCoordinate FirstPixel:YES];
            _backgroundChanged = NO;
        }
        //  防止上面的判断条件因背景相关的设置不生效，重新判断是否需要清除整个opengl渲染面
        BOOL renderFirstPixel = NO;
        if (_backgroundChanged) {
            renderFirstPixel = YES;
            _backgroundChanged = NO;
        }
        for (int index = 0; index < _capacity; index++) {
            CVPixelBufferRef pixelBuffer = pixelList[index];
            if(pixelBuffer) {
                MutilVideoViewCoordinateInfo* viewCoordinate = [self.viewCoordinateInfoDictionary objectForKey:@(index)];
                if (viewCoordinate) {
                    [self renderPixelBuffer:pixelBuffer ViewCoordinate:viewCoordinate FirstPixel:renderFirstPixel];
                } else {
                    NSLog(@"the pixel buffer would not be rendered, bacause of the view coordinate is nil!");
                }
            }
        }
        if (_videoTextureCache) {
            CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
        }
        glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
        [_openglContext presentRenderbuffer:GL_RENDERBUFFER];
    }
    [_lockObj unlock];
}

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer ViewCoordinate:(MutilVideoViewCoordinateInfo*)viewCoordinate FirstPixel:(BOOL) isFirstPixelToRender
{
    if (!_openglContext || ![EAGLContext setCurrentContext:_openglContext]) {
        NSLog(@"set Current context failed");
        return;
    }
    
    if(pixelBuffer == NULL) {
        NSLog(@"Pixel buffer is null");
        return;
    }
    
    int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    if(frameHeight == 0 || frameWidth == 0) {
        NSLog(@"Pixel buffer width or height is 0");
        return;
    }
    
    size_t planeCount = CVPixelBufferGetPlaneCount(pixelBuffer);
    if(planeCount == 0) {
        NSLog(@" pixel buffer plane count is 0");
        return;
    }
    
    if (!_videoTextureCache) {
        NSLog(@"No video texture cache");
        return;
    }
    
    [self cleanUpTextures];
    
    FourCharCode fourcc = CVPixelBufferGetPixelFormatType(pixelBuffer);
    
    CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    if(colorAttachments) {
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
            if (fourcc == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                fourcc == kCVPixelFormatType_420YpCbCr8Planar) {
                _preferredConversion = kColorConversion601;
            } else {
                _preferredConversion = kColorConversion601FullRange;
            }
        } else if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_709_2, 0) == kCFCompareEqualTo) {
            if (fourcc == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                fourcc == kCVPixelFormatType_420YpCbCr8Planar) {
                _preferredConversion = kColorConversion709;
            } else {
                _preferredConversion = kColorConversion709FullRange;
            }
        } else{
            if (fourcc == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                fourcc == kCVPixelFormatType_420YpCbCr8Planar) {
                _preferredConversion = kColorConversion601;
            } else {
                _preferredConversion = kColorConversion601FullRange;
            }
        }
    } else {
        _preferredConversion = kColorConversion601;
    }
    
    GLfloat rangeOffset = 16.0;
    if (fourcc == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
        fourcc == kCVPixelFormatType_420YpCbCr8PlanarFullRange) {
        rangeOffset = 0.0;
    }
    
    /*
     CVOpenGLESTextureCacheCreateTextureFromImage will create GLES texture optimally from CVPixelBufferRef.
     */
    
    /*
     Create Y and UV textures from the pixel buffer. These textures will be drawn on the frame buffer Y-plane.
     */
    
    glActiveTexture(GL_TEXTURE0);
    
    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                _videoTextureCache,
                                                                pixelBuffer,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                GL_RED_EXT,//GL_LUM
                                                                frameWidth,
                                                                frameHeight,
                                                                GL_RED_EXT,//GL_RED_EXT
                                                                GL_UNSIGNED_BYTE,
                                                                0,
                                                                &_lumaTexture);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    if(planeCount == 2) {
        // UV-plane.
        glActiveTexture(GL_TEXTURE1);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RG_EXT,
                                                           frameWidth / 2,
                                                           frameHeight / 2,
                                                           GL_RG_EXT,
                                                           GL_UNSIGNED_BYTE,
                                                           1,
                                                           &_chromaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    
    // Set the view port to the entire view.
    
    // 视口的原点是以左下角为原点
    
    if (isFirstPixelToRender) {
        glViewport(0, 0, _backingWidth, _backingHeight);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    
    glViewport(viewCoordinate.openglX, viewCoordinate.openglY, viewCoordinate.width, viewCoordinate.height);
    // Use shader program.
    glUseProgram(self.program);
    
    // 0 and 1 are the texture IDs of _lumaTexture and _chromaTexture respectively.
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], 0);
    glUniform1f(uniforms[UNIFORM_RANGEOFFSET], rangeOffset);
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    
    // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
    CGRect viewBounds = CGRectMake(0, 0, viewCoordinate.width, viewCoordinate.height);//self.bounds;
    CGSize contentSize = CGSizeMake(frameWidth, frameHeight);
    CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(contentSize, viewBounds);
    
    // Compute normalized quad coordinates to draw the frame into.
    normalizedSamplingSize = CGSizeMake(0.0, 0.0);
    //    CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/viewBounds.size.width,
    //                                        vertexSamplingRect.size.height/viewBounds.size.height);
    
    CGFloat widthScale = vertexSamplingRect.size.width / viewBounds.size.width, heightScale = vertexSamplingRect.size.height / viewBounds.size.height;
    CGSize cropScaleAmount = CGSizeMake(widthScale, heightScale);
    switch (_fillMode)
    {
        case FillModeNone:
            normalizedSamplingSize = CGSizeMake(1.0, 1.0);
            break;
        case FillModePreserveAspectRatio:
            normalizedSamplingSize = cropScaleAmount;
            break;
        case FillModePreserveAspectRatioAndFill:
        {
            if (widthScale != heightScale)
            {
                widthScale  = viewBounds.size.height / vertexSamplingRect.size.height;
                heightScale = viewBounds.size.width / vertexSamplingRect.size.width;
            }
            normalizedSamplingSize = CGSizeMake(widthScale, heightScale);
            
        }
            break;
        default://maybe another fill mode is not used for yy
            break;
    }
    
    /*
     The quad vertex data defines the region of 2D plane onto which we draw our pixel buffers.
     Vertex data formed using (-1,-1) and (1,1) as the bottom left and top right coordinates respectively, covers the entire screen.
     */
    GLfloat quadVertexData [] = {
        -1 * normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        -1 * normalizedSamplingSize.width, normalizedSamplingSize.height,
        normalizedSamplingSize.width, normalizedSamplingSize.height,
    };
    
    // Update attribute values.
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, quadVertexData);
    /*
     The texture vertices are set up such that we flip the texture vertically. This is so that our top left origin buffers match OpenGL's bottom left texture coordinate system.
     */
    CGRect textureSamplingRect = CGRectMake(0, 0, 1.0, 1.0);
    GLfloat quadTextureData[] =  {
        CGRectGetMinX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
        CGRectGetMaxX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
        CGRectGetMinX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
        CGRectGetMaxX(textureSamplingRect), CGRectGetMinY(textureSamplingRect)
    };
    
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}


# pragma mark - OpenGL setup

- (BOOL)setupGL
{
    _openglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_openglContext || ![EAGLContext setCurrentContext:_openglContext]) {
        NSLog(@"create opengl context failed");
        return NO;
    }
    
    [self setupBuffers];
    [self loadShaders];
    
    glUseProgram(self.program);
    
    // Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
    if (!_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _openglContext, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return NO;
        }
    }
    return YES;
}

-(void) cleanUpGL
{
    if (!_openglContext || ![EAGLContext setCurrentContext:_openglContext]) {
        NSLog(@"_openglContext is nil!");
        return;
    }
    
    [self releaseBuffers];
    
    [self cleanUpTextures];
    
    if(_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
    
    if (self.program) {
        glDeleteProgram(self.program);
        self.program = 0;
    }
    if(_openglContext) {
        _openglContext = nil;
    }
    NSLog(@"clean up opengl context");
}

#pragma mark - Utilities

- (void)setupBuffers
{
    glDisable(GL_DEPTH_TEST);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    [_lockObj lock];
    [self createBuffers];
    [_lockObj unlock];
}

- (void) createBuffers
{
    glGenFramebuffers(1, &_frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    glGenRenderbuffers(1, &_colorBufferHandle);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    [_openglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    if (_backingHeight == 0 || _backingWidth == 0)
    {
        NSLog(@"_backingHeight =%d, _backingWidth=%d",_backingHeight,_backingWidth);
        [self releaseBuffers];
    }
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBufferHandle);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

- (void) releaseBuffers
{
    if(_frameBufferHandle) {
        glDeleteFramebuffers(1, &_frameBufferHandle);
        _frameBufferHandle = 0;
    }
    
    if(_colorBufferHandle) {
        glDeleteRenderbuffers(1, &_colorBufferHandle);
        _colorBufferHandle = 0;
    }
}

- (void) resetRenderBuffer
{
    [_lockObj lock];
    if (!_openglContext || ![EAGLContext setCurrentContext:_openglContext]) {
        NSLog(@"_openglContext is error");
        [_lockObj unlock];
        return;
    }
    
    [self releaseBuffers];
    [self createBuffers];
    [_lockObj unlock];
    
}

- (void) cleanUpTextures
{
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
}

#pragma mark -  OpenGL ES 2 shader compilation

static const GLchar *shader_fsh = (const GLchar*)"varying highp vec2 texCoordVarying;"
"precision mediump float;"
"uniform sampler2D SamplerY;"
"uniform sampler2D SamplerUV;"
"uniform float rangeOffset;"
"uniform mat3 colorConversionMatrix;"
"void main()"
"{"
"    mediump vec3 yuv;"
"    lowp vec3 rgb;"
//   Subtract constants to map the video range start at 0
"    yuv.x = (texture2D(SamplerY, texCoordVarying).r - (rangeOffset/255.0));"
"    yuv.yz = (texture2D(SamplerUV, texCoordVarying).rg - vec2(0.5, 0.5));"
"    rgb = colorConversionMatrix * yuv;"
"    gl_FragColor = vec4(rgb, 1);"
"}";

static const GLchar *shader_vsh = (const GLchar*)"attribute vec4 position;"
"attribute vec2 texCoord;"
"uniform float preferredRotation;"
"varying vec2 texCoordVarying;"
"void main()"
"{"
"    mat4 rotationMatrix = mat4(cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,"
"                               sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,"
"                               0.0,                        0.0, 1.0, 0.0,"
"                               0.0,                        0.0, 0.0, 1.0);"
"    gl_Position = position * rotationMatrix;"
"    texCoordVarying = texCoord;"
"}";

- (BOOL)loadShaders
{
    GLuint vertShader = 0, fragShader = 0;
    
    // Create the shader program.
    self.program = glCreateProgram();
    
    if(![self compileShaderString:&vertShader type:GL_VERTEX_SHADER shaderString:shader_vsh]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    if(![self compileShaderString:&fragShader type:GL_FRAGMENT_SHADER shaderString:shader_fsh]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(self.program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(self.program, fragShader);
    
    // Bind attribute locations. This needs to be done prior to linking.
    glBindAttribLocation(self.program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(self.program, ATTRIB_TEXCOORD, "texCoord");
    
    // Link the program.
    if (![self linkProgram:self.program]) {
        NSLog(@"Failed to link program: %d", self.program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (self.program) {
            glDeleteProgram(self.program);
            self.program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_Y] = glGetUniformLocation(self.program, "SamplerY");
    uniforms[UNIFORM_UV] = glGetUniformLocation(self.program, "SamplerUV");
    //    uniforms[UNIFORM_LUMA_THRESHOLD] = glGetUniformLocation(self.program, "lumaThreshold");
    //    uniforms[UNIFORM_CHROMA_THRESHOLD] = glGetUniformLocation(self.program, "chromaThreshold");
    uniforms[UNIFORM_ROTATION_ANGLE] = glGetUniformLocation(self.program, "preferredRotation");
    uniforms[UNIFORM_RANGEOFFSET] = glGetUniformLocation(self.program, "rangeOffset");
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(self.program, "colorConversionMatrix");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(self.program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(self.program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShaderString:(GLuint *)shader type:(GLenum)type shaderString:(const GLchar*)shaderString
{
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &shaderString, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    GLint status = 0;
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL
{
    NSError *error;
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (sourceString == nil) {
        NSLog(@"Failed to load vertex shader: %@", [error localizedDescription]);
        return NO;
    }
    
    const GLchar *source = (GLchar *)[sourceString UTF8String];
    
    BOOL ret = [self compileShaderString:shader type:type shaderString:source];
    
    return ret;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

-(void) removeFromSuperlayer
{
    NSLog(@"");
    [self deleteAllPixelBuffer];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf deinitDisplayLink];
    });
    [super removeFromSuperlayer];
}

-(void) deleteAllPixelBuffer
{
    [_lockObj lock];
    {
        for (int i = 0; i < _capacity; i++)
        {
            CVPixelBufferRef pixelBuffer = pixelList[i];
            if (pixelBuffer) {
                CVPixelBufferRelease(pixelBuffer);
            }
            pixelList[i] = NULL;
        }
        
        if (_viewCoordinateInfoDictionary) {
            [_viewCoordinateInfoDictionary removeAllObjects];
        }
        
        _backgroundChanged = YES;
    }
    [_lockObj unlock];
}

-(void) deleteBgPixelBuffer
{
    [_lockObj lock];
    {
        if (_bgPixelBuf) {
            CVPixelBufferRelease(_bgPixelBuf);
            _bgViewCoordinate = nil;
            _bgPixelBuf = NULL;
        }
    }
    [_lockObj unlock];
}

- (void)dealloc
{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self deleteAllPixelBuffer];
    [self deleteBgPixelBuffer];
    [_lockObj lock];
    [self cleanUpGL];
    [_lockObj unlock];
    _renderQueue = nil;
    
    NSLog(@"MutilDrawEAGLLayer dealloc");
}

-(uint32_t) getTickCount
{
    struct timeval now;
    gettimeofday(&now, NULL);
    return (uint32_t) (((uint64_t)now.tv_sec * USEC_PER_SEC + now.tv_usec) / 1000);
}

#pragma mark - openglDelegate
- (void)setContianerFrame:(CGRect)rect{
    self.frame = rect;
    dispatch_sync(_renderQueue, ^{
        [self resetRenderBuffer ];
    });

}

- (void)openGLRender{
    
    NSString *imageName = [NSString stringWithFormat:@"container.jpg"];
    UIImage *image = [UIImage imageNamed:imageName];
    CVPixelBufferRef pixelbuffer = imageToYUVPixelBuffer(image);
    
    int screenScale = [UIScreen mainScreen].scale;
    
    int width  = CGRectGetWidth(self.bounds)/3 * screenScale;
    int heigh = CGRectGetHeight(self.bounds)/3 * screenScale;
    if (width > heigh) {
        width = heigh;
    }else{
        heigh = width;
    }
    
    int lineIndex = 0;
    int rowIndex = 0;
    for (int i = 0; i < 9; i++) {
        lineIndex = i / 3;
        rowIndex = i % 3;
        
        MutilVideoViewCoordinateInfo* info = [MutilVideoViewCoordinateInfo new];
        info.openglX = rowIndex * width;
        info.openglY = lineIndex * heigh;
        info.width = width;
        info.height = heigh;
        info.index = i;
        [self setPixelBuffer:pixelbuffer ViewCoordinate:info];
    }
    
    CVPixelBufferRelease(pixelbuffer);
}

- (void)removeFromSuperContainer{
    [_displayLink invalidate];
    [self removeFromSuperlayer];
}
@end
