//
//  UDPServer.h
//  YYAudioDemo
//
//  Created by JFChen on 2018/5/7.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebProtocolDelegate.h"

@interface UDPSenderReceiver : NSObject
@property (nonatomic, weak) id<WebProtocolDelegate> delegate;

- (void)enableBroadCast;

- (void)bindPort:(int)port;
- (void)linkToHost:(NSString *)ipAddress port:(int)port;
- (void)sendData:(NSData *)data;

+ (NSString *)getLocalIPAddress;
+ (NSString *)getLocalIPAddressMask;

@end
