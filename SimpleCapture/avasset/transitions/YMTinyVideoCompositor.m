//
//  YMTinyVideoCompositor.m
//  ymplayerdemo
//
//  Created by bleach on 2017/7/19.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "YMTinyVideoCompositor.h"
//#import "YMTinyVideoTransitionRender.h"
#import "YMTinyVideoCompositionInstruction.h"

@interface YMTinyVideoCompositor()

@property (nonatomic, assign) BOOL shouldCancelAllRequests;
@property (nonatomic, assign) BOOL renderContextDidChange;
//@property (nonatomic, strong) YMTinyVideoTransitionRender * transitionRender;

@end

@implementation YMTinyVideoCompositor {
    AVVideoCompositionRenderContext * _renderContext;
}

- (id)init {
    self = [super init];
    if (self) {
//        _transitionRender = [[YMTinyVideoTransitionRender alloc] init];
        _renderContextDidChange = NO;
    }
    return self;
}

- (NSDictionary *)sourcePixelBufferAttributes {
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
              (NSString *)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
              (NSString *)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {
        _renderContext = newRenderContext;
        _renderContextDidChange = YES;
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
    @autoreleasepool {
        if (_shouldCancelAllRequests) {
            [request finishCancelledRequest];
        } else {
            NSError * err = nil;
            CVPixelBufferRef resultPixels = [self newRenderedPixelBufferForRequest:request error:&err];
            
            if (resultPixels) {
                [request finishWithComposedVideoFrame:resultPixels];
                CFRelease(resultPixels);
            } else {
                [request finishWithError:err];
            }
        }
    }
}

- (void)cancelAllPendingVideoCompositionRequests {
    _shouldCancelAllRequests = YES;
    _shouldCancelAllRequests = NO;
}

- (Float64)factorForTimeInRange:(CMTime)time range:(CMTimeRange)range {
    CMTime elapsed = CMTimeSubtract(time, range.start);
    return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration);
}

- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut {
    Float64 tweenFactor = [self factorForTimeInRange:request.compositionTime range:request.videoCompositionInstruction.timeRange];
    
    CVPixelBufferRef destinationFramePixels = [_renderContext newPixelBuffer];
    if ([request.videoCompositionInstruction isKindOfClass:[YMTinyVideoCompositionInstruction class]]) {
        YMTinyVideoCompositionInstruction * currentInstruction = (YMTinyVideoCompositionInstruction *)request.videoCompositionInstruction;
        
        CVPixelBufferRef preVideoFramePixelBuffer = [request sourceFrameByTrackID:currentInstruction.preTrackID];
        CVPixelBufferRef nextVideoFramePixelBuffer = [request sourceFrameByTrackID:currentInstruction.nextTrackID];
        
//        _transitionRender.transitionType = currentInstruction.transitionType;
//        [_transitionRender renderPixelBuffer:destinationFramePixels preVideoFramePixelBuffer:preVideoFramePixelBuffer nextVideoFramePixelBuffer:nextVideoFramePixelBuffer tweenFactor:tweenFactor];
    }
    
    return destinationFramePixels;
}

@end
