//
//  VideoPlayerVC+EvtRe.h
//  SimpleCapture
//
//  Created by JFChen on 17/3/24.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoPlayerVC.h"

@interface VideoPlayerVC (EvtRe)


#pragma mark - btnPress event
- (void)btnPlayVideoPressed:(id)sender;
- (void)btnWebSeverStart:(id)sender;
- (void)btnFileChoosed:(id)sender;

#pragma mark - slider event
- (void)sliderBitChange:(id)sender;
- (void)sliderDenomChange:(id)sender;

@end
