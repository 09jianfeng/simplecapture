//
//  VideoFileDecoder.h
//  SimpleCapture
//
//  Created by JFChen on 17/3/22.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#include "SCCommon.h"

@protocol VideoFileDecoderDelegate <NSObject>

@required
- (void)outPutPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

@interface VideoFileDecoder : NSObject
@property(nonatomic, assign) UInt32 decodeInterval;
@property(nonatomic, weak) id<VideoFileDecoderDelegate> delegate;

- (void)decodeVideoWithVideoPath:(NSString *)videoPath;
- (void)invalidDecoder;

@end
