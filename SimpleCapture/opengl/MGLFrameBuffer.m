//
//  MGLFrameBuffer.m
//  video
//
//  Created by bleach on 16/8/2.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import "MGLFrameBuffer.h"
#import "MGLTools.h"

@interface MGLFrameBuffer()

//FrameBuffer的尺寸
@property (nonatomic, assign) CGSize size;
//纹理配置
@property (nonatomic, assign) MGLTextureOptions textureOptions;
//申请的FrameBuffer Id
@property (nonatomic, assign) GLuint framebuffer;
//申请的RenderBuffer Id
@property (nonatomic, assign) GLuint depthBuffer;
//数据读取(当锁用)
@property (nonatomic, assign) NSUInteger readLockCount;

@end

@implementation MGLFrameBuffer {
    //渲染的目标对象(能直接转换成图像)
    CVPixelBufferRef _renderTarget;
    //渲染的目标对象纹理(可用于二次渲染)
    CVOpenGLESTextureRef _renderTexture;
    //纹理缓存
    CVOpenGLESTextureCacheRef _textureCache;
}

- (id)initWithSize:(CGSize)framebufferSize {
    MGLTextureOptions defaultTextureOptions;
    defaultTextureOptions.minFilter = GL_LINEAR;
    defaultTextureOptions.magFilter = GL_LINEAR;
    defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.internalFormat = GL_RGBA;
    defaultTextureOptions.format = GL_BGRA;
    defaultTextureOptions.type = GL_UNSIGNED_BYTE;
    
    if (!(self = [self initWithSize:framebufferSize textureOptions:defaultTextureOptions])) {
        return nil;
    }
    
    return self;
}


- (id)initWithSize:(CGSize)framebufferSize textureOptions:(MGLTextureOptions)fboTextureOptions {
    if (!(self = [super init])) {
        return nil;
    }
    
    _textureOptions = fboTextureOptions;
    _size = framebufferSize;
    
    [self generateFramebuffer];
    [self doRegisterNotification];
    return self;
}

- (id)initWithSize:(CGSize)framebufferSize inputTexture:(GLuint)inputTexture {
    if (!(self = [super init])) {
        return nil;
    }
    
    MGLTextureOptions defaultTextureOptions;
    defaultTextureOptions.minFilter = GL_LINEAR;
    defaultTextureOptions.magFilter = GL_LINEAR;
    defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.internalFormat = GL_RGBA;
    defaultTextureOptions.format = GL_BGRA;
    defaultTextureOptions.type = GL_UNSIGNED_BYTE;
    
    _textureOptions = defaultTextureOptions;
    _size = framebufferSize;
    
    _bindTexture = inputTexture;
    
    return self;
}

- (void)activateFramebuffer {
    glViewport(0, 0, (GLsizei)_size.width, (GLsizei)_size.height);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
}

- (void)deactiveFramebuffer {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

#pragma mark - inner
- (void)doRegisterNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (void)handleMemoryWarning {
    if (_textureCache) {
        CVOpenGLESTextureCacheFlush(_textureCache, 0);
    }
}

- (void)generateTexture {
    glActiveTexture(GL_TEXTURE2);
    glGenTextures(1, &_bindTexture);
    glBindTexture(GL_TEXTURE_2D, _bindTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, _textureOptions.minFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, _textureOptions.magFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);
}

- (void)generateFramebuffer {
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    // create a depth buffer and bind it.
    glGenRenderbuffers(1, &_depthBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthBuffer);
    
    //是否可使用iOS的FBO加速(如果不可以就需要使用传统的glTexImage2D)
    if ([MGLTools supportsFastTextureUpload]) {
        EAGLContext* glContext = [EAGLContext currentContext];
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, glContext, NULL, &_textureCache);
        if (err) {
           // [YYLogger info:TPreProcess message:@"generateFramebuffer CVOpenGLESTextureCacheCreate err:%d", err];
            NSLog(@"generateFramebuffer CVOpenGLESTextureCacheCreate err:%d", err);
        }
        
//        CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, (void*)[NSDictionary dictionary]);
        CFDictionarySetValue(attrs, kCVPixelBufferOpenGLESCompatibilityKey, (void*)[NSNumber numberWithBool:YES]);

        err = CVPixelBufferCreate(kCFAllocatorDefault, (int)_size.width, (int)_size.height, kCVPixelFormatType_32BGRA, attrs, &_renderTarget);
        
        if (err) {
           // [YYLogger info:TPreProcess message:@"generateFramebuffer error CVPixelBufferCreate err:%d FBO size:w:%f h:%f",err, _size.width, _size.height];
            NSLog(@"generateFramebuffer error CVPixelBufferCreate err:%d FBO size:w:%f h:%f",err, _size.width, _size.height);
        }
        
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _textureCache,
                                                           _renderTarget,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           _textureOptions.internalFormat,
                                                           (int)_size.width,
                                                           (int)_size.height,
                                                           _textureOptions.format,
                                                           _textureOptions.type,
                                                           0,
                                                           &_renderTexture);
        if (err) {
            //[YYLogger info:TPreProcess message:@"generateFramebuffer CVOpenGLESTextureCacheCreateTextureFromImage err:%d",err];
        }
        
        CFRelease(attrs);
//        CFRelease(empty);
        
        glBindTexture(CVOpenGLESTextureGetTarget(_renderTexture), CVOpenGLESTextureGetName(_renderTexture));
        _bindTexture = CVOpenGLESTextureGetName(_renderTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, _textureOptions.minFilter);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, _textureOptions.magFilter);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);
        
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, _size.width, _size.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(_renderTexture), 0);
    } else {
        [self generateTexture];
        glBindTexture(GL_TEXTURE_2D, _bindTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, _textureOptions.internalFormat, (int)_size.width, (int)_size.height, 0, _textureOptions.format, _textureOptions.type, 0);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, _size.width, _size.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _bindTexture, 0);
    }
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"___ MGLFrameBuffer glCheckFramebufferStatus error %d",status);
    }
    
    glBindTexture(GL_TEXTURE_2D, 0);
}

- (void)deInit {
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_depthBuffer) {
        glDeleteRenderbuffers(1, &_depthBuffer);
        _depthBuffer = 0;
    }
    
    if ([MGLTools supportsFastTextureUpload]) {
        //如果使用加速的纹理,不需要glDeleteTextures
        if (_renderTarget) {
            CFRelease(_renderTarget);
            _renderTarget = NULL;
        }
        
        if (_renderTexture) {
            CFRelease(_renderTexture);
            _renderTexture = NULL;
        }
        
        if (_textureCache) {
            CFRelease(_textureCache);
            _textureCache = NULL;
        }
    } else {
        glDeleteTextures(1, &_bindTexture);
        _bindTexture = 0;
    }
}

- (NSInteger)bytesPerRow {
    if ([MGLTools supportsFastTextureUpload]) {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        return CVPixelBufferGetBytesPerRow(_renderTarget);
#else
        return _size.width * 4;
#endif
    } else {
        return _size.width * 4;
    }
}

- (CVPixelBufferRef)pixelBuffer {
    if ([MGLTools supportsFastTextureUpload]) {
        
        /*
        CIImage* ciImage = [CIImage imageWithCVPixelBuffer:_renderTarget];
        CGImageRef videoImage = [[CIContext contextWithOptions:nil] createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(_renderTarget), CVPixelBufferGetHeight(_renderTarget))];
        
        UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
        CGImageRelease(videoImage);
        */
        
        return _renderTarget;
    } else {
        return nil;
    }
}

- (void)lockForReading {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    if ([MGLTools supportsFastTextureUpload]) {
        if (_readLockCount == 0) {
            CVPixelBufferLockBaseAddress(_renderTarget, 0);
        }
        _readLockCount++;
    }
#endif
}

- (void)unlockAfterReading {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    if ([MGLTools supportsFastTextureUpload]) {
        if (_readLockCount <= 0) {
            //[YYLogger info:TPreProcess message:@"Unbalanced call to -[MGLFrameBuffer unlockAfterReading]"];
        }
        
        _readLockCount--;
        if (_readLockCount == 0) {
            CVPixelBufferUnlockBaseAddress(_renderTarget, 0);
        }
    }
#endif
}

- (GLubyte *)byteBuffer {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    [self lockForReading];
    GLubyte * bufferBytes = CVPixelBufferGetBaseAddress(_renderTarget);
    [self unlockAfterReading];
    return bufferBytes;
#else
    return NULL; // TODO: do more with this on the non-texture-cache side
#endif
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
