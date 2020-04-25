//
//  TCPServer.h
//  YYVideolibDemo
//
//  Created by JFChen on 2018/2/5.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebProtocolDelegate.h"

@interface TCPServer : NSObject
@property(nonatomic, weak) id<WebProtocolDelegate> delegate;

+ (instancetype)shareInstance;

- (void)startServer;
- (void)stopServer;

- (NSString *)getLocalServerIP;

- (void)sendData:(NSData *)data;

@end
