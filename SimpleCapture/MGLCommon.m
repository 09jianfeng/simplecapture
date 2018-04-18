//
//  MGLCommon.m
//  video
//
//  Created by bleach on 16/7/29.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import "MGLCommon.h"

void mglRunAsyncOnMainQueueWithoutDeadlocking(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

MImageData* mglImageDataFromUIImage(UIImage* uiImage, BOOL flipVertical) {
    CGImageRef cgImage = uiImage.CGImage;
    if (!cgImage) {
        return NULL;
    }
    return mglImageDataFromCGImage(cgImage, flipVertical);
}

MImageData* mglImageDataFromCGImage(CGImageRef cgImage, BOOL flipVertical) {
    CGFloat scale = [[UIScreen mainScreen] scale] > 2.0f ? 2.0f : [[UIScreen mainScreen] scale];
    GLuint width = (GLuint)CGImageGetWidth(cgImage) * scale;
    GLuint height = (GLuint)CGImageGetHeight(cgImage) * scale;
    
    MImageData* imageData = (MImageData *)malloc(sizeof(MImageData));
    imageData->width = width;
    imageData->height = height;
    imageData->rowByteSize = width * 4;
    imageData->data = (GLubyte *)malloc(height * imageData->rowByteSize);
    imageData->format = GL_RGBA;
    imageData->type = GL_UNSIGNED_BYTE;
    
    CGContextRef context = CGBitmapContextCreate(imageData->data, imageData->width, imageData->height, 8, imageData->rowByteSize, CGImageGetColorSpace(cgImage), kCGBitmapAlphaInfoMask & kCGImageAlphaNoneSkipLast);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    if (flipVertical) {
        CGContextTranslateCTM(context, 0.0f, imageData->height);
        CGContextScaleCTM(context, 1.0, -1.0);
    }
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, imageData->width, imageData->height), cgImage);
    CGContextRelease(context);
    
    if (NULL == imageData->data) {
        mglDestroyImageData(imageData);
        return NULL;
    }
    
    return imageData;
}

void mglDestroyImageData(MImageData* imageData) {
    if (imageData == NULL) {
        return;
    }
    free(imageData->data);
    imageData->data = NULL;
    free(imageData);
    imageData = NULL;
}
