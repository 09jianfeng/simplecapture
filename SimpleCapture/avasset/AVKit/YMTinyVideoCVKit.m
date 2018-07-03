//
//  YMTinyVideoCVKit.m
//  yymediarecordersdk
//
//  Created by 吴顺 on 2018/6/13.
//  Copyright © 2018年 YY Inc. All rights reserved.
//

#import "YMTinyVideoCVKit.h"


@implementation YMTinyVideoCVKit

+ (UIImage *)UIImageFormPixelbuffer:(CVPixelBufferRef)buffer{
    
    CIImage* ciImage = [CIImage imageWithCVPixelBuffer:buffer];
    CIContext* context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer : @(YES)}];
    CGRect rect = CGRectMake(0, 0, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer));
    CGImageRef videoImage = [context createCGImage:ciImage fromRect:rect];
    
    UIImage* image = [UIImage imageWithCGImage:videoImage];
    CGImageRelease(videoImage);
    return image;
}

+ (CVPixelBufferRef)deepCopyPixelBuffer:(CVPixelBufferRef)srcPixelBuffer
{
    const void *keys[] = {
        kCVPixelBufferOpenGLESCompatibilityKey,
        kCVPixelBufferIOSurfacePropertiesKey,
    };
    
    const void *values[] = {
        (__bridge const void *)([NSNumber numberWithBool:YES]),
        (__bridge const void *)([NSDictionary dictionary])
    };
    
    OSType bufferPixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer);
    
    CFDictionaryRef optionsDictionary = CFDictionaryCreate(NULL, keys, values, 2, NULL, NULL);
    
    size_t width = CVPixelBufferGetWidth(srcPixelBuffer);
    size_t height = CVPixelBufferGetHeight(srcPixelBuffer);
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault,
                        width,
                        height,
                        bufferPixelFormat,
                        optionsDictionary,
                        &pixelBuffer);
    
    CFRelease(optionsDictionary);
    
    if (pixelBuffer) {
        Boolean isPlanar = CVPixelBufferIsPlanar(srcPixelBuffer);
        size_t planeCount = CVPixelBufferGetPlaneCount(srcPixelBuffer);
        
        CVPixelBufferLockBaseAddress(srcPixelBuffer, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        if (!isPlanar) {
            void * src = CVPixelBufferGetBaseAddress(srcPixelBuffer);
            void * dst = CVPixelBufferGetBaseAddress(pixelBuffer);
            size_t bytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer);
            
            memcpy(dst, src, bytesPerRow*height);
        } else {
            for (size_t plane = 0; plane < planeCount; plane++) {
                void * src = CVPixelBufferGetBaseAddressOfPlane(srcPixelBuffer, plane);
                void * dst = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane);
                size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(srcPixelBuffer, plane);
                size_t planeHeight = CVPixelBufferGetHeightOfPlane(srcPixelBuffer, plane);
                
                memcpy(dst, src, bytesPerRow*planeHeight);
            }
        }
        CVPixelBufferUnlockBaseAddress(srcPixelBuffer, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    
    return pixelBuffer;
}


@end
