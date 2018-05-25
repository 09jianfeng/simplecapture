//
//  GPUImageWaterMarkerFilter.h
//  GPUImage
//
//  Created by xuqing on 30/10/15.
//  Copyright © 2015 Brad Larson. All rights reserved.

#import "GPUImageTwoInputFilter.h"

@interface GPUImageWaterMarkerFilter : GPUImageTwoInputFilter
{
    GLint mixUniform;
    GLint gammaUniform;
}

// Mix ranges from 0.0 (only image 1) to 1.0 (only image 2), with 1.0 as the normal level
@property(readwrite, nonatomic) CGFloat mix;
@property(readwrite, nonatomic) CGFloat gamma;
@end