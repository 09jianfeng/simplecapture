//
//  OpenGLTestVCBase.h
//  SimpleCapture
//
//  Created by JFChen on 2018/4/18.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OpenGLTestVCBase : UIViewController
@property (nonatomic, strong) NSArray *classNames;

- (void)useOpenGLTestType:(int)type;

@end