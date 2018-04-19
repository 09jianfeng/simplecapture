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
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)coordinateBtnPressed:(id)sender {
    OpenGLTestVCBase *openglVC = [OpenGLTestVCBase new];
    [openglVC useOpenGLTestType:OpenGLTestTypeGLKViewTexture];
    [self.navigationController pushViewController:openglVC animated:NO];

}

- (IBAction)textureBtnPressed:(id)sender {
    OpenGLTestVCBase *openglVC = [OpenGLTestVCBase new];
    [openglVC useOpenGLTestType:OpenGLTestTypeTexture];
    [self.navigationController pushViewController:openglVC animated:NO];
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
