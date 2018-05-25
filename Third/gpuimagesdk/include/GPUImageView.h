#import <UIKit/UIKit.h>
#import "GPUImageContext.h"

typedef enum {
    kGPUImageFillModeStretch,                       // Stretch to fill the full view, which may distort the image outside of its normal aspect ratio
    kGPUImageFillModePreserveAspectRatio,           // Maintains the aspect ratio of the source image, adding bars of the specified background color --->Inner Fit(no crop)
    kGPUImageFillModePreserveAspectRatioAndFill     // Maintains the aspect ratio of the source image, zooming in on its center to fill the view--->Outer Fit(crop first and then zoom)
} GPUImageFillModeType; 

/**
 UIView subclass to use as an endpoint for displaying GPUImage outputs
 */
@interface GPUImageView : UIView <GPUImageInput>
{
    GPUImageRotationMode inputRotation;
}

/** The fill mode dictates how images are fit in the view, with the default being kGPUImageFillModePreserveAspectRatio
 */
@property(readwrite, nonatomic) GPUImageFillModeType fillMode;

/** This calculates the current display size, in pixels, taking into account Retina scaling factors
 */
@property(readonly, nonatomic) CGSize sizeInPixels;

@property(nonatomic) BOOL enabled;

/** Handling fill mode
 
 @param redComponent Red component for background color
 @param greenComponent Green component for background color
 @param blueComponent Blue component for background color
 @param alphaComponent Alpha component for background color
 */
- (void)setBackgroundColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent alpha:(GLfloat)alphaComponent;

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue;
- (id)initWithFrame:(CGRect)frame; ///EK 2015-9-6 USING_GPU_PROC_FOR_VIDEO_STREAM
@end
