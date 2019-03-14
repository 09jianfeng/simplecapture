//
//  MP4Transform.h
//  SimpleCapture
//
//  Created by JFChen on 2018/7/16.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MP4Transform : NSObject

- (instancetype)initWithMp4Path:(NSString *)path;
- (void)transFormBegin;

@end
