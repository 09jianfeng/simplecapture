//
//  M4aPlayer.h
//  SimpleCapture
//
//  Created by JFChen on 2020/8/10.
//  Copyright © 2020 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface M4aPlayer : NSObject
+ (AVAsset *)getAssetWithPath:(NSURL *)audioPath;
+ (NSData *)readAudioSamplesFromAsset:(AVAsset *)asset sampleRate:(int *)sampleRate channel:(int *)channel;
@end

NS_ASSUME_NONNULL_END
