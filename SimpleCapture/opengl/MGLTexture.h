//
//  MGLTexture.h
//  video
//
//  Created by bleach on 16/7/29.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "MGLCommon.h"



@interface MGLImageFrameItem : NSObject

@property (nonatomic, assign) GLuint textureId;

- (void)decodeTexture:(UIImage *)image;

- (void)deInit;

@end

/* 管理纹理,但是只针对一个,如果像YUV那种,可以使用里面的cache,在各自的filter里自己处理 */
@interface MGLTexture : NSObject

@property (nonatomic, assign) GLuint bindTexture;

- (id)initNormalTexture:(BOOL)normalTexture;

- (id)initWithOptions:(MGLTextureOptions)fboTextureOptions normalTexture:(BOOL)normalTexture;

- (void)updateTextureWithUIImage:(UIImage *)image;

- (void)updateTextureWithImageData:(MImageData *)cacheImageData;

- (CVOpenGLESTextureCacheRef)textureCache;

- (void)deInit;

@end
