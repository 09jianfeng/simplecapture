//
//  OpenGLTestVCBase.m
//  SimpleCapture
//
//  Created by JFChen on 2018/4/18.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "OpenGLTestVCBase.h"
#import "OpenGLContianerDelegate.h"
#import "TextureEAGLLayer.h"
#import "TextureGLKView.h"
#import "TextureGLKViewFBTexture.h"
#import "TextureEAGLLayerFBTexture.h"

@interface OpenGLTestVCBase ()
@property(nonatomic, strong) id<OpenGLContianerDelegate> openglDelegate;
@end

@implementation OpenGLTestVCBase

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    [self.openglDelegate setContianerFrame:self.view.bounds];
    [self.openglDelegate openGLRender];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - myFunction
- (void)useOpenGLTestType:(int)type{
    [self.openglDelegate removeFromSuperContainer];
    
    switch (type) {
        case 0:{
            TextureGLKViewFBTexture *textureView = [TextureGLKViewFBTexture new];
            [self.view addSubview:textureView];
            self.openglDelegate = textureView;

        }
        break;

        case 1:{
            TextureGLKView *textureView = [TextureGLKView new];
            [self.view addSubview:textureView];
            self.openglDelegate = textureView;
        }
        break;
        
        case 2:
        {
            TextureEAGLLayer *textureLayer = [TextureEAGLLayer new];
            [self.view.layer addSublayer:textureLayer];
            self.openglDelegate = textureLayer;
        }
        break;
            
        case 3:
        {
            TextureEAGLLayerFBTexture *textureLayer = [TextureEAGLLayerFBTexture new];
            [self.view.layer addSublayer:textureLayer];
            self.openglDelegate = textureLayer;
        }
            break;

        
        default:
        break;
    }
}

- (void)dealloc{
    NSLog(@"OpenGLTestVCBase dealloc");
    [self.openglDelegate removeFromSuperContainer];
}

@end
