//
//  AudioCapture.h
//  SimpleCapture
//
//  Created by Yao Dong on 16/2/13.
//  Copyright © 2016年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioCapture : NSObject

@property BOOL isVOIP;
@property int sampleRate;
-(void) start;
-(void) stop;

@end
