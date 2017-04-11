//
//  VideoProcessor.h
//  SimpleCapture
//
//  Created by Yao Dong on 16/2/7.
//  Copyright © 2016年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol VideoProcessorDelegate <NSObject>
- (void) processorOutput:(CMSampleBufferRef)sampleBuf;
@end

@interface VideoProcessor : NSObject

@property BOOL enableBeauty;
@property BOOL enableFlip;

@property (readonly) UIView *previewView;

-(id) initWithSize:(CGSize)size;
-(void) process:(CMSampleBufferRef)sampleBuffer;
-(void) setDelegate:(id<VideoProcessorDelegate>)processorDelegate queue:(dispatch_queue_t)processorCallbackQueue;
-(void)stop;
@end
