//
//  Mp4DemuxerObjc.h
//  SimpleCapture
//
//  Created by JFChen on 2018/7/16.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoConfiguration.h"

@interface Mp4DemuxerObjc : NSObject

- (instancetype)initWithVideoPath:(NSString *)path;

- (NSData *)getOneFrameVideoData;
- (VideoConfiguration *)getVideoConfig;

@end
