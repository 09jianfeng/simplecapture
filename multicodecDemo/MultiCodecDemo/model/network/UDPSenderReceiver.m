//
//  UDPServer.m
//  YYAudioDemo
//
//  Created by JFChen on 2018/5/7.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import "UDPSenderReceiver.h"
#import "GCDAsyncUdpSocket.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#include <time.h>
#include <sys/time.h>
#import <UIKit/UIKit.h>
#import <SVProgressHUD.h>

@interface UDPSenderReceiver()<GCDAsyncUdpSocketDelegate>
@property(nonatomic, copy) NSString *ipAddress;
@property(nonatomic, assign) int port;
@end

@implementation UDPSenderReceiver{
    GCDAsyncUdpSocket *_udpSocket;
    
    int _tags;
    int _frameCount;
    uint32_t _lastTicCount;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
        
        self.port = 8080;
    }
    return self;
}

- (void)enableBroadCast{
    NSError *error;
    [_udpSocket enableBroadcast:YES error:&error];
    if (error) {
        NSLog(@"enableBroadCast false");
    }
}

- (void)bindPort:(int)port{
    self.port = port;
    [self bindToPort:port];
}

- (void)linkToHost:(NSString *)ipAddress port:(int)port{
    self.ipAddress = ipAddress;
    self.port = port;
}

- (void)bindToPort:(int)port{
    NSError *error = nil;
    if(![_udpSocket bindToPort:port error:&error])
    {
        NSLog(@"error in bindToPort port:%d error:%@",port,error);
        return;
    }
    
    if(![_udpSocket beginReceiving:&error])
    {
        NSLog(@"error in beginReceiving port:%d error:%@",port,error);
        return;
    }

    
    [_delegate finishStartServer:[UDPSenderReceiver getLocalIPAddress] port:port];
    
    NSString *message = [NSString stringWithFormat:@"开启服务器成功：ip地址%@ 成功",[UDPSenderReceiver getLocalIPAddress]];
    [SVProgressHUD setMaximumDismissTimeInterval:2];
    [SVProgressHUD showSuccessWithStatus:message];
}

- (void)sendData:(NSData *)data{
    
    _tags++;
    [_udpSocket sendData:data toHost:self.ipAddress port:self.port withTimeout:-1 tag:_tags];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext{
    [_delegate didReceiveData:data fromIP:address];
    
    uint32_t now = [self getTickCount];
    if (_lastTicCount <= 0) {
        _lastTicCount = now;
    }
    _frameCount++;
    if (now - _lastTicCount >= 1000) {
        _lastTicCount = now;
        //NSLog(@"____ udpSocket client frameCount:%d",_frameCount);
        _frameCount = 0;
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error{
    NSLog(@"udpSocketDidClose error:%@",error);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag{
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    NSLog(@"发送信息失败 %@",error);
}

-(uint32_t) getTickCount
{
    struct timeval now;
    gettimeofday(&now, NULL);
    return (uint32_t) (((uint64_t)now.tv_sec * USEC_PER_SEC + now.tv_usec) / 1000);
}

+ (NSString *)getLocalIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if( temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

+ (NSString *)getLocalIPAddressMask
{
    NSString *ipAddre = [UDPSenderReceiver getLocalIPAddress];
    NSArray *ipSubAry = [ipAddre componentsSeparatedByString:@"."];
    NSString *recombineString = @"";
    for (int i = 0; i < ipSubAry.count - 1; i++) {
        recombineString = [recombineString stringByAppendingString:ipSubAry[i]];
        recombineString = [recombineString stringByAppendingString:@"."];
    }
    
    recombineString = [recombineString stringByAppendingString:@"255"];
    return recombineString;
}

@end
