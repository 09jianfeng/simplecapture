//
//  TCPClient.h
//  YYVideolibDemo
//
//  Created by JFChen on 2018/2/5.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebProtocolDelegate.h"

@interface TCPClient : NSObject
@property(nonatomic, weak) id<WebProtocolDelegate> delegate;

- (void)linkToHost:(NSString *)ipAddress port:(int)port;

- (void)sendData:(NSData *)data;
- (void)disconnect;
@end
