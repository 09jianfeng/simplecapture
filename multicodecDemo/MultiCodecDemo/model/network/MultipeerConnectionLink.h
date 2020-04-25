//
//  MultipeerConnectionLink.h
//  test
//
//  Created by JFChen on 2018/9/3.
//  Copyright © 2018年 yy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol MultipeerConnectionLinkDelegate<NSObject>
- (void)didReceiveData:(NSData *)data;
@end

@interface MultipeerConnectionLink : NSObject
@property (nonatomic, weak) id<MultipeerConnectionLinkDelegate> delegate;
@property (nonatomic, assign) BOOL isClient;

- (void)setUpConnectionWitController:(UIViewController *)viewController;

//reliable 表示可靠传输还是不可靠传输
- (void)sendData:(NSData *)data isReliable:(BOOL)isReliable;

@end
