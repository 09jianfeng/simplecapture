//
//  AssetTools.h
//  SimpleCapture
//
//  Created by JFChen on 2019/5/30.
//  Copyright © 2019 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef void (^CompletionBlock)(BOOL success,NSURL *url);

typedef NS_ENUM(int,LYZMediaType){
    LYZMediaTypeAudio,
    LYZMediaTypeVideo
};

@interface AssetTools : NSObject

//音频与视频混合
+ (void)mixVideoAndAudioWithVieoPath:(NSURL *)videoPath
                           audioPath:(NSURL *)audioPath
                      needVideoVoice:(BOOL)needVideoVoice
                         videoVolume:(CGFloat)videoVolume
                         audioVolume:(CGFloat)audioVolume
                      outPutFileName:(NSString *)fileName
                     complitionBlock:(CompletionBlock)completionBlock;

//音频与音频合并
+ (void)mixOriginalAudio:(NSURL *)originalAudioPath
     originalAudioVolume:(float)originalAudioVolume
             bgAudioPath:(NSURL *)bgAudioPath
           bgAudioVolume:(float)bgAudioVolume
          outPutFileName:(NSString *)fileName
         completionBlock:(CompletionBlock)completionBlock;

@end
