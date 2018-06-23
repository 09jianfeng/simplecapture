//
//  TextureGLKView.m
//  SimpleCapture
//
//  Created by JFChen on 2018/4/19.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "TextureGLKViewFBTexture.h"
#import "GLProgram.h"
#import "MGLCommon.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <GLKit/GLKit.h>

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


@interface TextureGLKViewFBTexture()<GLKViewDelegate>
@property (nonatomic, strong) GLKView *glkView;
@property (nonatomic, strong) EAGLContext *context;
@end

@implementation TextureGLKViewFBTexture{
    GLProgram *_program;
    GLProgram *_screenProgram;
    
    GLuint aPos;
    GLuint aTextCoord;
    GLuint acolor;
    GLuint VAO,VBO,EBO;
    GLuint texture0;
    
    unsigned int offscreenTextureId;
    unsigned int offscreenTextureIdLoc;
    unsigned int offscreenBufferId;
    
    CADisplayLink *_displayLink;
}

- (void)dealloc{
    glDeleteBuffers(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    NSLog(@"TextureGLKViewFBTexture dealloc");
}

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self){
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        [EAGLContext setCurrentContext:_context];

        _glkView = [[GLKView alloc] initWithFrame:self.bounds];
        _glkView.delegate = self;
        _glkView.context = _context;
        _glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
        _glkView.enableSetNeedsDisplay = NO;
        [self addSubview:_glkView];
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayingLinkDraw)];
        _displayLink.frameInterval = 2.0;
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)buildProgram{
    _program = [[GLProgram alloc] initWithVertexShaderString:TextureRGBVS fragmentShaderString:TextureRGBFS];
    [_program addAttribute:@"aPos"];
    [_program addAttribute:@"aTextCoord"];
    [_program addAttribute:@"acolor"];
    
    if(![_program link]){
        NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_program programLog], [_program fragmentShaderLog], [_program vertexShaderLog]);
        _program = nil;
        NSAssert(NO, @"Falied to link TextureRGBFS shaders");
    }
    
    aPos = [_program attributeIndex:@"aPos"];
    aTextCoord = [_program attributeIndex:@"aTextCoord"];
    acolor = [_program attributeIndex:@"acolor"];
    
    _screenProgram = [[GLProgram alloc] initWithVertexShaderString:ScreenTextureRGBVS fragmentShaderString:ScreenTextureRGBFS];
    [_screenProgram addAttribute:@"aPos"];
    [_screenProgram addAttribute:@"aTextCoord"];
    
    if(![_screenProgram link]){
        NSLog(@"_program link error %@  fragement log %@  vertext log %@", [_screenProgram programLog], [_screenProgram fragmentShaderLog], [_screenProgram vertexShaderLog]);
        _screenProgram = nil;
        NSAssert(NO, @"Falied to link TextureRGBFS shaders");
    }
}

- (void)setupFramebuffer{
    { // 设置framebuffer。 并且给framebuffer附加上 纹理。  framebuffer必须附加上纹理或者 renderbuffer。
        GLint defaultFramebuffer = 0;
        int scale = [UIScreen mainScreen].scale;
        // use 1K by 1K texture for shadow map
        unsigned int offscreenTextureWidth = CGRectGetWidth(self.frame) * scale;
        unsigned int  offscreenTextureHeight = CGRectGetHeight(self.frame) * scale;
        
        glGenTextures ( 1, &offscreenTextureId );
        glBindTexture ( GL_TEXTURE_2D, offscreenTextureId );
        glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, offscreenTextureWidth, offscreenTextureHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
        
        glBindTexture ( GL_TEXTURE_2D, 0 );
        
        glGetIntegerv ( GL_FRAMEBUFFER_BINDING, &defaultFramebuffer );
        // setup fbo
        glGenFramebuffers ( 1, &offscreenBufferId );
        glBindFramebuffer ( GL_FRAMEBUFFER, offscreenBufferId );
        
        glFramebufferTexture2D ( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, offscreenTextureId, 0 );
        glBindTexture ( GL_TEXTURE_2D, offscreenTextureId );
        
        GLuint depthRenderbuffer;
        glGenRenderbuffers(1, &depthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, offscreenTextureWidth, offscreenTextureHeight);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        if ( GL_FRAMEBUFFER_COMPLETE != glCheckFramebufferStatus ( GL_FRAMEBUFFER ) )
        {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        }
        glBindFramebuffer ( GL_FRAMEBUFFER, defaultFramebuffer );
        
    }
}

- (void)setUpGLBuffers{
    {  //生成并且绑定顶点数据。  VAO、VOB、EBO。  这些顶点数据都会被VAO附带。要用的时候不需要在赋值顶点数据、纹理顶点数据。只需要绑定VAO。就是复带上了所需的顶点数据
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
        glVertexAttribPointer(aPos, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(aPos);
        
        // color attribute
        glVertexAttribPointer(acolor, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
        glEnableVertexAttribArray(acolor);
        
        // texture coord attribute
        glVertexAttribPointer(aTextCoord, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
        glEnableVertexAttribArray(aTextCoord);
    }
}

// 生成并且绑定纹理
- (void)setUpTexture{
    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &texture0);
    glBindTexture(GL_TEXTURE_2D, texture0);
    // set the texture wrapping parameters
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

#pragma mark - GLKViewDelegate
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    [EAGLContext setCurrentContext:_context];
    
    int scale = [UIScreen mainScreen].scale;
    int width = CGRectGetWidth(rect) * scale;
    int heigh = CGRectGetHeight(rect) * scale;
    
    GLint defaultFramebuffer = 0;
    glGetIntegerv ( GL_FRAMEBUFFER_BINDING, &defaultFramebuffer );
    
    glBindFramebuffer ( GL_FRAMEBUFFER, offscreenBufferId );
    GLint setFrameBufferid = 0;
    glGetIntegerv ( GL_FRAMEBUFFER_BINDING, &setFrameBufferid );
//    glViewport ( 0, 0, (unsigned int)self.glkView.drawableWidth, (unsigned int)self.glkView.drawableHeight);
    glViewport ( 0, 0, width, heigh);
    
    // render
    // ------
    glClearColor(0.2f, 0.3f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // render container
    [_program use];
    glBindVertexArrayOES(VAO);
    //bind 了framebuffer后要记得绑过一次texture0；要跟对应着对应的framebuffer
    glBindTexture ( GL_TEXTURE_2D, texture0);
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    
    
    glBindFramebuffer ( GL_FRAMEBUFFER, defaultFramebuffer );
    glViewport ( 0, 0, (unsigned int)self.glkView.drawableWidth, (unsigned int)self.glkView.drawableHeight);
    
    // render
    // ------
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // render container
    [_screenProgram use];
    glBindVertexArrayOES(VAO);
    glActiveTexture ( GL_TEXTURE0 );
    glBindTexture ( GL_TEXTURE_2D, offscreenTextureId );
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}

#pragma mark - OpenGLContianerDelegate
- (void)setContianerFrame:(CGRect)rect{
    self.frame = rect;
    _glkView.frame = self.bounds;
}

- (void)openGLRender{
    [self buildProgram];
    
    [self setUpGLBuffers];
    [self setUpTexture];
    [self setupFramebuffer];
    
    [_glkView display];
}

- (void)displayingLinkDraw{
//    [_glkView display];
}

- (void)removeFromSuperContainer{
    [self removeFromSuperview];
    [_displayLink invalidate];
}

@end
