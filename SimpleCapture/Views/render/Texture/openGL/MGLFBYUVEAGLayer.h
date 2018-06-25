//
//  MGLFBYUVEAGLayer.h
//  SimpleCapture
//
//  Created by JFChen on 2018/6/23.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#include <QuartzCore/QuartzCore.h>
#include <CoreVideo/CoreVideo.h>
#include "OpenGLContianerDelegate.h"

@interface MGLFBYUVEAGLayer : CAEAGLLayer

- (void)rotate:(int)angle;

@end
