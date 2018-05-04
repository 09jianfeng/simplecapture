/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  This CAEAGLLayer subclass demonstrates how to draw a CVPixelBufferRef using OpenGLES and display the timecode associated with that pixel buffer in the top right corner.
  
 */

#import "AAPLEAGLLayer.h"

#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>
#include <AVFoundation/AVFoundation.h>
#import <UIKit/UIScreen.h>
#include <OpenGLES/EAGL.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#include <time.h>
#include <sys/time.h>

// #import "log.h"



BOOL IOS8_OR_LATER() {
    return ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending);
}

static uint32_t getTickCount() {
    struct timeval now;
    gettimeofday(&now, NULL);
    return (uint32_t) (((uint64_t)now.tv_sec * USEC_PER_SEC + now.tv_usec) / 1000);
}

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

bool g_isInBackground;

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


@interface AAPLEAGLLayer ()
{
    // The pixel dimensions of the CAEAGLLayer.
    GLint _backingWidth;
    GLint _backingHeight;
    
    EAGLContext *_context;
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
}
@property GLuint program;

@end
static VideoFillModeType  fillMode = FillModePreserveAspectRatio;

@implementation AAPLEAGLLayer
@synthesize pixelBuffer = _pixelBuffer;

-(CVPixelBufferRef) pixelBuffer
{
    return _pixelBuffer;
}

- (void)setPixelBuffer:(CVPixelBufferRef)pb
{
    if(_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    _pixelBuffer = CVPixelBufferRetain(pb);
    
    int frameWidth = (int)CVPixelBufferGetWidth(_pixelBuffer);
    int frameHeight = (int)CVPixelBufferGetHeight(_pixelBuffer);
    
    @synchronized (self) {
        
        if (g_isInBackground) {
            _justInBackground = YES;
            return;
        }
        
        // ios8 or earlier
        if (!IOS8_OR_LATER()) {
            if (_justInBackground) {
                _justInBackground = NO;
                _justRestored = YES;
                _timeRestoreFromBackground = getTickCount();
                //LOGT("AAPLEAGLLayer, restore from background!");
            }
            
            uint32_t now = getTickCount();
            if (now - _timeRestoreFromBackground < 1000) {
                return;
            }
            
            if (_justRestored) {
                _justRestored = NO;
                //LOGT("AAPLEAGLLayer, render the 1st frame after restored from background!");
            }
        }
        
        [self renderPixelBuffer:_pixelBuffer width:frameWidth height:frameHeight];
        
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
}


-(void)setxMode:(VideoFillModeType)md;
{
    fillMode = md;
}

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    //[self updateFrame:frame];
    [self resetRenderBuffer ];
}

-(void)updateFrame:(CGRect)frame
{
    viewFrame = frame;
    if (!CGSizeEqualToSize(self.bounds.size, viewFrame.size) && !CGSizeEqualToSize(self.bounds.size, CGSizeZero))
    {
        self.frame = CGRectMake(viewFrame.origin.x, viewFrame.origin.y, viewFrame.size.width, viewFrame.size.height);// viewFrame;
        [self resetRenderBuffer ];        
    }
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super init];
    if (self) {
        CGFloat scale = [[UIScreen mainScreen] scale];
        self.contentsScale = scale;

        self.opaque = TRUE;
        self.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:YES]};

        [self setFrame:frame];
        
        _justInBackground = NO;
        _timeRestoreFromBackground = 0;
        _justRestored = NO;

        // Set the context into which the frames will be drawn.
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if (!_context) {
            return nil;
        }
        
        // Set the default conversion to BT.601, which is the standard for SDTV.
        _preferredConversion = kColorConversion601;
        
        [self setupGL];
    }
    
    return self;
}

- (void)clearContents
{
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        return;
    }
    [self cleanUpTextures];
    [self resetRenderBuffer];
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer width:(uint32_t)frameWidth height:(uint32_t)frameHeight
{
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        NSLog(@"[VRender] set Current context failed");
        return;
    }

    if(pixelBuffer == NULL) {
        NSLog(@"[VRender] Pixel buffer is null");
        return;
    }
    
    if(frameHeight == 0 || frameWidth == 0) {
        NSLog(@"[VRender] Pixel buffer width or height is 0");
        return;
    }
    
    size_t planeCount = CVPixelBufferGetPlaneCount(pixelBuffer);
    if(planeCount == 0) {
        NSLog(@"[VRender] pixel buffer plane count is 0");
        return;
    }
    
    if (!_videoTextureCache) {
        NSLog(@"[VRender] No video texture cache");
        return;
    }
    
    [self cleanUpTextures];
    
    /*
     Use the color attachment of the pixel buffer to determine the appropriate color conversion matrix.
     */

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
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    // Set the view port to the entire view.
    glViewport(0, 0, _backingWidth, _backingHeight);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // Use shader program.
    glUseProgram(self.program);

    glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], 0);
    glUniform1f(uniforms[UNIFORM_RANGEOFFSET], rangeOffset);
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    
    // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
    CGRect viewBounds = self.bounds;
    CGSize contentSize = CGSizeMake(frameWidth, frameHeight);
    CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(contentSize, viewBounds);
    
    // Compute normalized quad coordinates to draw the frame into.
    normalizedSamplingSize = CGSizeMake(0.0, 0.0);
//    CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/viewBounds.size.width,
//                                        vertexSamplingRect.size.height/viewBounds.size.height);
    
	CGFloat widthScale = vertexSamplingRect.size.width / viewBounds.size.width, heightScale = vertexSamplingRect.size.height / viewBounds.size.height;
    CGSize cropScaleAmount = CGSizeMake(widthScale, heightScale);
    switch (fillMode)
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

    // Normalize the quad vertices.
//    if (cropScaleAmount.width > cropScaleAmount.height) {
//        normalizedSamplingSize.width = 1.0;
//        normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
//    }
//    else {
//        normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
//        normalizedSamplingSize.height = 1.0;;
//    }
    
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
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, quadVertexData);
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    
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
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
}

# pragma mark - OpenGL setup

- (void)setupGL
{
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        return;
    }
    
    [self setupBuffers];
    [self loadShaders];
    
    glUseProgram(self.program);
    
    // 0 and 1 are the texture IDs of _lumaTexture and _chromaTexture respectively.
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], 0);
    glUniform1f(uniforms[UNIFORM_RANGEOFFSET], 0);
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    
    // Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
    if (!_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
}

#pragma mark - Utilities

- (void)setupBuffers
{
    glDisable(GL_DEPTH_TEST);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    
    [self createBuffers];
}

- (void) createBuffers
{
    glGenFramebuffers(1, &_frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    glGenRenderbuffers(1, &_colorBufferHandle);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    if (_backingHeight == 0 || _backingWidth == 0)
    {
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
    @synchronized (self) {
        if (!_context || ![EAGLContext setCurrentContext:_context]) {
            return;
        }
        
        [self releaseBuffers];
        [self createBuffers];
    }
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
    
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

#pragma mark -  OpenGL ES 2 shader compilation

const GLchar *shader_fsh = (const GLchar*)"varying highp vec2 texCoordVarying;"
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

const GLchar *shader_vsh = (const GLchar*)"attribute vec4 position;"
"attribute vec2 texCoord;"
"uniform float preferredRotation;"
"varying vec2 texCoordVarying;"
"void main()"
"{"
"    mat4 rotationMatrix = mat4(cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,"
"                               sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,"
"                               0.0,					    0.0, 1.0, 0.0,"
"                               0.0,					    0.0, 0.0, 1.0);"
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

- (void)dealloc
{
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        return;
    }
    
    [self cleanUpTextures];
    
    if(_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
    if(_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }

    if (self.program) {
        glDeleteProgram(self.program);
        self.program = 0;
    }
    if(_context) {
        _context = nil;
    }
}

@end
