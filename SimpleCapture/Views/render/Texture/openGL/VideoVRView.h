//
//  VRPlayerView.h
//  VRPlayer
//
//  Created by JFChen on 2018/6/23.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoVRView : UIView
@property (unsafe_unretained) CVPixelBufferRef  pixelBuffer;
@property (assign, nonatomic) BOOL      isUsingMotion;
@property (assign, nonatomic) BOOL           isLandscape;

- (void)startDeviceMotion:(NSError **)error;
- (void)stopDeviceMotion;
@end
