#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>

@interface VideoCapture : NSObject

@property (readonly) CALayer *capturePreviewLayer;
@property (readonly) CALayer *playbackLayer;
@property (readonly) UIView *processorPreviewView;
@property int actuallyBitrate;
@property int actuallyFps;
@property (readonly) NSString *videoInfo;

- (id) init;
- (void) setConfig:(VideoConfig)config;
- (void) start;
- (void) stop;
- (void) setTargetBitrate:(int)bitrateInKbps;
- (void) setTapPosition:(CGPoint)position;

@end
