//
//  YMTinyVideoCVKit.h
//  yymediarecordersdk
//
//  Created by 吴顺 on 2018/6/13.
//  Copyright © 2018年 YY Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface YMTinyVideoCVKit : NSObject

+ (UIImage *)UIImageFormPixelbuffer:(CVPixelBufferRef)buffer;

+ (CVPixelBufferRef)deepCopyPixelBuffer:(CVPixelBufferRef)srcPixelBuffe;

@end
