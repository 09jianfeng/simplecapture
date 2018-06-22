//
//  OpenGLTestVCBase.m
//  SimpleCapture
//
//  Created by JFChen on 2018/4/18.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "OpenGLTestVCBase.h"
#import "OpenGLContianerDelegate.h"
#import "MultiTextureEAGLLayer.h"
#import "TextureGLKView.h"
#import "TextureGLKViewFBTexture.h"
#import "TextureEAGLLayerFBTexture.h"
#import "MetalRenderLayer.h"
#import "AAPLEAGLLayer.h"
#import "MultiRenderMetalLayer.h"

@interface OpenGLTestVCBase ()
@property(nonatomic, strong) id<OpenGLContianerDelegate> openglDelegate;
@end

@implementation OpenGLTestVCBase{
}

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
    
    NSString *name = _classNames[type];
    Class MineClass = NSClassFromString(name);
    id<OpenGLContianerDelegate> object = [MineClass new];
    if([object respondsToSelector:@selector(addSubview:)]){
        [self.view addSubview:(UIView *)object];
    }else{
     [self.view.layer addSublayer:(CALayer *)object];
    }
    self.openglDelegate = object;
}

- (void)dealloc{
    NSLog(@"OpenGLTestVCBase dealloc");
    [self.openglDelegate removeFromSuperContainer];
}

@end
