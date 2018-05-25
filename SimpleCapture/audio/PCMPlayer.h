//
//  PCMPlayer.h
//  SimpleCapture
//
//  Created by JFChen on 2018/5/25.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PCMPlayer;

@protocol PCMPlayerDelegate <NSObject>
- (void)onPlayToEnd:(PCMPlayer *)pcmPlayer;
@end

@interface PCMPlayer : NSObject
@property (nonatomic, weak) id<PCMPlayerDelegate> delegate;

- (void)play;
- (double)getCurrentTime;

@end
