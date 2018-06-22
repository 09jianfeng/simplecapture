//
//  MGLTexture.m
//  video
//
//  Created by bleach on 16/7/29.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import "MGLTexture.h"
#import "MGLTools.h"

@implementation MGLImageFrameItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _textureId = 0;
    }
    
    return self;
}

- (void)dealloc {
    
}

- (void)decodeTexture:(UIImage *)image {
    MImageData * imageData = mglImageDataFromUIImage(image, YES);
    
    glGenTextures(1, &_textureId);
    glBindTexture(GL_TEXTURE_2D, _textureId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, imageData->format, (GLint)imageData->width, (GLint)imageData->height, 0, imageData->format, imageData->type, imageData->data);
    
    GetGLError()
    
    mglDestroyImageData(imageData);
}

- (void)deInit {
    if (_textureId != 0) {
        glDeleteTextures(1, &_textureId);
        _textureId = 0;
    }
}

@end

@interface MGLTexture()
//纹理设置
@property (nonatomic, assign) MGLTextureOptions textureOptions;
//是否强制不使用fastTexture
@property (nonatomic, assign) BOOL normalTexture;
//用于纹理
@property (nonatomic, assign) CGSize textureSize;

@end

@implementation MGLTexture {
    MImageData* _imageData;
    CVOpenGLESTextureCacheRef _textureCache;
}

- (id)initNormalTexture:(BOOL)normalTexture {
    MGLTextureOptions defaultTextureOptions;
    defaultTextureOptions.minFilter = GL_LINEAR;
    defaultTextureOptions.magFilter = GL_LINEAR;
    defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.internalFormat = GL_RGBA;
    defaultTextureOptions.format = GL_RGBA;
    defaultTextureOptions.type = GL_UNSIGNED_BYTE;
    
    if (!(self = [self initWithOptions:defaultTextureOptions normalTexture:normalTexture])) {
        return nil;
    }
    
    return self;
}

- (id)initWithOptions:(MGLTextureOptions)fboTextureOptions normalTexture:(BOOL)normalTexture {
    if (!(self = [super init])) {
        return nil;
    }
    
    _textureOptions = fboTextureOptions;
    _normalTexture = normalTexture;
    
    if ([MGLTools supportsFastTextureUpload] && !normalTexture) {
        [self generateFastTexture];
    } else {
        [self generateTexture];
    }
    return self;
}

- (void)generateTexture {
    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &_bindTexture);
    glBindTexture(GL_TEXTURE_2D, _bindTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, _textureOptions.minFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, _textureOptions.magFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);
}

- (void)generateFastTexture {
    do {
        EAGLContext* glContext = [EAGLContext currentContext];
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, glContext, NULL, &_textureCache);
        if (err) {
            //[YYLogger info:TPreProcess message:@"GenerateFastTexture cache error!"];
            break;
        }
        return;
    } while (false);
    
    [self deInit];
}

- (void)deInit {
    if ([MGLTools supportsFastTextureUpload] && !_normalTexture) {
        if (_textureCache) {
            CFRelease(_textureCache);
            _textureCache = NULL;
        }
    } else {
        glDeleteTextures(1, &_bindTexture);
        _bindTexture = 0;
    }
    
    if (_imageData != NULL) {
        mglDestroyImageData(_imageData);
        _imageData = NULL;
    }
}

- (GLuint)bindTexture {
    return _bindTexture;
}

- (CVOpenGLESTextureCacheRef)textureCache {
    return _textureCache;
}

- (void)updateTextureWithUIImage:(UIImage *)image {
    @autoreleasepool {
        if (!_normalTexture) {
            NSLog(@"Error updateTextureWithUIImage");
            return;
        }
        if (_imageData != NULL) {
            mglDestroyImageData(_imageData);
            _imageData = NULL;
        }
        
        _imageData = mglImageDataFromUIImage(image, YES);
        
        glActiveTexture(GL_TEXTURE0);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        glBindTexture(GL_TEXTURE_2D, _bindTexture);
        if (_textureSize.width != _imageData->width || _textureSize.height != _imageData->height) {
            glTexImage2D(GL_TEXTURE_2D, 0, _imageData->format, (GLint)_imageData->width, (GLint)_imageData->height, 0, _imageData->format, _imageData->type, _imageData->data);
            _textureSize.width = _imageData->width;
            _textureSize.height = _imageData->height;
        } else {
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, (GLint)_imageData->width, (GLint)_imageData->height, _imageData->format, _imageData->type, _imageData->data);
        }
        if (_imageData != NULL) {
            mglDestroyImageData(_imageData);
            _imageData = NULL;
        }
        if (!_normalTexture) {
            //[YYLogger info:TPreProcess message:@"Error updateTextureWithUIImage"];
            return;
        }
    }
}

- (void)updateTextureWithImageData:(MImageData *)cacheImageData {
    if (!_normalTexture) {
        //[YYLogger info:TPreProcess message:@"Error updateTextureWithUIImage"];
        return;
    }
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _bindTexture);
    if (_textureSize.width != cacheImageData->width || _textureSize.height != cacheImageData->height) {
        glTexImage2D(GL_TEXTURE_2D, 0, cacheImageData->format, (GLint)cacheImageData->width, (GLint)cacheImageData->height, 0, cacheImageData->format, cacheImageData->type, cacheImageData->data);
        _textureSize.width = cacheImageData->width;
        _textureSize.height = cacheImageData->height;
    } else {
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, (GLint)cacheImageData->width, (GLint)cacheImageData->height, cacheImageData->format, cacheImageData->type, cacheImageData->data);
    }
}

@end
