//
//  MGLFBYUVEAGLayer.m
//  SimpleCapture
//
//  Created by JFChen on 2018/6/23.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "MGLFBYUVEAGLayer.h"
#import <UIKit/UIKit.h>
#include <OpenGLES/EAGL.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#import "GLProgram.h"
#import "MGLCommon.h"

#import "MGLFrameBuffer.h"

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
 
 void main() {
     gl_Position = vec4(aPos,1.0);
     TexCoord = vec2(aTextCoord.x,aTextCoord.y);
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
//     gl_FragColor = texture2D(textureY, TexCoord);
     mediump vec3 yuv;
     lowp vec3 rgb;
     yuv.x = (texture2D(textureY, TexCoord).r - (rangeOffset/255.0));
     yuv.yz = (texture2D(textureUV, TexCoord).rg - vec2(0.5, 0.5));
     rgb = colorConversionMatrix * yuv;
     gl_FragColor = vec4(rgb, 1)*vec4(outColor,1);
 }
 );



static NSString *const ScreenTextureRGBVS = SHADER_STRING
(
 attribute vec3 aPos;
 attribute vec2 aTextCoord;
 attribute vec3 acolor;
 
 //纹理坐标，传给片段着色器的
 varying vec2 TexCoord;
 varying vec3 outColor;
 
 void main() {
     gl_Position = vec4(aPos,1.0);
     TexCoord = aTextCoord.xy;
     
// 注意：这里传递acolor的值的话，会导致渲染变形。为什么会这样呢？？？？？？
//     outColor = acolor.rgb;
 }
 );

static NSString *const ScreenTextureRGBFS = SHADER_STRING
(
 //指明精度
 precision mediump float;
 //纹理坐标，从顶点着色器那里传过来
 varying mediump vec2 TexCoord;
 varying mediump vec3 outColor;
 
 //纹理采样器
 uniform sampler2D texture;
 void main() {
     //从纹理texture中采样纹理
     gl_FragColor = texture2D(texture, TexCoord);
 }
 );

@implementation MGLFBYUVEAGLayer{
    GLuint _textureIndex;
    GLuint _positionIndex;
    GLuint _colorIndex;
    
    GLuint _ontextureIndex;
    GLuint _onpositionIndex;
    GLuint _oncolorIndex;

    
    GLProgram *_program;
    GLProgram *_screenProgram;
    
    EAGLContext   *_context;
    GLuint _framebufferID;
    GLuint _renderBufferID;
    
    GLint _backingWidth;
    GLint _backingHeight;
    
    unsigned int VBO, VAO, EBO;
    unsigned int onVBO, onVAO, onEBO;
    
    MGLFrameBuffer *_mglFB;
    
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
}

- (instancetype)init{
    self = [super init];
    if(self){
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        CGFloat scale = [[UIScreen mainScreen] scale];
        self.contentsScale = scale;
        self.opaque = TRUE;
        self.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:YES]};
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
}

- (void)buildProgram{
    // -- offscreen
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
    
    //-- screen
    _screenProgram = [[GLProgram alloc] initWithVertexShaderString:ScreenTextureRGBVS fragmentShaderString:ScreenTextureRGBFS];
    if(![_screenProgram link]){
        NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_screenProgram programLog], [_screenProgram fragmentShaderLog], [_screenProgram vertexShaderLog]);
        _screenProgram = nil;
        NSAssert(NO, @"Falied to link TextureRGBFS shaders");
    }
    [_screenProgram addAttribute:@"aPos"];
    [_screenProgram addAttribute:@"aTextCoord"];
    [_screenProgram addAttribute:@"acolor"];
    
    _onpositionIndex = [_screenProgram attributeIndex:@"aPos"];
    _ontextureIndex = [_screenProgram attributeIndex:@"aTextCoord"];
    _oncolorIndex = [_screenProgram attributeIndex:@"acolor"];

}

- (void)initFramebuffer{
    // -- on screen
    // general framebuffer
    glGenFramebuffers(1, &_framebufferID);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebufferID);
    
    glGenRenderbuffers(1, &_renderBufferID);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBufferID);
    
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBufferID);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

- (void)initVertBuffer{
    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
//    float vertices[] = {
//        // positions          // colors           // texture coords
//        0.5f,  0.5f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f, // top right
//        0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f, // bottom right
//        -0.5f, -0.5f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f, // bottom left
//        -0.5f,  0.5f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f  // top left
//    };
    
    float vertices[] = {
        // positions          // colors           // texture coords
        0.5f,  0.5f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f, // top right
        0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f, // bottom right
        -0.5f, -0.5f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f, // bottom left
        -0.5f,  0.5f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f  // top left
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
    
    glBindVertexArrayOES(0);
    
    
    
    
    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    float onvertices[] = {
        // positions          // colors           // texture coords
        0.5f,  0.5f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f, // top right
        0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f, // bottom right
        -0.5f, -0.5f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f, // bottom left
        -0.5f,  0.5f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f  // top left
    };
//    float onvertices[] = {
//        // positions          // colors           // texture coords
//        1.0f,  1.0f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f, // top right
//        1.0f, -1.0f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f, // bottom right
//        -1.0f, -1.0f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f, // bottom left
//        -1.0f,  1.0f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f  // top left
//    };

    unsigned int onindices[] = {
        0, 1, 3, // first triangle
        1, 2, 3  // second triangle
    };
    
    
    glGenVertexArraysOES(1, &onVAO);
    glGenBuffers(1, &onVBO);
    glGenBuffers(1, &onEBO);
    
    glBindVertexArrayOES(onVAO);
    
    glBindBuffer(GL_ARRAY_BUFFER, onVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(onvertices), onvertices, GL_STATIC_DRAW);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, onEBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(onindices), onindices, GL_STATIC_DRAW);
    
    // position attribute
    glVertexAttribPointer(_onpositionIndex, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(_onpositionIndex);
    
    // color attribute
    glVertexAttribPointer(_oncolorIndex, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(_oncolorIndex);
    
    // texture coord attribute
    glVertexAttribPointer(_ontextureIndex, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
    glEnableVertexAttribArray(_ontextureIndex);
    
    glBindVertexArrayOES(0);

}

- (void)loadTexture{
    // Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
    if (!_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
    
    // load image, create texture and generate mipmaps
    UIImage *image = [UIImage imageNamed:@"container.jpg"];
    CVPixelBufferRef nv12Pixelbuf = imageToYUVPixelBuffer(image);
    
    size_t width = CVPixelBufferGetWidthOfPlane(nv12Pixelbuf, 0);
    size_t height = CVPixelBufferGetHeightOfPlane(nv12Pixelbuf, 0);
    
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
    
    /*
    // load and create a texture
    // -------------------------
    glActiveTexture(GL_TEXTURE0); //GL_TEXTURE0对应着片段着色器里面声明的uniform sampler2D采样器 默认是单位采样单位0. 如果要设置那个变量的采样单元 glUniform1i(glGetUniformLocation(ourShader.ID, "texture1"), 0);
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture); // all upcoming GL_TEXTURE_2D operations now have effect on this texture object
    //    // set the texture wrapping parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);    // set texture wrapping to GL_REPEAT (default wrapping method)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    // set texture filtering parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    MImageData* imageData = mglImageDataFromUIImage(image, YES);
    glTexImage2D(GL_TEXTURE_2D, 0, imageData->format, (GLint)imageData->width, (GLint)imageData->height, 0, imageData->format, imageData->type, imageData->data);
    glGenerateMipmap(GL_TEXTURE_2D);
    mglDestroyImageData(imageData);
     */
}

- (void)drawOpenGL{
    [EAGLContext setCurrentContext:_context];
    
    // -- offscreen
    [_mglFB activateFramebuffer];
    
    // render
    // ------
    glClearColor(0.5f, 0.4f, 0.3f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // render container
    [_program use];
    [self setUniforAttribute];
    
    glBindVertexArrayOES(VAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    [_mglFB deactiveFramebuffer];
    
    glFlush();
    CVPixelBufferRef pixel = _mglFB.pixelBuffer;
    NSLog(@"pixel %@",pixel);
    
    // -- on screen
    glBindFramebuffer(GL_FRAMEBUFFER, _framebufferID);
    glViewport(0,0,_backingWidth,_backingHeight);
    
    // render
    // ------
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // render container
    [_screenProgram use];
    glBindVertexArrayOES(onVAO);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _mglFB.bindTexture);
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    [_context presentRenderbuffer:GL_RENDERER];
}

#pragma mark - openglcontainerDelegate
- (void)setContianerFrame:(CGRect)rect{
    self.frame = rect;
}

- (void)setUpGLWithFrame:(CGRect)rect{
    [self buildProgram];
    [self initVertBuffer];
    [self loadTexture];
    [self initFramebuffer];
}


- (void)openGLRender{
    [EAGLContext setCurrentContext:_context];
    
    if(!_mglFB){
        int scale = [UIScreen mainScreen].scale;
        int width = CGRectGetWidth(self.bounds) * scale;
        int heigh = CGRectGetHeight(self.bounds) * scale;
        
        _mglFB = [[MGLFrameBuffer alloc] initWithSize:CGSizeMake(width, heigh)];
    }
    
    [self setUpGLWithFrame:self.frame];
    
    [self drawOpenGL];
}

- (void)removeFromSuperContainer{
    [self removeFromSuperlayer];
}

@end
