//
//  PixelBufferConvertTool.m
//  yyvideolib
//
//  Created by YYInc on 2017/11/25.
//  Copyright © 2017年 yy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Accelerate/Accelerate.h>
#import "PixelBufferConvertTool.h"

struct TemporaryBuffer
{
    uint8_t * bufferPointer;
    unsigned long height;
    unsigned long width;
    long length;
};

@interface PixelBufferConvertTool()
{
    vImage_YpCbCrToARGB *_conversionInfo;
    TemporaryBuffer *tempBufferWhenCreatePixelBuffer;
    TemporaryBuffer *tempBufferWhenRotatePixelBuffer;
}
@end

@implementation PixelBufferConvertTool

- (void)dealloc
{
    [self deleteTemporaryBuffer:&tempBufferWhenRotatePixelBuffer];
    [self deleteTemporaryBuffer:&tempBufferWhenCreatePixelBuffer];
    
    if (_conversionInfo)
    {
        free(_conversionInfo);
    }
}

- (CVPixelBufferRef) createPixelBuffer:(uint8_t*)buffer BufferFormat:(YVLVideoPixelFormat)format Width:(int)width Height:(int)height
{
    if (buffer == NULL)
    {
        return NULL;
    }
    
    NSDictionary* option = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                            [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                            [NSNumber numberWithBool:YES], kCVPixelBufferOpenGLESCompatibilityKey,
                            @{}, kCVPixelBufferIOSurfacePropertiesKey,
                            @(16), kCVPixelBufferBytesPerRowAlignmentKey,
                            nil];
    
    int alignWidth = width + (16 - width%16);
    
    CVPixelBufferRef pixelBuffer = NULL;
    
    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)option, &pixelBuffer);
    
    if (err)
    {
        NSLog(@"create pixelbuffer failed. format:%d, w:%d, h:%d", format, width, height);
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    {
        if (format == kVLVideoPixelFormat_I420)
        {
            // I420
            vImage_Buffer srcYp;
            srcYp.data = buffer;
            srcYp.width = width;
            srcYp.height = height;
            srcYp.rowBytes = width;
            
            vImage_Buffer srcCb;
            srcCb.data = buffer + width * height;
            srcCb.width = width / 2;
            srcCb.height = height / 2;
            srcCb.rowBytes = width / 2;
            
            vImage_Buffer srcCr;
            srcCr.data = buffer + width * height + width * height / 4;
            srcCr.width = width / 2;
            srcCr.height = height / 2;
            srcCr.rowBytes = width / 2;
            
            uint8_t * baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
            unsigned long bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            vImage_Buffer dest;
            dest.data = baseAddress;
            dest.width = width;
            dest.height = height;
            dest.rowBytes = bytesPerRow;
            
            vImage_Error result = [self prepareForAccelerateConversion];
            uint8_t permuteMap[4] = {3, 2, 1, 0};
            result = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&srcYp, &srcCb, &srcCr, &dest, _conversionInfo, permuteMap, 255, kvImageNoFlags);
        }
        else if (format == kVLVideoPixelFormat_BGRA)
        {
            // BGRA
            if (width == alignWidth)
            {
                uint8_t * baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
                memcpy(baseAddress, buffer, 4 * width * height);
            }
            else
            {
                vImage_Buffer srcImageBuffer;
                srcImageBuffer.data = buffer;
                srcImageBuffer.width = width;
                srcImageBuffer.height = height;
                srcImageBuffer.rowBytes = width * 4;
                
                uint8_t * baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
                unsigned long bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
                vImage_Buffer dstImageBuffer;
                dstImageBuffer.data = baseAddress;
                dstImageBuffer.width = width;
                dstImageBuffer.height = height;
                dstImageBuffer.rowBytes = bytesPerRow;
                
                Pixel_8888 backgroundColor = {0,0,0,0};
                if (tempBufferWhenCreatePixelBuffer == NULL)
                {
                    long length = vImageRotate_ARGB8888(&srcImageBuffer, &dstImageBuffer, nil, 0, backgroundColor, kvImageGetTempBufferSize);
                    if (length)
                    {
                        [self createTemporaryBuffer:&tempBufferWhenCreatePixelBuffer Width:width Height:height Length:length];
                        NSLog(@"malloc temp create buffer : %ld", length);
                    }
                }
                vImageRotate_ARGB8888(&srcImageBuffer, &dstImageBuffer, tempBufferWhenCreatePixelBuffer->bufferPointer, 0, backgroundColor, kvImageBackgroundColorFill);
            }
        }
        else if (format == kVLVideoPixelFormat_NV12)
        {
            // NV12
            vImage_Buffer srcYp;
            srcYp.data = buffer;
            srcYp.width = width;
            srcYp.height = height;
            srcYp.rowBytes = width;
            
            vImage_Buffer srcCb;
            srcCb.data = buffer + width * height;
            srcCb.width = width;
            srcCb.height = height / 2;
            srcCb.rowBytes = width;
            
            uint8_t * baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
            unsigned long bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            vImage_Buffer dest;
            dest.data = baseAddress;
            dest.width = width;
            dest.height = height;
            dest.rowBytes = bytesPerRow;
            
            vImage_Error result = [self prepareForAccelerateConversion];
            uint8_t permuteMap[4] = {3, 2, 1, 0};
            result = vImageConvert_420Yp8_CbCr8ToARGB8888(&srcYp, &srcCb, &dest, _conversionInfo, permuteMap, 255, kvImageNoFlags);
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

- (vImage_Error)prepareForAccelerateConversion
{
    // Setup the YpCbCr to ARGB conversion.
    
    if (_conversionInfo != NULL) {
        return kvImageNoError;
    }
    
    vImage_YpCbCrPixelRange pixelRange = { 0, 128, 255, 255, 255, 1, 255, 0 };
    //    vImage_YpCbCrPixelRange pixelRange = { 16, 128, 235, 240, 255, 0, 255, 0 };
    vImage_YpCbCrToARGB *outInfo = (vImage_YpCbCrToARGB *)malloc(sizeof(vImage_YpCbCrToARGB));
    vImageYpCbCrType inType = kvImage420Yp8_Cb8_Cr8;
    vImageARGBType outType = kvImageARGB8888;
    
    vImage_Error error = vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &pixelRange, outInfo, inType, outType, kvImagePrintDiagnosticsToConsole);
    
    _conversionInfo = outInfo;
    
    return error;
}

- (CVPixelBufferRef) rotatePixelBufferOfBGRA8888:(CVPixelBufferRef) pixelBuffer Rotation:(YVLVideoPixelRotation) rotation
{
    if (rotation != kVLVideoPixelRotate_ClockWise90 && rotation != kVLVideoPixelRotate_ClockWise180 && rotation != kVLVideoPixelRotate_ClockWise270)
    {
        return pixelBuffer;
    }
    
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (pixelFormat != kCVPixelFormatType_32BGRA)
    {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    uint8_t *srcBaseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    unsigned long srcWidth = CVPixelBufferGetWidth(pixelBuffer);
    unsigned long srcHeight = CVPixelBufferGetHeight(pixelBuffer);
    unsigned long srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    
    unsigned long dstWidth = 0;
    unsigned long dstHeight = 0;
    float angleInRadians = 0;
    if (rotation == kVLVideoPixelRotate_ClockWise180)
    {
        dstWidth = srcWidth;
        dstHeight = srcHeight;
        angleInRadians = M_PI;
    }
    else if (rotation == kVLVideoPixelRotate_ClockWise90 || rotation == kVLVideoPixelRotate_ClockWise270)
    {
        dstWidth = srcHeight;
        dstHeight = srcWidth;
        
        int degree = rotation == kVLVideoPixelRotate_ClockWise90? 90 : 270;
        angleInRadians = 2*M_PI - ((degree) / 180.0 * M_PI);
    }
    
    CVPixelBufferRef outputPixelBuffer = NULL;
    
    NSDictionary* option = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                            [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                            [NSNumber numberWithBool:YES], kCVPixelBufferOpenGLESCompatibilityKey,
                            @{}, kCVPixelBufferIOSurfacePropertiesKey,
                            @(16), kCVPixelBufferBytesPerRowAlignmentKey,
                            nil];
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault, dstWidth, dstHeight, pixelFormat, (__bridge CFDictionaryRef)option, &outputPixelBuffer);
    if (result == kCVReturnSuccess)
    {
        CVPixelBufferLockBaseAddress(outputPixelBuffer, 0);
        uint8_t *dstBaseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(outputPixelBuffer);
        unsigned long dstBytesPerRow = CVPixelBufferGetBytesPerRow(outputPixelBuffer);
        
        vImage_Buffer srcImageBuffer;
        srcImageBuffer.data = srcBaseAddress;
        srcImageBuffer.width = srcWidth;
        srcImageBuffer.height = srcHeight;
        srcImageBuffer.rowBytes = srcBytesPerRow;
        
        vImage_Buffer dstImageBuffer;
        dstImageBuffer.data = dstBaseAddress;
        dstImageBuffer.width = dstWidth;
        dstImageBuffer.height = dstHeight;
        dstImageBuffer.rowBytes = dstBytesPerRow;
        
        Pixel_8888 backgroundColor = {0,0,0,0};
        if (tempBufferWhenRotatePixelBuffer == NULL)
        {
            long length = vImageRotate_ARGB8888(&srcImageBuffer, &dstImageBuffer, nil, angleInRadians, backgroundColor, kvImageGetTempBufferSize);
            if (length)
            {
                [self createTemporaryBuffer:&tempBufferWhenRotatePixelBuffer Width:dstWidth Height:dstHeight Length:length];
                NSLog(@"malloc temp rotate buffer : %ld", length);
            }
        }
        vImageRotate_ARGB8888(&srcImageBuffer, &dstImageBuffer, tempBufferWhenRotatePixelBuffer->bufferPointer, angleInRadians, backgroundColor, kvImageBackgroundColorFill);
        CVPixelBufferUnlockBaseAddress(outputPixelBuffer, 0);
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return outputPixelBuffer;
}

- (void) createTemporaryBuffer:(TemporaryBuffer **)instancePointer Width:(unsigned long)width Height:(unsigned long)height Length:(long)length
{
    [self deleteTemporaryBuffer:instancePointer];
    (*instancePointer) = new TemporaryBuffer();
    (*instancePointer)->width = width;
    (*instancePointer)->height = height;
    (*instancePointer)->length = length;
    (*instancePointer)->bufferPointer = (uint8_t *) malloc(length);
}

- (void) deleteTemporaryBuffer:(TemporaryBuffer **)instancePointer
{
    if ((*instancePointer) != NULL)
    {
        if ((*instancePointer)->bufferPointer != NULL)
        {
            free((*instancePointer)->bufferPointer);
            (*instancePointer)->bufferPointer = NULL;
        }
        free((*instancePointer));
        (*instancePointer) = NULL;
    }
}


/**
 * 从RGB的image转到YUV 420f 的 pixelbuffer.
 * 非常重要
 * Y = 0.299R + 0.587G + 0.114B
 * Cb = (-0.1145R - 0.3855G + 0.500B) +128
 * Cr =  (0.500R - 0.4543G - 0.0457B) + 128
 */
+ (CVPixelBufferRef)imageToYUVPixelBuffer:(UIImage *)image
{
    // convert to CGImage & dump to bitmapData
    
    CGImageRef imageRef = [image CGImage];
    int width  = (int)CGImageGetWidth(imageRef);
    int height = (int)CGImageGetHeight(imageRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *bitmapData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
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
    
    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs, &yuvPixelBuffer);
    if (err) {
        return NULL;
    }
    CFRelease(attrs);
    
    CVPixelBufferLockBaseAddress(yuvPixelBuffer, 0);
    
    uint8_t * yPtr = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(yuvPixelBuffer, 0);
    size_t strideY = CVPixelBufferGetBytesPerRowOfPlane(yuvPixelBuffer, 0);
    
    uint8_t * uvPtr = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(yuvPixelBuffer, 1);
    size_t strideUV = CVPixelBufferGetBytesPerRowOfPlane(yuvPixelBuffer, 1);
    
    for (int j = 0; j < height; j++) {
        for (int i = 0; i < width; i++) {
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
    
    for (int j = 0; j < height; j+=2)
    {
        for (int i = 0; i < width; i+=2)
        {
            float r  = bitmapData[j*bytesPerRow + i*4 + 0];
            float g  = bitmapData[j*bytesPerRow + i*4 + 1];
            float b  = bitmapData[j*bytesPerRow + i*4 + 2];
            
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
            
            uvPtr[j/2*strideUV + i + 0] = (uint8_t)u;
            uvPtr[j/2*strideUV + i + 1] = (uint8_t)v;
        }
    }
    
    free(bitmapData);
    CVPixelBufferUnlockBaseAddress(yuvPixelBuffer, 0);
    
    return yuvPixelBuffer;
}
@end

