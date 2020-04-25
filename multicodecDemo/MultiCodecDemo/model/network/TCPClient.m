//
//  TCPClient.m
//  YYVideolibDemo
//
//  Created by JFChen on 2018/2/5.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import "TCPClient.h"
#import "GCDAsyncSocket.h"
#import "DataPackUnPack.h"
#import <UIKit/UIKit.h>
#import <SVProgressHUD.h>

#define PACKDATAHEADER 1
#define PACKDATABODY 2

// Log levels: off, error, warn, info, verbose
@interface TCPClient()<NSNetServiceBrowserDelegate, NSNetServiceDelegate, GCDAsyncSocketDelegate>

@end

@implementation TCPClient{
    NSNetServiceBrowser *netServiceBrowser;
    NSNetService *serverService;
    NSMutableArray *serverAddresses;
    GCDAsyncSocket *asyncSocket;
    BOOL connected;
    int _tag;
}

- (void)linkToHost:(NSString *)ipAddress port:(int)port{
    asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *error = nil;
    [asyncSocket connectToHost:ipAddress onPort:port error:&error];
    [asyncSocket readDataToLength:4 withTimeout:-1 tag:PACKDATAHEADER];
    if (error) {
        NSLog(@"asyncSocket error %@",error);
        
        NSString *message = [NSString stringWithFormat:@"连接失败 error:%@",error];
        [SVProgressHUD showSuccessWithStatus:message];
        return;
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"Socket:DidConnectToHost: %@ Port: %hu", host, port);
    
    connected = YES;
    
    NSString *message = [NSString stringWithFormat:@"连接成功 ip:%@ Port:%hu",host, port];
    [SVProgressHUD showSuccessWithStatus:message];
    
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    switch (tag) {
        case PACKDATAHEADER:
        {
            uint8_t *packDataHeaderLen = (uint8_t *)[data bytes];
            int packDHLen = [DataPackUnPack getIntFromLittleEndian:packDataHeaderLen];
            [sock readDataToLength:packDHLen withTimeout:-1 tag:PACKDATABODY];
        }
            break;
        case PACKDATABODY:
        {
            [_delegate didReceiveData:data fromIP:nil];
            [sock readDataToLength:4 withTimeout:-1 tag:PACKDATAHEADER];
        }
            break;
            
        default:
            break;
    }
}

- (void)disconnect{
    [asyncSocket disconnect];
}

#pragma mark - write data
- (void)socket:(GCDAsyncSocket*)sock didWriteDataWithTag:(long)tag{
    _tag++;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"SocketDidDisconnect:WithError: %@", err);
    
    if (!connected)
    {
    }
    
    NSString *message = [NSString stringWithFormat:@"连接断开 error:%@",err];
    [SVProgressHUD showSuccessWithStatus:message];
}

- (void)sendData:(NSData *)data{
    [asyncSocket writeData:data withTimeout:30 tag:_tag];
}

@end
