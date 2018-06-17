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

/*
 * UIImage to yuv420f nv12格式。
 */
CVPixelBufferRef imageToYUVPixelBuffer(UIImage *image){
    // convert to CGImage & dump to bitmapData
    
    CGImageRef imageRef = [image CGImage];
    int width  = (int)CGImageGetWidth(imageRef);
    int height = (int)CGImageGetHeight(imageRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = ((bytesPerPixel*width+255)/256)*256;
    NSUInteger bitsPerComponent = 8;
    GLubyte* bitmapData = (GLubyte *)malloc(bytesPerRow*height); // if 4 components per pixel (RGBA)
    CGContextRef context = CGBitmapContextCreate(bitmapData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    // 创建YUV pixelbuffer
    
    CVPixelBufferRef yuvPixelBuffer;
    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, (void*)[NSDictionary dictionary]);
    CFDictionarySetValue(attrs, kCVPixelBufferOpenGLESCompatibilityKey, (void*)[NSNumber numberWithBool:YES]);
    
    ////420YpCbCr8BiPlanar是半 plannar
    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, (int)image.size.width, (int)image.size.height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs, &yuvPixelBuffer);
    if (err) {
        return NULL;
    }
    CFRelease(attrs);
    
    CVPixelBufferLockBaseAddress(yuvPixelBuffer, 0);
    
    uint8_t * yPtr = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(yuvPixelBuffer, 0);
    size_t strideY = CVPixelBufferGetBytesPerRowOfPlane(yuvPixelBuffer, 0);
    
    uint8_t * uvPtr = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(yuvPixelBuffer, 1);
    size_t strideUV = CVPixelBufferGetBytesPerRowOfPlane(yuvPixelBuffer, 1);
    
    for (int j = 0; j < image.size.height; j++) {
        for (int i = 0; i < image.size.width; i++) {
            float r  = bitmapData[j*bytesPerRow + i*4 + 0];
            float g  = bitmapData[j*bytesPerRow + i*4 + 1];
            float b  = bitmapData[j*bytesPerRow + i*4 + 2];
            
            int16_t y = (0.257*r + 0.504*g + 0.098*b) + 16;
            if (y > 255) {
                y = 255;
            } else if (y < 0) {
                y = 0;
            }
            
            yPtr[j*strideY + i] = (uint8_t)y;
        }
    }
    
    for (int j = 0; j < image.size.height/2; j++) {
        for (int i = 0; i < image.size.width/2; i++) {
            float r  = bitmapData[j*2*bytesPerRow + i*2*4 + 0];
            float g  = bitmapData[j*2*bytesPerRow + i*2*4 + 1];
            float b  = bitmapData[j*2*bytesPerRow + i*2*4 + 2];
            
            int16_t u = (-0.148*r - 0.291*g + 0.439*b) + 128;
            int16_t v = (0.439*r - 0.368*g - 0.071*b) + 128;
            
            if (u > 255) {
                u = 255;
            } else if (u < 0) {
                u = 0;
            }
            
            if (v > 255) {
                v = 255;
            } else if (v < 0) {
                v = 0;
            }
            
            uvPtr[j*strideUV + i*2 + 0] = (uint8_t)u;
            uvPtr[j*strideUV + i*2 + 1] = (uint8_t)v;
        }
    }
    
    free(bitmapData);
    CVPixelBufferUnlockBaseAddress(yuvPixelBuffer, 0);
    
    return yuvPixelBuffer;
}

CVPixelBufferRef pixelBufferFromCGImage(UIImage *image)
{
    CGImageRef ciImage = [image CGImage];
    
    CGSize frameSize = CGSizeMake(CGImageGetWidth(ciImage), CGImageGetHeight(ciImage));
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width, frameSize.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options, &pxbuffer);
    if(status != 0){
        NSLog(@"status is not 0, status:%d",status);
    }
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void* pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width, frameSize.height, 8, 4 * frameSize.width, rgbColorSpace, kCGImageAlphaNoneSkipLast);
    
    CGContextTranslateCTM(context, 0, frameSize.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(ciImage), CGImageGetHeight(ciImage)), ciImage);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

CVPixelBufferRef pixelBufferFromCGImageFaster(UIImage *image){
    CGImageRef cgImage = [image CGImage];
    CVPixelBufferRef pxbuffer = NULL;
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    size_t width =  CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    size_t bytesPerRow = CGImageGetBytesPerRow(cgImage);
    
    CFDataRef dataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    GLubyte* imageData = (GLubyte *)CFDataGetBytePtr(dataFromImageDataProvider);
    
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, imageData,bytesPerRow, NULL, NULL, (__bridge CFDictionaryRef)options, &pxbuffer);
    
    CFRelease(dataFromImageDataProvider);
    
    return pxbuffer;
}
