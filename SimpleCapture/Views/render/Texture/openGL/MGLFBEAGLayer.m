//
//  MGLFBEAGLayer.m
//  SimpleCapture
//
//  Created by JFChen on 2018/6/22.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "MGLFBEAGLayer.h"

#import <UIKit/UIKit.h>
#include <OpenGLES/EAGL.h>
#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>
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
 uniform sampler2D texture;
 void main() {
     //从纹理texture中采样纹理
     gl_FragColor = texture2D(texture, TexCoord) * vec4(outColor, 1.0);
 }
 );



static NSString *const ScreenTextureRGBVS = SHADER_STRING
(
 attribute vec3 aPos;
 attribute vec2 aTextCoord;
 
 //纹理坐标，传给片段着色器的
 varying vec2 TexCoord;
 
 void main() {
     gl_Position = vec4(aPos,1.0);
     TexCoord = aTextCoord.xy;
 }
 );

static NSString *const ScreenTextureRGBFS = SHADER_STRING
(
 //指明精度
 precision mediump float;
 //纹理坐标，从顶点着色器那里传过来
 varying mediump vec2 TexCoord;
 
 //纹理采样器
 uniform sampler2D texture;
 void main() {
     //从纹理texture中采样纹理
     gl_FragColor = texture2D(texture, TexCoord);
 }
 );

@implementation MGLFBEAGLayer{
    GLuint _textureIndex;
    GLuint _positionIndex;
    GLuint _colorIndex;
    
    GLProgram *_program;
    GLProgram *_screenProgram;
    
    unsigned int texture;
    EAGLContext   *_context;
    GLuint _framebufferID;
    GLuint _renderBufferID;
    
    GLint _backingWidth;
    GLint _backingHeight;
    
    unsigned int VBO, VAO, EBO;
    
    MGLFrameBuffer *_mglFB;
}

- (instancetype)init{
    self = [super init];
    if(self){
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        
        CGFloat scale = [[UIScreen mainScreen] scale];
        self.contentsScale = scale;
        self.opaque = TRUE;
        self.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:YES]};
    }
    return self;
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
    
    _screenProgram = [[GLProgram alloc] initWithVertexShaderString:ScreenTextureRGBVS fragmentShaderString:ScreenTextureRGBFS];
    if(![_screenProgram link]){
        NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_screenProgram programLog], [_screenProgram fragmentShaderLog], [_screenProgram vertexShaderLog]);
        _screenProgram = nil;
        NSAssert(NO, @"Falied to link TextureRGBFS shaders");
    }

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
}

- (void)loadTexture{
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
    
    // load image, create texture and generate mipmaps
    UIImage *image = [UIImage imageNamed:@"container.jpg"];
    MImageData* imageData = mglImageDataFromUIImage(image, YES);
    glTexImage2D(GL_TEXTURE_2D, 0, imageData->format, (GLint)imageData->width, (GLint)imageData->height, 0, imageData->format, imageData->type, imageData->data);
    glGenerateMipmap(GL_TEXTURE_2D);
    
    mglDestroyImageData(imageData);
}

- (void)drawOpenGL{
    [EAGLContext setCurrentContext:_context];
    
    // -- offscreen
    [_mglFB activateFramebuffer];

    // render
    // ------
    glClearColor(0.5f, 1.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // render container
    [_program use];
    glBindVertexArrayOES(VAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture);
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    [_mglFB deactiveFramebuffer];
    
    
    
    // -- on screen
    glBindFramebuffer(GL_FRAMEBUFFER, _framebufferID);
    glViewport(0,0,_backingWidth,_backingHeight);
    
    // render
    // ------
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // render container
    [_program use];
    glBindVertexArrayOES(VAO);
    
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