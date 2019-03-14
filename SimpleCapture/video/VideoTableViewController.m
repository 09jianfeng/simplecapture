//
//  VideoTableViewController.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "VideoTableViewController.h"
#import "AssetViewController.h"
#import "AVCamCameraViewController.h"
#import "VideoPlayerVC.h"
#import "KXMovieController.h"
#import "AVCamManualCameraViewController.h"

@interface VideoTableViewController ()

@end

@implementation VideoTableViewController{
    NSArray *_data;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    _data = @[@"camera+samplebuffer output",
              @"AVAsset 转码",
              @"AutoCamera+photo/moviefile output",
              @"ffmpeg 转码",
              @"kxController",
              @"ManualCamera",
              ];
    
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
    return _data.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"videotableviewcell" forIndexPath:indexPath];
    cell.textLabel.text = _data[indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    switch (indexPath.row) {
        case 0:
        {
            UIViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"ViewController"];
            [self.navigationController pushViewController:vc animated:YES];
        }
            break;
        case 1:
        {
            AssetViewController *asset = [[AssetViewController alloc] initWithNibName:@"AssetViewController" bundle:nil];
            [self.navigationController pushViewController:asset animated:YES];
        }
            break;
        case 2:
        {
            AVCamCameraViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"AVCamCameraViewController"];
            [self.navigationController pushViewController:vc animated:YES];
        }
            break;
        case 3:
        {
            VideoPlayerVC *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"VideoPlayerVC"];
            [self.navigationController pushViewController:vc animated:YES];
        }
            break;
        case 4:
        {
            KXMovieController *vc = [KXMovieController new];
            [self.navigationController pushViewController:vc animated:YES];
        }
            break;
        case 5:
        {
            AVCamManualCameraViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"AVCamManualCameraViewController"];
            [self.navigationController pushViewController:vc animated:YES];
        }
            break;
            
        default:
            break;
    }
}

@end
