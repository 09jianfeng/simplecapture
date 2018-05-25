//
//  GPUImageYYBeautyFilter
//  GPUImage
//
//  Created by chengyu on 16/4/6.
//  Copyright © 2016 yy. All rights reserved.
//

#import "GPUImageFilter.h"
@interface GPUImageBeautyFilter : GPUImageFilter
{
    GLint  EpsUniform;
    GLint  StepUniform;
    GLint  whitenessUniform;
}

@property(nonatomic, readwrite)CGFloat uEps;
@property(nonatomic, readwrite)CGFloat step;
@property(nonatomic, readwrite)CGFloat whiteness;
@property(nonatomic, readwrite)CGFloat softLight;
@end
