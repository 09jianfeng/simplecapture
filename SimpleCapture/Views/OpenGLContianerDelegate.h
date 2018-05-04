//
//  OpenGLContianner.h
//  SimpleCapture
//
//  Created by JFChen on 2018/4/18.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol OpenGLContianerDelegate <NSObject>

- (void)setContianerFrame:(CGRect)rect;
- (void)openGLRender;
- (void)removeFromSuperContainer;
@end
