//
//  TCPServer.m
//  YYVideolibDemo
//
//  Created by JFChen on 2018/2/5.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import "TCPServer.h"
#import "GCDAsyncSocket.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "DataPackUnPack.h"
#include <time.h>
#include <sys/time.h>

#import <UIKit/UIKit.h>
#import <SVProgressHUD.h>

#define PACKDATAHEADER 1
#define PACKDATABODY 2

// Log levels: off, error, warn, info, verbose
@interface TCPServer()<NSNetServiceDelegate,GCDAsyncSocketDelegate>

@end

@implementation TCPServer{
    NSNetService *netService;
    GCDAsyncSocket *asyncSocket;
    NSMutableArray *connectedSockets;
    int _tag;
    
    int _frameCountOut;
    int _frameCount;
    uint32_t _lastTicCount;
    GCDAsyncSocket *_gcdReadingSocket;
}

+ (instancetype)shareInstance{
    static dispatch_once_t onceToken;
    static TCPServer *tcpSer = nil;
    dispatch_once(&onceToken, ^{
        tcpSer = [TCPServer new];
    });
    return tcpSer;
}

- (void)startServer{
    asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    // Create an array to hold accepted incoming connections.
    
    connectedSockets = [[NSMutableArray alloc] init];
    
    // Now we tell the socket to accept incoming connections.
    // We don't care what port it listens on, so we pass zero for the port number.
    // This allows the operating system to automatically assign us an available port.
    
    NSError *err = nil;
    if ([asyncSocket acceptOnPort:8080 error:&err])
    {
        // So what port did the OS give us?
        
        UInt16 port = [asyncSocket localPort];
        
        // Create and publish the bonjour service.
        // Obviously you will be using your own custom service type.
        
        netService = [[NSNetService alloc] initWithDomain:@"local."
                                                     type:@"_YourServiceName._tcp."
                                                     name:@""
                                                     port:port];
        
        [netService setDelegate:self];
        [netService publish];
        
        // You can optionally add TXT record stuff
        
        NSMutableDictionary *txtDict = [NSMutableDictionary dictionaryWithCapacity:2];
        
        [txtDict setObject:@"moo" forKey:@"cow"];
        [txtDict setObject:@"quack" forKey:@"duck"];
        
        NSData *txtData = [NSNetService dataFromTXTRecordDictionary:txtDict];
        [netService setTXTRecordData:txtData];
    }
    else
    {
        NSLog(@"Error in acceptOnPort:error: -> %@", err);
    }
}

- (void)stopServer{
    asyncSocket = nil;
    connectedSockets = nil;
    netService = nil;
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    NSLog(@"Accepted new socket from %@:%hu", [newSocket connectedHost], [newSocket connectedPort]);
    
    // The newSocket automatically inherits its delegate & delegateQueue from its parent.
    
    [connectedSockets addObject:newSocket];
    
    [newSocket readDataToLength:4 withTimeout:-1 tag:PACKDATAHEADER];
    
    NSString *message = [NSString stringWithFormat:@"Accepted new socket from %@:%hu", [newSocket connectedHost], [newSocket connectedPort]];
    [SVProgressHUD showSuccessWithStatus:message];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"socket did disconnect %@",err);
    [connectedSockets removeObject:sock];
    
    NSString *message = [NSString stringWithFormat:@"socket did disconnect %@",err];
    [SVProgressHUD showSuccessWithStatus:message];
}

- (void)netServiceDidPublish:(NSNetService *)ns
{
    NSLog(@"Bonjour Service Published: domain(%@) type(%@) name(%@) port(%i)",[ns domain], [ns type], [ns name], (int)[ns port]);
    [_delegate finishStartServer:[self getIPAddress] port:(int)[ns port]];
}

- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
    // Override me to do something here...
    //
    // Note: This method in invoked on our bonjour thread.
    
    NSLog(@"Failed to Publish Service: domain(%@) type(%@) name(%@) - %@",[ns domain], [ns type], [ns name], errorDict);
    [_delegate serverDidClose];
}

- (NSString *)getIPAddress
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

#pragma mark - read data

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    _gcdReadingSocket = sock;
    
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

#pragma mark - write data
-(uint32_t) getTickCount
{
    struct timeval now;
    gettimeofday(&now, NULL);
    return (uint32_t) (((uint64_t)now.tv_sec * USEC_PER_SEC + now.tv_usec) / 1000);
}

- (void)socket:(GCDAsyncSocket*)sock didWriteDataWithTag:(long)tag{
    _tag++;
}

- (void)sendData:(NSData *)data{
    
    uint32_t now = [self getTickCount];
    if (_lastTicCount <= 0) {
        _lastTicCount = now;
    }
    
    _frameCountOut++;
    if (now - _lastTicCount >= 1000) {
        _lastTicCount = now;
        NSLog(@"____ server frameCount:%d outside:%d",_frameCount,_frameCountOut);
        _frameCount = 0;
        _frameCountOut = 0;
    }

    for (GCDAsyncSocket *sock in connectedSockets) {
        if (sock == _gcdReadingSocket) {
            continue;
        }
        
        [sock writeData:data withTimeout:1.0 tag:_tag];
        _frameCount++;
    }
}

- (NSString *)getLocalServerIP{
    return @"";
}

@end
