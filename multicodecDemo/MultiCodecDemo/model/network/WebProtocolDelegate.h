//
//  WebProtocolDelegate.h
//  YYAudioDemo
//
//  Created by JFChen on 2018/5/7.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol WebProtocolDelegate <NSObject>

@optional
- (void)finishStartServer:(NSString *)ipadress port:(int)port;
- (void)serverDidClose;
- (void)didReceiveData:(NSData *)data fromIP:(NSData *)fromIP;

@end
