//
//  GPUImageBilatBeauty.h
//  GPUImage
//
//  Created by xuqing on 22/6/2016.
//  Copyright © 2016 Brad Larson. All rights reserved.
//

#import "GPUImageFilterGroup.h"

@class GPUImageBilateralFilter;
@interface GPUImageBilatBeauty :GPUImageFilterGroup
{
    GPUImageBilateralFilter *blurFilter;
    GPUImageFilter *srcFilter;
    
}
@property (readwrite, nonatomic) CGFloat whiteness;
@property (readwrite, nonatomic) CGFloat alphaSoftlight;
@property (readwrite, nonatomic) CGFloat alphaSkin;
@property (nonatomic, readwrite) CGFloat distanceFactor;

@end
