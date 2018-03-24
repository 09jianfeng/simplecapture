//
//  CameraViewController.m
//  SimpleCapture
//
//  Created by JFChen on 2018/3/23.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "CameraViewController.h"
#import "CameraView.h"

@interface CameraViewController ()

@end

@implementation CameraViewController{
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.edgesForExtendedLayout = UIRectEdgeAll;
    CameraView *view = [CameraView new];
    view.backgroundColor = [UIColor grayColor];
    [self.view addSubview:view];
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
