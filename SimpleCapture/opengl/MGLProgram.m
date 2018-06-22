//
//  MGLProgram.m
//  video
//
//  Created by bleach on 16/7/30.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import "MGLProgram.h"

@interface MGLProgram()

//直接使用数组的个数来绑定attribute的索引
@property (nonatomic, strong) NSMutableArray* attributes;
@property (nonatomic, assign) GLuint programId;
@property (nonatomic, assign) GLuint vertShader;
@property (nonatomic, assign) GLuint fragShader;

@end

@implementation MGLProgram

- (id)initWithVertexShaderString:(NSString *)vShaderString fragmentShaderString:(NSString *)fShaderString {
    if ((self = [super init])) {
        _initialized = NO;
        _attributes = [[NSMutableArray alloc] init];
        [self doInitProgram:vShaderString fragmentShaderString:fShaderString];
    }
    
    return self;
}

- (void)doInitProgram:(NSString *)vShaderString fragmentShaderString:(NSString *)fShaderString {
    do {
        _programId = glCreateProgram();
        
        GLenum err = glGetError();
        while (err != GL_NO_ERROR) {
           NSLog(@"GLError %s set in File:%s Line:%d\n _programId:%d\n",
                    GetGLErrorString(err), __FILE__, __LINE__, _programId);
            err = glGetError();
        }
        
        if (![self compileShader:&_vertShader type:GL_VERTEX_SHADER string:vShaderString]) {
           NSLog(@"Failed to compile vertex shader");
            break;
        }
        
        if (![self compileShader:&_fragShader type:GL_FRAGMENT_SHADER string:fShaderString]) {
           NSLog(@"Failed to compile fragment shader");
            break;
        }
        
        glAttachShader(_programId, _vertShader);
        glAttachShader(_programId, _fragShader);
        
        err = glGetError();
        while (err != GL_NO_ERROR) {
           NSLog(@"GLError %s set in File:%s Line:%d\n _vertShader:%d\n _fragShader:%d\n",
                    GetGLErrorString(err), __FILE__, __LINE__, _vertShader, _fragShader);
            err = glGetError();
        }
        
        return;
    } while (NO);
    
    [self deInit];
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type string:(NSString *)shaderString {
    GLint status = GL_FALSE;
    
    const GLchar* source = (GLchar *)[shaderString UTF8String];
    if (!source) {
       NSLog(@"Failed to load vertex shader");
        return status;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    
    if (status != GL_TRUE) {
        GLint logLength;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar *)malloc(logLength);
            glGetShaderInfoLog(*shader, logLength, &logLength, log);
            if (shader == &_vertShader) {
               NSLog(@"Vertex shader error log = %s", log);
            } else {
               NSLog(@"Fragment shader error log = %s", log);
            }
            
            free(log);
        }
    }
    
    return status == GL_TRUE;
}

- (void)dealloc {
}

#pragma mark - link program
- (BOOL)isProgramAvailable {
    return _initialized;
}

- (BOOL)link {
    GLint status = GL_FALSE;
    
    glLinkProgram(_programId);
    glGetProgramiv(_programId, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        GLint logLength;
        glGetProgramiv(_programId, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0)
        {
            GLchar *log = (GLchar *)malloc(logLength);
            glGetProgramInfoLog(_programId, logLength, &logLength, log);
           NSLog(@"Program link log = %s", log);
            free(log);
        }
        return NO;
    }
    
    if (_vertShader) {
        glDeleteShader(_vertShader);
        _vertShader = 0;
    }
    if (_fragShader) {
        glDeleteShader(_fragShader);
        _fragShader = 0;
    }
    
    _initialized = YES;
    
    return YES;
}

- (void)use {
    glUseProgram(_programId);
}

#pragma mark - attribute and uniform bind
- (void)addAttribute:(NSString *)attributeName {
    if (![_attributes containsObject:attributeName]) {
        [_attributes addObject:attributeName];
        glBindAttribLocation(_programId, (GLint)[_attributes indexOfObject:attributeName], [attributeName UTF8String]);
    }
}

- (GLint)attributeIndex:(NSString *)attributeName {
    return (GLint)[_attributes indexOfObject:attributeName];
}

- (GLint)uniformIndex:(NSString *)uniformName {
    return glGetUniformLocation(_programId, [uniformName UTF8String]);
}

- (void)deInit {
    if (_vertShader) {
        glDeleteShader(_vertShader);
        _vertShader = 0;
    }
    
    if (_fragShader) {
        glDeleteShader(_fragShader);
        _fragShader = 0;
    }
    
    if (_programId) {
        glDeleteProgram(_programId);
        _programId = 0;
    }
}

@end
