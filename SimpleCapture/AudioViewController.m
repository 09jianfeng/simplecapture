//
//  AudioViewController.m
//  SimpleCapture
//
//  Created by JFChen on 2018/5/1.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "AudioViewController.h"
#import "AACPlayer.h"
#import "PCMPlayer.h"
#import "AccompanimentPlay.h"
#import "AudioUnitPlayer.h"
#import "AudioCaptureSampleBuffer.h"
#import "AudioCapture.h"

@interface AudioViewController ()
@property (nonatomic, strong) NSArray *tableViewData;
@end

@implementation AudioViewController{
    AACPlayer *_player;
    PCMPlayer *_pcmPlayer;
    AccompanimentPlay *_accompPlayer;
    AudioUnitPlayer *_auPlayer;
    AudioCaptureSampleBuffer *_audioCapture;
    AudioCapture *_audioCapturePCM;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    _tableViewData = @[@"播放AAC",@"播放PCM",@"伴奏",@"AudioUnit解码并且播放",@"采集声音SampleBuffer",@"采集声音PCMdata"];
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
    return self.tableViewData.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"audioVCTableCell" forIndexPath:indexPath];
    NSString *viewDetail = _tableViewData[indexPath.row];
    
    UILabel *cellLabel = [cell viewWithTag:1001];
    if (!cellLabel) {
        cellLabel = [[UILabel alloc] initWithFrame:cell.bounds];
        cellLabel.textAlignment = NSTextAlignmentCenter;
        cellLabel.tag = 1001;
    }
    cellLabel.text = viewDetail;
    [cell addSubview:cellLabel];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.row) {
        case 0:{
                _player = [[AACPlayer alloc] init];
                [_player play];
        }
            break;
            
        case 1:{
                _pcmPlayer = [[PCMPlayer alloc] init];
                [_pcmPlayer play];
        }
            break;
            
        case 2:{
                _accompPlayer = [AccompanimentPlay new];
                [_accompPlayer start];
        }
            break;
        
        case 3:{
                _auPlayer = [AudioUnitPlayer new];
                [_auPlayer play];
        }
            break;
            
        case 4:{
                _audioCapture = [AudioCaptureSampleBuffer new];
                [_audioCapture startCapture];
        }
            break;
            
        case 5:{
            _audioCapturePCM = [AudioCapture new];
            [_audioCapturePCM start];
        }
            break;
            
        default:
            break;
    }
}

@end
