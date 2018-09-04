//
//  VRPlayerView.h
//  VRPlayer
//
//  Created by huafeng chen on 16/3/30.
//  Copyright © 2016年 huafeng chen. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoVRView : UIView
@property (unsafe_unretained) CVPixelBufferRef  pixelBuffer;
@property (assign, nonatomic) BOOL      isUsingMotion;
@property (assign, nonatomic) BOOL           isLandscape;

- (void)startDeviceMotion:(NSError **)error;
- (void)stopDeviceMotion;
@end
