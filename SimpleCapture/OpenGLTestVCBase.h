//
//  OpenGLTestVCBase.h
//  SimpleCapture
//
//  Created by JFChen on 2018/4/18.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(int,OpenGLTestType){
    OpenGLTestTypeCoordinate,
    OpenGLTestTypeTexture
};

@interface OpenGLTestVCBase : UIViewController

- (void)useOpenGLTestType:(OpenGLTestType)type;

@end
