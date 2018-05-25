//
//  GPUImageGaussBeauty.h
//  GPUImage
//
//  Created by xuqing on 21/6/2016.
//  Copyright © 2016 Brad Larson. All rights reserved.
//

#import "GPUImageFilterGroup.h"

@class GPUImageGaussianBlurFilter;

@interface GPUImageGaussBeauty : GPUImageFilterGroup
{
    GPUImageGaussianBlurFilter *blurFilter;
    GPUImageFilter *srcFilter;
    
}
@property (readwrite, nonatomic) CGFloat whiteness;
@property (readwrite, nonatomic) CGFloat alphaSoftlight;
@property (readwrite, nonatomic) CGFloat alphaSkin;
@property (readwrite, nonatomic) CGFloat blurRadiusInPixels;
@end
