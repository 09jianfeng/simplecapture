//
//  VideoConfiguration.h
//  SimpleCapture
//
//  Created by JFChen on 2018/7/16.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoConfiguration : NSObject
@property (nonatomic, copy) NSData *sps;
@property (nonatomic, copy) NSData *pps;
@property (nonatomic, copy) NSData *vps;

@property (nonatomic, assign) int width;
@property (nonatomic, assign) int heigh;
@end
