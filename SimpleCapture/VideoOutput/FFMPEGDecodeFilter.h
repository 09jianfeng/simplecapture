//
//  FFMPEGDecodeFilter.h
//  SimpleCapture
//
//  Created by JFChen on 2017/5/11.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface MediaSample : NSObject
@property (nonatomic, assign) CMSampleBufferRef sampleBuffer;
@property (nonatomic, assign) uint64_t pts;
@property (nonatomic, assign) uint64_t dts;
@property (nonatomic, assign) NSDictionary* filterParams;
@end


@protocol FFMPEGDecodeFilterDelegate <NSObject>
- (void)decodedPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

@interface FFMPEGDecodeFilter : NSObject
@property(nonatomic, weak) id<FFMPEGDecodeFilterDelegate> delegate;

- (int)processMediaSample:(MediaSample *)mediaSample from:(id)upstream;

@end
