//
//  PixelBufferRotateTool.m
//  SimpleCapture
//
//  Created by JFChen on 2018/6/23.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "PixelBufferRotateTool.h"
#import <UIKit/UIKit.h>
#include <OpenGLES/EAGL.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#import "GLProgram.h"
#import "MGLCommon.h"
#import "MGLMatrix.h"
#import "MGLFrameBuffer.h"
#import <CoreMedia/CoreMedia.h>

#define STRINGIZE(x) #x
#define SHADER_STRING(text) @ STRINGIZE(text)

static NSString *const TextureRGBVS = SHADER_STRING
(
 attribute vec3 aPos;
 attribute vec2 aTextCoord;
 attribute vec3 acolor;
 
 //纹理坐标，传给片段着色器的
 varying vec2 TexCoord;
 varying vec3 outColor;
 
 uniform mat4 transform;
 
 void main() {
     gl_Position = transform * vec4(aPos,1.0);
     TexCoord = aTextCoord.xy;
     outColor = acolor.rgb;
 }
 );

static NSString *const TextureRGBFS = SHADER_STRING
(
 //指明精度
 precision mediump float;
 //纹理坐标，从顶点着色器那里传过来
 varying mediump vec2 TexCoord;
 varying mediump vec3 outColor;
 
 //纹理采样器
 uniform sampler2D textureY;
 uniform sampler2D textureUV;
 
 uniform mat3 colorConversionMatrix;
 uniform float rangeOffset;
 
 void main() {
     //从纹理texture中采样纹理
     gl_FragColor = texture2D(textureY, TexCoord);
     mediump vec3 yuv;
     lowp vec3 rgb;
     yuv.x = (texture2D(textureY, TexCoord).r - (rangeOffset/255.0));
     yuv.yz = (texture2D(textureUV, TexCoord).rg - vec2(0.5, 0.5));
     rgb = colorConversionMatrix * yuv;
     gl_FragColor = vec4(rgb, 1);
 }
 );

@implementation PixelBufferRotateTool{
    GLuint _textureIndex;
    GLuint _positionIndex;
    GLuint _colorIndex;
    
    GLProgram *_program;
    
    EAGLContext   *_context;
    
    unsigned int VBO, VAO, EBO;
    
    MGLFrameBuffer *_mglFB;
    
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    MGLMatrix *_matrix;
    int _angle;
    
    NSOutputStream *_outPutStream;
}

- (instancetype)init{
    self = [super init];
    if(self){
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        _matrix = [MGLMatrix new];
        [_matrix setIdentity];
        
        [EAGLContext setCurrentContext:_context];
        [self buildProgram];
        [self initVertBuffer];
    }
    return self;
}


// BT.709, which is the standard for HDTV.
static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

// if full range then rangeOffset is 0; 16.0 is video range
static GLfloat rangeOffset = 16.0;
- (void)setUniforAttribute{
//    glUniform1f([_program uniformIndex:@"colorConversionMatrix"], 0);//rangeOffset
    glUniform1f([_program uniformIndex:@"rangeOffset"], rangeOffset);
    glUniformMatrix3fv([_program uniformIndex:@"colorConversionMatrix"], 1, GL_FALSE, kColorConversion709);
    
    glUniform1i([_program uniformIndex:@"textureY"], 0);
    glUniform1i([_program uniformIndex:@"textureUV"], 1);
    glUniformMatrix4fv([_program uniformIndex:@"transform"], 1, GL_FALSE, _matrix.mtxElements);
}

- (void)buildProgram{
    _program = [[GLProgram alloc] initWithVertexShaderString:TextureRGBVS fragmentShaderString:TextureRGBFS];
    [_program addAttribute:@"aPos"];
    [_program addAttribute:@"aTextCoord"];
    [_program addAttribute:@"acolor"];
    
    if (![_program link]) {
        NSString *programLog = [_program programLog];
        NSLog(@"Program link log: %@", programLog);
        NSString *fragmentLog = [_program fragmentShaderLog];
        NSLog(@"Fragment shader compile log: %@", fragmentLog);
        NSString *vertexLog = [_program vertexShaderLog];
        NSLog(@"Vertex shader compile log: %@", vertexLog);
        _program = nil;
        NSAssert(NO, @"Falied to link HalfSpherical shaders");
    }
    
    _positionIndex = [_program attributeIndex:@"aPos"];
    _textureIndex = [_program attributeIndex:@"aTextCoord"];
    _colorIndex = [_program attributeIndex:@"acolor"];
}

- (void)initVertBuffer{
    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    float vertices[] = {
        // positions          // colors           // texture coords
        1.0f,  1.0f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f, // top right
        1.0f, -1.0f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f, // bottom right
        -1.0f, -1.0f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f, // bottom left
        -1.0f,  1.0f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f  // top left
    };
    unsigned int indices[] = {
        0, 1, 3, // first triangle
        1, 2, 3  // second triangle
    };
    
    
    glGenVertexArraysOES(1, &VAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);
    
    glBindVertexArrayOES(VAO);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    // position attribute
    glVertexAttribPointer(_positionIndex, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(_positionIndex);
    
    // color attribute
    glVertexAttribPointer(_colorIndex, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(_colorIndex);
    
    // texture coord attribute
    glVertexAttribPointer(_textureIndex, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
    glEnableVertexAttribArray(_textureIndex);
}

- (void)loadTexture:(CVPixelBufferRef)nv12Pixelbuf{
    // Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
    if (!_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
    
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
    
    size_t width = CVPixelBufferGetWidth(nv12Pixelbuf);
    size_t height = CVPixelBufferGetHeight(nv12Pixelbuf);
    
    glActiveTexture(GL_TEXTURE0);
    // 这个函数是 opengl es 2的
    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                _videoTextureCache,
                                                                nv12Pixelbuf,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                GL_RED_EXT,//GL_LUM
                                                                (int)width,
                                                                (int)height,
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

    
    glActiveTexture(GL_TEXTURE1);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       nv12Pixelbuf,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RG_EXT,
                                                       (int)width/2,
                                                       (int)height/2,
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

- (CVPixelBufferRef)drawOpenGL:(CVPixelBufferRef)pix{
    [EAGLContext setCurrentContext:_context];
    
    // -- offscreen
    [_mglFB activateFramebuffer];

    [self loadTexture:pix];
    // render
    // ------
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // render container
    [_program use];
	[self setUniforAttribute];
    glBindVertexArrayOES(VAO);
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    [_mglFB deactiveFramebuffer];
    
    glFlush();
    return _mglFB.pixelBuffer;
}

#pragma mark - openglcontainerDelegate
- (CVPixelBufferRef)rotatePixelBuffer:(CVPixelBufferRef)pix rotate:(int)angle{
    [self rotate:angle];
    
    [EAGLContext setCurrentContext:_context];
    
    size_t width = CVPixelBufferGetWidth(pix);
    size_t height = CVPixelBufferGetHeight(pix);

    if(!_mglFB){
        _mglFB = [[MGLFrameBuffer alloc] initWithSize:CGSizeMake(width, height)];
    }
    
    return [self drawOpenGL:pix];
}

- (void)rotate:(int)angle{
    if (_angle != angle) {
        [_matrix setRotate:angle xAxis:0.0 yAxis:0.0 zAxis:1.0];
    }
    _angle = angle;
}
    
#pragma mark - write nv12 to file
- (void)writeSampleBufferData:(CMSampleBufferRef)sampleBuffer{
    CVPixelBufferRef pixelBuffer = CVPixelBufferRetain(CMSampleBufferGetImageBuffer(sampleBuffer));
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int heigh = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    CVPlanarPixelBufferInfo_YCbCrBiPlanar *pi = (CVPlanarPixelBufferInfo_YCbCrBiPlanar*)(baseAddress);
    size_t yPlaneOffset = CFSwapInt32(pi->componentInfoY.offset);
    size_t cbcrPlaneOffset = CFSwapInt32(pi->componentInfoCbCr.offset);
    uint32_t yPlanePitch = CFSwapInt32(pi->componentInfoY.rowBytes);
    uint32_t cbcrPlanePitch = CFSwapInt32(pi->componentInfoCbCr.rowBytes);
    
    
    // nv12 format
    for (int i = 0; i < heigh; i++) {
        //write y
        [_outPutStream write:baseAddress+yPlaneOffset+yPlanePitch*i maxLength:width];
    }
    for (int i = 0; i < heigh/2; i++) {
        //write uv
        [_outPutStream write:baseAddress+cbcrPlaneOffset+cbcrPlanePitch*i maxLength:width];
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferRelease(pixelBuffer);
}

@end


