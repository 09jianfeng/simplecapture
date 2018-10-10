//
//  TextureGLKView.m
//  SimpleCapture
//
//  Created by JFChen on 2018/4/19.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>

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
 uniform vec2 vecSize;
 uniform mat2 upsidedown;
 vec2 mosaicSize = vec2(16,16);
 
 vec4 dip_filter(mat3 _filter, sampler2D _image, vec2 _xy, vec2 texSize)
 {
 
   mat3 _filter_pos_delta_x=mat3(vec3(-1.0, 0.0, 1.0), vec3(0.0, 0.0 ,1.0) ,vec3(1.0,0.0,1.0));
   mat3 _filter_pos_delta_y=mat3(vec3(-1.0,-1.0,-1.0),vec3(-1.0,0.0,0.0),vec3(-1.0,1.0,1.0));
   vec4 final_color = vec4(0.0, 0.0, 0.0, 0.0);
   for(int i = 0; i<3; i++)
   {
       for(int j = 0; j<3; j++)
       {
           vec2 _xy_new = vec2(_xy.x + _filter_pos_delta_x[i][j], _xy.y + _filter_pos_delta_y[i][j]);
           vec2 _uv_new = vec2(_xy_new.x/texSize.x, _xy_new.y/texSize.y);
           final_color += texture2D(_image,_uv_new) * _filter[i][j];
       }
   }
   return final_color;
 }
 
 vec4 xposure(vec4 _color, float gray, float ex)
 {
     float b = (4.0*ex - 1.0);
     float a = 1.0 - b;
     float f = gray*(a*gray + b);
     return f*_color;
 }

 // https://blog.csdn.net/neng18/article/details/38083987?utm_source=tuicool&utm_medium=referral 图像效果参考这个博客
 void main() {
     //跟颜色值混合
//     gl_FragColor = texture2D(texture, TexCoord) * vec4(outColor, 1.0);
     
     //正常显示
//     gl_FragColor = texture2D(texture, TexCoord).rgba;
     
     /*
     {//图像翻转
         vec2 vecImageSize = vecSize;
         vec2 posNew = vec2(vecImageSize.x - TexCoord.x,vecImageSize.y-TexCoord.y);
         vec3 irgb = texture2D(texture,posNew).rgb;
         gl_FragColor = vec4(irgb,1.0);
     }
      */
     
     /*
     {//矩阵图像翻转
         vec3 irgb = texture2D(texture,TexCoord * upsidedown).rgb;
         gl_FragColor = vec4(irgb,1.0);
     }
      */
     
     /*
     {//浮雕
        vec2 tex = TexCoord;
        vec2 upLeftUV = vec2(tex.x-1.0/vecSize.x,tex.y-1.0/vecSize.y);
        vec4 curColor = texture2D(texture,TexCoord);
        vec4 upLeftColor = texture2D(texture,upLeftUV);
        vec4 delColor = curColor - upLeftColor;
        float h = 0.3*delColor.x + 0.59*delColor.y + 0.11*delColor.z;
        vec4 bkColor = vec4(0.5, 0.5, 0.5, 1.0);
        gl_FragColor = vec4(h,h,h,0.0) +bkColor;
     }
      */
     
     /*
     {//马赛克
         vec2 intXY = vec2(TexCoord.x*vecSize.x, TexCoord.y*vecSize.y);
         vec2 XYMosaic = vec2(floor(intXY.x/mosaicSize.x)*mosaicSize.x,floor(intXY.y/mosaicSize.y)*mosaicSize.y);
         vec2 UVMosaic = vec2(XYMosaic.x/vecSize.x,XYMosaic.y/vecSize.y);
         vec4 baseMap = texture2D(texture,UVMosaic);
         gl_FragColor = baseMap;
     }*/
     
     
     /*
     {// 模糊
          vec2 intXY = vec2(TexCoord.x * vecSize.x, TexCoord.y * vecSize.y);
         //box 模糊
//          mat3 _smooth_fil = mat3(1.0/9.0,1.0/9.0,1.0/9.0,
//                                  1.0/9.0,1.0/9.0,1.0/9.0,
//                                  1.0/9.0,1.0/9.0,1.0/9.0);
         
         //拉普拉斯锐化
//         mat3 _smooth_fil = mat3(-1.0,-1.0,-1.0,
//                                 -1.0,9.0,-1.0,
//                                 -1.0,-1.0,-1.0);
         
         mat3 _smooth_fil = mat3(1.0/16.0,2.0/16.0,1.0/16.0,
                                 2.0/16.0,4.0/16.0,2.0/16.0,
                                 1.0/16.0,2.0/16.0,1.0/16.0);
          
          vec4 tmp = dip_filter(_smooth_fil, texture, intXY, vecSize);
          gl_FragColor = tmp;
     }*/
     
     /*
     {// 描边
         vec2 intXY = vec2(TexCoord.x * vecSize.x, TexCoord.y * vecSize.y);
         //box 模糊
         mat3 _smooth_fil = mat3(-0.5,-1.0,0.0,
                                 -1.0,0.0,1.0,
                                 0.0,1.0,0.5);
         vec4 delColor = dip_filter(_smooth_fil, texture, intXY, vecSize);
         float deltaGray = 0.3*delColor.x + 0.59*delColor.y + 0.11*delColor.z;
         if(deltaGray < 0.0) deltaGray = -1.0 * deltaGray;
         deltaGray = 1.0 - deltaGray;
         gl_FragColor = vec4(deltaGray,deltaGray,deltaGray,1.0);
     }*/
     
     /*
     {// HDR + Blow
         float k = 1.6;
         vec4 _dsColor = texture2D(texture, TexCoord);
         float _lum = 0.3*_dsColor.x + 0.59*_dsColor.y;
         vec4 _fColor = texture2D(texture, TexCoord);
         gl_FragColor = xposure(_fColor, _lum, k);
     }*/
     
     
     
 }
 );

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
    UISlider *_slider;
    uint32_t _imageWidth;
    uint32_t _imageHeigh;
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
