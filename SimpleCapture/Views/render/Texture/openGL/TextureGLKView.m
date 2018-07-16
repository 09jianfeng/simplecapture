//
//  TextureGLKView.m
//  SimpleCapture
//
//  Created by JFChen on 2018/4/19.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "TextureGLKView.h"
#import "GLProgram.h"
#import "MGLCommon.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
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
 
 uniform float sliderValue;
 
 void main() {
     //从纹理texture中采样纹理
//     gl_FragColor = texture2D(texture, TexCoord) * vec4(outColor, 1.0);
     gl_FragColor = texture2D(texture, TexCoord).rgba;
 }
 );

@interface TextureGLKView()<GLKViewDelegate>
@property (nonatomic, strong) GLKView *glkView;
@property (nonatomic, strong) EAGLContext *context;
@end

@implementation TextureGLKView{
    GLProgram *_program;
    
    GLuint aPos;
    GLuint aTextCoord;
    GLuint acolor;
    GLuint VAO,VBO,EBO;
    GLuint texture0;
    
    CADisplayLink *_displayLink;
    UISlider *_slider;
}

- (void)dealloc{
    glDeleteBuffers(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    NSLog(@"textureglkview dealloc");
}

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self){
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        [EAGLContext setCurrentContext:_context];

        _glkView = [[GLKView alloc] initWithFrame:self.bounds];
        _glkView.delegate = self;
        _glkView.context = _context;
        _glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
        _glkView.enableSetNeedsDisplay = NO;
        [self addSubview:_glkView];
        
        [self initOpenGL];
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayingLinkDraw)];
        _displayLink.frameInterval = 2.0;
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        _slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(frame), 50)];
        _slider.maximumValue = 100;
        _slider.minimumValue = 0;
        _slider.value = 50;
        [_slider addTarget:self action:@selector(sliderValueDidChage:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_slider];
    }
    return self;
}

- (void)sliderValueDidChage:(id)sender{
    
}

- (void)initOpenGL{
    [self buildProgram];
    [self setUpGLBuffers];
    [self setUpTexture];
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
}

- (void)updateUniformValue{
    glUniform1f([_program uniformIndex:@"sliderValue"], _slider.value);
}

- (void)setUpGLBuffers{
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
    glVertexAttribPointer(aPos, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(aPos);
    
    // color attribute
    glVertexAttribPointer(acolor, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(acolor);
    
    // texture coord attribute
    glVertexAttribPointer(aTextCoord, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
    glEnableVertexAttribArray(aTextCoord);
}

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
//    UIImage *image = [UIImage imageNamed:@"humantest.jpeg"];
    UIImage *image = [UIImage imageNamed:@"humantest.jpg"];
    MImageData* imageData = mglImageDataFromUIImage(image, YES);
    glTexImage2D(GL_TEXTURE_2D, 0, imageData->format, (GLint)imageData->width, (GLint)imageData->height, 0, imageData->format, imageData->type,imageData->data);
    
    /*
    int width = [self suggestTexSize:imageData->width];
    int heigh = [self suggestTexSize:imageData->height];
    
    //宽高必须是2的N次幂,如果是非2次幂的，就要先用glTexImage2D创建一个2次幂函的空纹理，然后用gltexsubimage2d来给这个纹理的部分附值。如果要铺平，就修改纹理坐标。这里就不赘述了
    glTexImage2D(GL_TEXTURE_2D, 0, imageData->format, (GLint)width, (GLint)heigh, 0, imageData->format, imageData->type,NULL);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, imageData->width, imageData->height, imageData->format, imageData->type, imageData->data);
    */
     
    glGetError();
    glGenerateMipmap(GL_TEXTURE_2D);
    mglDestroyImageData(imageData);
    
}

//拿到最接近2的N次幂的一个值
- (int)suggestTexSize:(int)size
{
    int texSize = 1;
    while(true)
    {
        texSize <<= 1;
        if(texSize >= size)
            break ;
    }
    return texSize;
}



#pragma mark - GLKViewDelegate
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    [EAGLContext setCurrentContext:_context];
    // render
    // ------
    glClearColor(0.2f, 0.3f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // render container
    [_program use];
    [self updateUniformValue];
    glBindVertexArrayOES(VAO);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}

#pragma mark - OpenGLContianerDelegate
- (void)setContianerFrame:(CGRect)rect{
    self.frame = rect;
    _glkView.frame = self.bounds;
}

- (void)openGLRender{
    [_glkView display];
}

- (void)displayingLinkDraw{
    [_glkView display];
}

- (void)removeFromSuperContainer{
    [self removeFromSuperview];
    [_displayLink invalidate];
}

@end
