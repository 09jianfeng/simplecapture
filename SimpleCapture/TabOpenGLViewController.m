//
//  TabOpenGLViewController.m
//  SimpleCapture
//
//  Created by JFChen on 2018/4/18.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "TabOpenGLViewController.h"
#import "OpenGLTestVCBase.h"

@interface TabOpenGLViewController ()

@end

@implementation TabOpenGLViewController{
    OpenGLTestVCBase *_openglVC;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _openglVC = [OpenGLTestVCBase new];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)coordinateBtnPressed:(id)sender {
    [_openglVC useOpenGLTestType:OpenGLTestTypeCoordinate];
    [self.navigationController pushViewController:_openglVC animated:NO];
}

- (IBAction)textureBtnPressed:(id)sender {
    [_openglVC useOpenGLTestType:OpenGLTestTypeTexture];
    [self.navigationController pushViewController:_openglVC animated:NO];
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
