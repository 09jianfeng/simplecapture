//
//  MultiTextureEAGLLayer.m
//  SimpleCapture
//
//  Created by JFChen on 2018/4/18.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "MultiTextureYUVGLLayer.h"
#import <UIKit/UIKit.h>
#include <OpenGLES/EAGL.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#import "GLProgram.h"
#import "MGLCommon.h"
#import "MGLMatrix.h"

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
 
 uniform mat3 colorConversionMatrix;
 uniform float rangeOffset;
 
 //纹理采样器
 uniform sampler2D texture0Y;
 uniform sampler2D texture0UV;
 uniform sampler2D texture1Y;
 uniform sampler2D texture1UV;
 uniform sampler2D texture2Y;
 uniform sampler2D texture2UV;
 uniform sampler2D texture3Y;
 uniform sampler2D texture3UV;
 uniform sampler2D texture4Y;
 uniform sampler2D texture4UV;
 uniform sampler2D texture5Y;
 uniform sampler2D texture5UV;
 uniform sampler2D texture6Y;
 uniform sampler2D texture6UV;
 uniform sampler2D texture7Y;
 uniform sampler2D texture7UV;
 uniform sampler2D texture8Y;
 uniform sampler2D texture8UV;
 
 void main() {
     //从纹理texture中采样纹理
     float w = 1.0/3.0;
     float w2 = w * 2.0;
     
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     if (TexCoord.x < w && TexCoord.y < w) {
//         gl_FragColor = texture2D(texture0, TexCoord*3.0);
         yuv.x = (texture2D(texture0Y, TexCoord*3.0).r - (rangeOffset/255.0));
         yuv.yz = (texture2D(texture0UV, TexCoord*3.0).rg - vec2(0.5, 0.5));
         rgb = colorConversionMatrix * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
     else if(TexCoord.x > w && TexCoord.x < w2 && TexCoord.y < w){
//         gl_FragColor = texture2D(texture1, TexCoord*3.0);
         yuv.x = (texture2D(texture1Y, TexCoord*3.0).r - (rangeOffset/255.0));
         yuv.yz = (texture2D(texture1UV, TexCoord*3.0).rg - vec2(0.5, 0.5));
         rgb = colorConversionMatrix * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
     else if(TexCoord.x > w2 && TexCoord.x < 1.0 && TexCoord.y < w){
//         gl_FragColor = texture2D(texture2, TexCoord*3.0);
         yuv.x = (texture2D(texture2Y, TexCoord*3.0).r - (rangeOffset/255.0));
         yuv.yz = (texture2D(texture2UV, TexCoord*3.0).rg - vec2(0.5, 0.5));
         rgb = colorConversionMatrix * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
     else if(TexCoord.x < w && TexCoord.y < w2 && TexCoord.y > w){
//         gl_FragColor = texture2D(texture3, TexCoord*3.0);
         yuv.x = (texture2D(texture3Y, TexCoord*3.0).r - (rangeOffset/255.0));
         yuv.yz = (texture2D(texture3UV, TexCoord*3.0).rg - vec2(0.5, 0.5));
         rgb = colorConversionMatrix * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
     else if(TexCoord.x > w && TexCoord.x < w2 && TexCoord.y < w2 && TexCoord.y > w){
//         gl_FragColor = texture2D(texture4, TexCoord*3.0);
         yuv.x = (texture2D(texture4Y, TexCoord*3.0).r - (rangeOffset/255.0));
         yuv.yz = (texture2D(texture4UV, TexCoord*3.0).rg - vec2(0.5, 0.5));
         rgb = colorConversionMatrix * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
     else if(TexCoord.x > w2 && TexCoord.x < 1.0  && TexCoord.y < w2 && TexCoord.y > w){
//         gl_FragColor = texture2D(texture5, TexCoord*3.0);
         yuv.x = (texture2D(texture5Y, TexCoord*3.0).r - (rangeOffset/255.0));
         yuv.yz = (texture2D(texture5UV, TexCoord*3.0).rg - vec2(0.5, 0.5));
         rgb = colorConversionMatrix * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
     else if(TexCoord.x < w && TexCoord.y < 1.0 && TexCoord.y > w2){
//         gl_FragColor = texture2D(texture6, TexCoord*3.0);
         yuv.x = (texture2D(texture6Y, TexCoord*3.0).r - (rangeOffset/255.0));
         yuv.yz = (texture2D(texture6UV, TexCoord*3.0).rg - vec2(0.5, 0.5));
         rgb = colorConversionMatrix * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
     else if(TexCoord.x > w && TexCoord.x < w2 && TexCoord.y < 1.0 && TexCoord.y > w2){
//         gl_FragColor = texture2D(texture7, TexCoord*3.0);
         yuv.x = (texture2D(texture8Y, TexCoord*3.0).r - (rangeOffset/255.0));
         yuv.yz = (texture2D(texture8UV, TexCoord*3.0).rg - vec2(0.5, 0.5));
         rgb = colorConversionMatrix * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
     else if(TexCoord.x > w2 && TexCoord.x < 1.0 && TexCoord.y < 1.0 && TexCoord.y > w2){
//         gl_FragColor = texture2D(texture8, TexCoord*3.0);
         yuv.x = (texture2D(texture8Y, TexCoord*3.0).r - (rangeOffset/255.0));
         yuv.yz = (texture2D(texture8UV, TexCoord*3.0).rg - vec2(0.5, 0.5));
         rgb = colorConversionMatrix * yuv;
         gl_FragColor = vec4(rgb, 1);
     }
     else{
         gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
     }
 }
 );



@implementation MultiTextureYUVGLLayer{
    GLuint _textureIndex;
    GLuint _positionIndex;
    GLuint _colorIndex;
    
    GLProgram *_program;
    unsigned int textures[18];
    unsigned int uniform[18];
    
    EAGLContext   *_context;
    GLuint _framebufferID;
    GLuint _renderBufferID;
    
    GLint _backingWidth;
    GLint _backingHeight;
    
    unsigned int VBO, VAO, EBO;
    
    MGLMatrix *_matrix;
    
    CADisplayLink *_displayLink;
    dispatch_queue_t _queue;
}

- (instancetype)init{
    self = [super init];
    if(self){
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        CGFloat scale = [[UIScreen mainScreen] scale];
        self.contentsScale = scale;
        self.opaque = TRUE;
        self.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:YES]};
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayingLinkDraw)];
        _displayLink.frameInterval = 2.0;
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        _queue = dispatch_queue_create("Render Queue", DISPATCH_QUEUE_SERIAL);
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
    
    for(int i = 0; i < 18; i+=2){
        NSString *attrabuteNameY = [NSString stringWithFormat:@"texture%dY",i/2];
        NSString *attrabuteNameUV = [NSString stringWithFormat:@"texture%dUV",i/2];
        uniform[i] = [_program uniformIndex:attrabuteNameY];
        uniform[i+1] = [_program uniformIndex:attrabuteNameUV];
    }
}

- (void)initGL{
    
    // 如果是 opengl es 2.0 只有 8个纹理单元。 opengl es 3.0有16个纹理单元。
    int MaxTextureImageUnits;
    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &MaxTextureImageUnits);
    NSLog(@"____ MaxTextureImageUnits %d",MaxTextureImageUnits);
    
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
    
    
    // load and create a texture
    // -------------------------
    // load image, create texture and generate mipmaps
    
    // load image, create texture and generate mipmaps
    UIImage *image = [UIImage imageNamed:@"container.jpg"];
    CVPixelBufferRef nv12Pixelbuf = imageToYUVPixelBuffer(image);
    
    for(int i = 0; i < 18; i+=2){
        // Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
        
        CVOpenGLESTextureRef _lumaTexture;
        CVOpenGLESTextureRef _chromaTexture;
        CVOpenGLESTextureCacheRef _videoTextureCache;

        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
        
//         Periodic texture cache flush every frame
        CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
        
        size_t width = CVPixelBufferGetWidthOfPlane(nv12Pixelbuf, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(nv12Pixelbuf, 0);
        
        glActiveTexture(GL_TEXTURE0+i);
        //  On GLES3 use GL_R8 instead of GL_RED
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                    _videoTextureCache,
                                                                    nv12Pixelbuf,
                                                                    NULL,
                                                                    GL_TEXTURE_2D,
                                                                    GL_R8_EXT,//GL_LUM
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
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        
        
        glActiveTexture(GL_TEXTURE0+i+1);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           nv12Pixelbuf,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RG8_EXT,
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
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        
    }
    
    // render container
    [_program use];
    [self setUniforAttribute];
    for(int i = 0; i < 18; i++){
        glUniform1i(uniform[i],i);
    }
    
    glViewport(0,0,_backingWidth,_backingHeight);
}

- (void)displayingLinkDraw{
    
    dispatch_async(_queue, ^{
        [EAGLContext setCurrentContext:_context];
        
        glBindFramebuffer(GL_FRAMEBUFFER, _framebufferID);
        
        // render
        // ------
        glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glBindVertexArrayOES(VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        
        glBindRenderbuffer(GL_RENDERBUFFER, _renderBufferID);
        [_context presentRenderbuffer:GL_RENDERER];
    });
}

- (void)setUpGLWithFrame:(CGRect)rect{
    [EAGLContext setCurrentContext:_context];
    
    [self buildProgram];
    [self initGL];
}

- (void)dealloc{
    
    [EAGLContext setCurrentContext:_context];
    
    glDeleteFramebuffers(1, &_framebufferID);
    glDeleteRenderbuffers(1, &_renderBufferID);
    glDeleteBuffers(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    
    NSLog(@"MultiTextureEAGLLayer dealloc");
}

#pragma mark - openglcontainerDelegate
- (void)setContianerFrame:(CGRect)rect{
    self.frame = rect;
}

- (void)openGLRender{
    [self setUpGLWithFrame:self.frame];
}

- (void)removeFromSuperContainer{
    [self removeFromSuperlayer];
    [_displayLink invalidate];
}

@end
