//
//  TextureViewController.m
//  SimpleCapture
//
//  Created by JFChen on 2018/4/18.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "TextureViewController.h"
#import "TextureEAGLLayer.h"

@interface TextureViewController ()
@property(nonatomic, strong) TextureEAGLLayer *textureLayer;
@end

@implementation TextureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    _textureLayer = [TextureEAGLLayer new];
    _textureLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:_textureLayer];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    _textureLayer.frame = self.view.bounds;
    [_textureLayer setUpGLWithFrame:self.view.bounds];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
