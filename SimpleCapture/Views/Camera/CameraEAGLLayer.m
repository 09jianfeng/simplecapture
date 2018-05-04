//
//  CameraEAGLLayer.m
//  SimpleCapture
//
//  Created by JFChen on 2018/3/23.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "CameraEAGLLayer.h"
#import <UIKit/UIKit.h>
#include <OpenGLES/EAGL.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#import "GLProgram.h"

#define STRINGIZE(x) #x
#define SHADER_STRING(text) @ STRINGIZE(text)


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

 NSString *const kMRGBAFragmentShaderString = SHADER_STRING
 (
 //指明精度
 precision mediump float;
 varying mediump vec2 TexCoord;
 
 // texture samplers
 uniform sampler2D texture1;
 uniform sampler2D texture2;
 
 void main() {
//     gl_FragColor = mix(texture(texture1, TexCoord), texture(texture2, TexCoord), 0.2);
     gl_FragColor = texture2D(texture2, TexCoord);
 }
 );

/*
NSString *const kMRGBAFragmentShaderString = SHADER_STRING
(
 precision mediump float;
 varying mediump vec2 vTextureCoordinate;
 uniform sampler2D uSampler;
 
 void main() {
     vec4 textureColor = texture2D(uSampler, vTextureCoordinate);
     gl_FragColor = textureColor;
 }
 );
*/

 NSString * const kMBaseVertexShaderString = SHADER_STRING
 (
  attribute vec3 aPos;
  attribute vec2 aTextCoord;
 
  varying vec2 TexCoord;
 
  uniform mat4 model;
  uniform mat4 view;
  uniform mat4 projection;
 
  void main() {
     gl_Position = projection * view * model * vec4(aPos,1.0);
      TexCoord = aTextCoord.xy;
  }
 );

@interface CameraEAGLLayer()
@property GLuint myProgram;
@end

@implementation CameraEAGLLayer{
    EAGLContext *_context;
    UIImage *_faceImage;
    UIImage *_continer;
    NSString *_fsPath;
    NSString *_vsPath;
    
    GLProgram *_program;
    CADisplayLink *_displayLink;
    GLint uniforms[NUM_UNIFORMS];
}

- (instancetype)init{
    self = [super init];
    if (self) {
        CGFloat scale = [[UIScreen mainScreen] scale];
        self.contentsScale = scale;
        
        self.opaque = TRUE;
        self.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:YES]};
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _faceImage = [UIImage imageNamed:@"awesomeface.png"];
        _continer = [UIImage imageNamed:@"container.jpg"];
        
        _fsPath = [[NSBundle mainBundle] pathForResource:@"camera" ofType:@"fs"];
        _vsPath = [[NSBundle mainBundle] pathForResource:@"camera" ofType:@"vs"];
        
        [self setUpGL];
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self
                                                   selector:@selector(draw)];
        _displayLink.frameInterval = 2;
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)setUpGL{
    [EAGLContext setCurrentContext:_context];
    _program = [[GLProgram alloc] initWithVertexShaderString:kMBaseVertexShaderString fragmentShaderString:kMRGBAFragmentShaderString];
}

- (void)draw{
    [EAGLContext setCurrentContext:_context];
    
    float vertices[] = {
        -0.5f, -0.5f, -0.5f,  0.0f, 0.0f,
        0.5f, -0.5f, -0.5f,  1.0f, 0.0f,
        0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
        0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
        -0.5f,  0.5f, -0.5f,  0.0f, 1.0f,
        -0.5f, -0.5f, -0.5f,  0.0f, 0.0f,
        
        -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
        0.5f, -0.5f,  0.5f,  1.0f, 0.0f,
        0.5f,  0.5f,  0.5f,  1.0f, 1.0f,
        0.5f,  0.5f,  0.5f,  1.0f, 1.0f,
        -0.5f,  0.5f,  0.5f,  0.0f, 1.0f,
        -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
        
        -0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
        -0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
        -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
        -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
        -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
        -0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
        
        0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
        0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
        0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
        0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
        0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
        0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
        
        -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
        0.5f, -0.5f, -0.5f,  1.0f, 1.0f,
        0.5f, -0.5f,  0.5f,  1.0f, 0.0f,
        0.5f, -0.5f,  0.5f,  1.0f, 0.0f,
        -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
        -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
        
        -0.5f,  0.5f, -0.5f,  0.0f, 1.0f,
        0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
        0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
        0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
        -0.5f,  0.5f,  0.5f,  0.0f, 0.0f,
        -0.5f,  0.5f, -0.5f,  0.0f, 1.0f
    };
    
    unsigned int VBO, VAO;
    glGenVertexArraysOES(1, &VAO);
    glBindVertexArrayOES(VAO);

    glGenBuffers(1, &VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    // position attribute
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    // texture coord attribute
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);
    
    // load and create a texture
    // -------------------------
    unsigned int texture1;
    // texture 1
    // ---------
    glGenTextures(1, &texture1);
    glBindTexture(GL_TEXTURE_2D, texture1);
    // set the texture wrapping parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    // set texture filtering parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //create texture
    UIImage* image = _faceImage;
    if (image == nil)
        NSLog(@"Do real error checking here");
    
    int width = (int)CGImageGetWidth(image.CGImage);
    int height = (int)CGImageGetHeight(image.CGImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc( height * width * 4 );
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, 4 * width,
                                                 colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease( colorSpace);
    CGContextClearRect( context, CGRectMake( 0, 0, width, height ));
    CGContextTranslateCTM( context, 0, height - height );
    CGContextDrawImage( context, CGRectMake( 0, 0, width, height ), image.CGImage );
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, imageData);
    glGenerateMipmap(GL_TEXTURE_2D);

    CGContextRelease(context);
    free(imageData);
}

@end
