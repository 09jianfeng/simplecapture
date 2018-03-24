//
//  CameraView.m
//  SimpleCapture
//
//  Created by JFChen on 2018/3/23.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "CameraView.h"
#import "CameraEAGLLayer.h"

@implementation CameraView{
    CameraEAGLLayer *_layer;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        _layer = [CameraEAGLLayer new];
        [self.layer addSublayer:_layer];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    _layer.frame = self.bounds;
}

@end
