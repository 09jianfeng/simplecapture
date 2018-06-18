//
//  OpenglTableViewController.m
//  SimpleCapture
//
//  Created by JFChen on 2018/5/4.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "OpenglTableViewController.h"
#import "OpenGLTestVCBase.h"

@interface OpenglTableViewController ()

@end

@implementation OpenglTableViewController{
    NSArray *_tableData;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    _tableData = @[@"glkview fb 渲染到纹理",
                   @"glkview 直接渲染",
                   @"CAEAGLLayer 渲染到renderbuffer",
                   @"CAEAGLLayer 渲染到纹理",
                   @"metalrenderlayer"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _tableData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenGLTBCell" forIndexPath:indexPath];
    
    cell.textLabel.text = _tableData[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    OpenGLTestVCBase *openglVC = [OpenGLTestVCBase new];
    [openglVC useOpenGLTestType:indexPath.row];
    [self.navigationController pushViewController:openglVC animated:NO];
}

@end
