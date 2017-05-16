//
//  FFMPEGDecodeFilter.h
//  SimpleCapture
//
//  Created by JFChen on 2017/5/11.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

typedef NS_ENUM(int,VideoFrameType) {
    kVideoUnknowFrame = 0xFF,   // 8bits
    kVideoIFrame = 0,
    kVideoPFrame,
    kVideoBFrame,
    kVideoPFrameSEI = 3,        // 0 - 3 is same with YY video packet's frame type.
    kVideoIDRFrame,
    kVideoSPSFrame,
    kVideoPPSFrame,
    kVideoHeaderFrame,
    kVideoEncodedDataFrame
};

@interface MediaSample : NSObject
@property (nonatomic, assign) CMSampleBufferRef sampleBuffer;
@property (nonatomic, assign) uint64_t pts;
@property (nonatomic, assign) uint64_t dts;
@property (nonatomic, assign) NSDictionary* filterParams;
@end

@interface FrameDesc : NSObject
@property(nonatomic, assign) VideoFrameType iFrameType;
@property(nonatomic, assign) unsigned int iPts;
@property(nonatomic, assign) unsigned int iRealPts;
@end

@protocol FFMPEGDecodeFilterDelegate <NSObject>
- (void)decodedPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

@interface FFMPEGDecodeFilter : NSObject
@property(nonatomic, weak) id<FFMPEGDecodeFilterDelegate> delegate;

- (int)processMediaSample:(MediaSample *)mediaSample from:(id)upstream;

@end
