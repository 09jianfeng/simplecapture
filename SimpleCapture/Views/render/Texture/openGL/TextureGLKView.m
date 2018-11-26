//
//  TextureGLKView.m
//  SimpleCapture
//
//  Created by JFChen on 2018/4/19.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TextureGLKViewShader.h"
#import "TextureGLKView.h"
#import "GLProgram.h"
#import "MGLCommon.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <GLKit/GLKit.h>

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
    
    UISlider *_beautySlider;
    float _beautyLevel;
    UISlider *_toneSlider;
    float _toneLevel;
    UISlider *_brightSlider;
    float _brightLevel;
    UISlider *_offsetSlider;
    float _texelOffset;
    
    int _paramsLocation;
    int _brightnessLocation;
    int _singleStepOffsetLocation;
    int _texelWidthLocation;
    int _texelHeightLocation;
    
    uint32_t _imageWidth;
    uint32_t _imageHeigh;
}

- (void)dealloc{
    glDeleteBuffers(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    NSLog(@"textureglkview dealloc");
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    for (int tag = 1; tag < 5; tag++) {
        UISlider *slider = [self viewWithTag:tag];
        slider.frame = CGRectMake(0, self.frame.size.height - tag * 30, self.frame.size.width, 30);
    }
}

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self){
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        [EAGLContext setCurrentContext:_context];

        _glkView = [[GLKView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetWidth(self.bounds))];
        _glkView.delegate = self;
        _glkView.context = _context;
        _glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
        _glkView.enableSetNeedsDisplay = NO;
        [self addSubview:_glkView];
        
        [self initOpenGL];
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayingLinkDraw)];
        _displayLink.frameInterval = 2.0;
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        _beautySlider = [[UISlider alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(frame) - 50, CGRectGetWidth(frame), 30)];
        _beautySlider.maximumValue = 2.5;
        _beautySlider.minimumValue = 0;
        _beautySlider.value = 1.0;
        _beautySlider.tag = 1;
        [_beautySlider addTarget:self action:@selector(sliderValueDidChage:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_beautySlider];
        
        _toneSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(frame) - 50, CGRectGetWidth(frame), 30)];
        _toneSlider.maximumValue = 5;
        _toneSlider.minimumValue = -5;
        _toneSlider.value = 0.0;
        _toneSlider.tag = 2;
        [_toneSlider addTarget:self action:@selector(sliderValueDidChage:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_toneSlider];
        
        _brightSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(frame) - 50, CGRectGetWidth(frame), 30)];
        _brightSlider.maximumValue = 1;
        _brightSlider.minimumValue = 0;
        _brightSlider.value = 0.5;
        _brightSlider.tag = 3;
        [_brightSlider addTarget:self action:@selector(sliderValueDidChage:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_brightSlider];
        
        _offsetSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(frame) - 50, CGRectGetWidth(frame), 30)];
        _offsetSlider.maximumValue = 10;
        _offsetSlider.minimumValue = -10;
        _offsetSlider.value = 0.5;
        _offsetSlider.tag = 4;
        [_offsetSlider addTarget:self action:@selector(sliderValueDidChage:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_offsetSlider];

    }
    return self;
}

- (void)sliderValueDidChage:(id)sender{
    UISlider *slider = (UISlider *)sender;
    switch (slider.tag) {
        case 1:
            [self setBeautyLevel:slider.value];
            break;
        case 2:
            [self setToneLevel:slider.value];
            break;
        case 3:
            [self setBrightLevel:slider.value];
            break;
        case 4:
            [self setTexelOffset:slider.value];
            break;
            
        default:
            break;
    }
}

- (void)setParams:(float)beauty tone:(float)tone{
    _beautyLevel=beauty;
    _toneLevel = tone;
    float vector[4];
    vector[0] = 1.0f - 0.6f * beauty;
    vector[1] = 1.0f - 0.3f * beauty;
    vector[2] = 0.1f + 0.3f * tone;
    vector[3] = 0.1f + 0.3f * tone;
//    glUniformMatrix2fv([_program uniformIndex:@"params"], 1, GL_FALSE, vector);
    glUniform4f([_program uniformIndex:@"params"], vector[0],  vector[1],  vector[2],  vector[3]);
}

-(void)setTexelOffset:(float)texelOffset{
    _texelOffset = texelOffset;
    glUniform1f([_program uniformIndex:@"texelWidthOffset"], texelOffset/_imageWidth);
    glUniform1f([_program uniformIndex:@"texelHeightOffset"], texelOffset/_imageHeigh);
}

-(void)setToneLevel:(float)toneLeve{
    _toneLevel = toneLeve;
    [self setParams:_beautyLevel tone:_toneLevel];
}

-(void)setBeautyLevel:(float)beautyLeve {
    _beautyLevel = beautyLeve;
    [self setParams:_beautyLevel tone:_toneLevel];
}

-(void)setBrightLevel:(float)brightLevel {
    _brightLevel = brightLevel;
    glUniform1f([_program uniformIndex:@"brightness"], 0.6f * (-0.5f + brightLevel));
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
    glUniform1f([_program uniformIndex:@"sliderValue"], _beautySlider.value);
    glUniform2f([_program uniformIndex:@"vecSize"], _imageWidth, _imageHeigh);
    GLfloat upsidedownmat[] = {1.0,0.0,0.0,-1.0};
    glUniformMatrix2fv([_program uniformIndex:@"upsidedown"], 1, GL_FALSE, upsidedownmat);
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
    _imageWidth = imageData->width;
    _imageHeigh = imageData->height;
    {//用glTexImage2D给纹理赋值
        //https://stackoverflow.com/questions/12428108/ios-how-to-draw-a-yuv-image-using-opengl glteximage2D	 yuv
        glTexImage2D(GL_TEXTURE_2D, 0, imageData->format, (GLint)imageData->width, (GLint)imageData->height, 0, imageData->format, imageData->type,imageData->data);
    }
    
    /*
    int width = [self suggestTexSize:imageData->width];
    int heigh = [self suggestTexSize:imageData->height];
    
    //glTexImage2D的宽高必须是2的N次幂才能创建成功,如果是非2次幂的，就要先用glTexImage2D创建一个2次幂函的空纹理，然后用gltexsubimage2d来给这个纹理的部分附值。如果要铺平，就修改纹理坐标。这里就不赘述了
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
    _glkView.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetWidth(self.bounds));
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
