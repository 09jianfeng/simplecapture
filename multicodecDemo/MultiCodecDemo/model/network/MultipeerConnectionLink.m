//
//  MultipeerConnectionLink.m
//  test
//
//  Created by JFChen on 2018/9/3.
//  Copyright © 2018年 yy. All rights reserved.
//

#import "MultipeerConnectionLink.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface MultipeerConnectionLink()<MCSessionDelegate,MCNearbyServiceBrowserDelegate,MCBrowserViewControllerDelegate>
/**
 *  表示为一个用户
 */
@property (nonatomic,strong)MCPeerID * peerID;
/**
 *  启用和管理Multipeer连接会话中的所有人之间的沟通。 通过Sesion，给别人发送数据。类似于Scoket
 */
@property (nonatomic,strong)MCSession * session;
/**
 *  可以接收，并处理用户请求连接的响应。没有回调，会弹出默认的提示框，并处理连接。
 */
@property (nonatomic,strong)MCAdvertiserAssistant * advertiser;
/**
 *  用于搜索附近的用户，并可以对搜索到的用户发出邀请加入某个会话中。
 */
@property (nonatomic,strong)MCNearbyServiceBrowser * brower;
/**
 *  附近用户列表
 */
@property (nonatomic,strong)MCBrowserViewController * browserViewController;
/**
 *  存储连接
 */
@property (nonatomic,strong)NSMutableArray * sessionArray;

@property (nonatomic,strong)UIViewController *viewController;
@end

@implementation MultipeerConnectionLink{
}

- (void)setUpConnectionWitController:(UIViewController *)viewController{
    _viewController = viewController;
    [self createMC];
}

/**
 *  两种类型
 MCSessionSendDataUnreliable 类似于UDP连接方式
 MCSessionSendDataReliable 类似于TCP连接方式
 */

- (void)sendData:(NSData *)data isReliable:(BOOL)isReliable{
    
    MCSessionSendDataMode mode;
    if (isReliable) {
        mode = MCSessionSendDataReliable;
    }else{
        mode = MCSessionSendDataReliable;
    }
    
    NSError *error = nil;
    BOOL success = [_session sendData:data toPeers:_session.connectedPeers withMode:mode error:&error];
    if (error) {
        NSLog(@"multi send data error %@ success %d",error, success);
    }
}

/**
 *  连接设置
 */
- (void)createMC{
    //获取设备名称
    NSString * name = [UIDevice currentDevice].name;
    //用户
    _peerID = [[MCPeerID alloc]initWithDisplayName:name];
    //为用户建立连接
    _session = [[MCSession alloc] initWithPeer:_peerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
    //设置代理
    _session.delegate = self;
    
    
    if (!_isClient) {
        //设置广播服务(发送方)
        _advertiser = [[MCAdvertiserAssistant alloc]initWithServiceType:@"type" discoveryInfo:nil session:_session];
        //开始广播
        [_advertiser start];
    }else{
        //设置发现服务(接收方)
        _brower = [[MCNearbyServiceBrowser alloc]initWithPeer:_peerID serviceType:@"type"];
        //设置代理
        _brower.delegate = self;
        [_brower startBrowsingForPeers];
    }
}
#pragma MC相关代理方法
/**
 *  发现附近用户
 *
 *  @param browser 搜索附近用户
 *  @param peerID  附近用户
 *  @param info    详情
 */
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info{
    NSLog(@"发现附近用户%@",peerID.displayName);
    if (_browserViewController == nil) {
        _browserViewController = [[MCBrowserViewController alloc]initWithServiceType:@"type" session:_session];
        _browserViewController.delegate = self;
        /**
         *  跳转发现界面
         */
        [_viewController presentViewController:_browserViewController animated:YES completion:nil];
    }
}
/**
 *  附近某个用户消失了
 *
 *  @param browser 搜索附近用户
 *  @param peerID  用户
 */
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID{
    NSLog(@"附近用户%@离开了",peerID.displayName);
}
#pragma mark BrowserViewController附近用户列表视图相关代理方法
/**
 *  选取相应用户
 *
 *  @param browserViewController 用户列表
 */
- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController{
    [_viewController dismissViewControllerAnimated:YES completion:nil];
    _browserViewController = nil;
    //关闭广播服务，停止其他人发现
    [_advertiser stop];
}
/**
 *  用户列表关闭
 *
 *  @param browserViewController 用户列表
 */
- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController{
    [_viewController dismissViewControllerAnimated:YES completion:nil];
    _browserViewController = nil;
    [_advertiser stop];
}
#pragma mark MCSession代理方法
/**
 *  当检测到连接状态发生改变后进行存储
 *
 *  @param session MC流
 *  @param peerID  用户
 *  @param state   连接状态
 */
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state{
    //判断如果连接
    if (state == MCSessionStateConnected) {
        //保存这个连接
        if (![_sessionArray containsObject:session]) {
            //如果不存在 保存
            [_sessionArray addObject:session];
        }
    }
}
/**
 *  接收到消息
 *
 *  @param session MC流
 *  @param data    传入的二进制数据
 *  @param peerID  用户
 */
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID{
    
    [_delegate didReceiveData:data];
//    NSString * message = [NSString stringWithFormat:@"%@:%@",peerID.displayName,[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [_dataArray addObject:message];
//        NSIndexPath * indexPath = [NSIndexPath indexPathForRow:_dataArray.count - 1 inSection:0];
//        [_tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
//        [_tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
//    });
}
/**
 *  接收数据流
 *
 *  @param session    MC流
 *  @param stream     数据流
 *  @param streamName 数据流名称（标示）
 *  @param peerID     用户
 */
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID{
    
}
/**
 *  开始接收资源
 *
 *  @param session      MC流
 *  @param resourceName 资源名称
 *  @param peerID       用户
 *  @param progress     进度
 */
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress{
    
}
/**
 *  资源接收结束
 *
 *  @param session      MC流
 *  @param resourceName 资源名称
 *  @param peerID       用户
 *  @param localURL     本地资源
 *  @param error        报错信息
 */
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error{
    NSLog(@"____ %@",error);
}

@end
