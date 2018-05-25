//
//  GPUImageGuidedFilter.h
//  GPUImage
//
//  Created by xuqing on 19/11/15.
//  Copyright © 2015 Brad Larson. All rights reserved.
//

#import "GPUImageFilter.h"
@interface GPUImageGuidedFilter : GPUImageFilter
{
    GLint  EpsUniform;
    GLint  StepUniform;
    GLint  whitenessUniform;
}

@property(nonatomic, readwrite)CGFloat uEps;
@property(nonatomic, readwrite)CGFloat step;
@property(nonatomic, readwrite)CGFloat whiteness;
@property(readwrite, nonatomic, copy) NSArray *redControlPoints;
@property(readwrite, nonatomic, copy) NSArray *greenControlPoints;
@property(readwrite, nonatomic, copy) NSArray *blueControlPoints;
@property(readwrite, nonatomic, copy) NSArray *rgbCompositeControlPoints;

// Initialization and teardown
- (id)initWithACVData:(NSData*)data;
- (void)changeGammaArr:(CGFloat)newValue;
// This lets you set all three red, green, and blue tone curves at once.
// NOTE: Deprecated this function because this effect can be accomplished
// using the rgbComposite channel rather then setting all 3 R, G, and B channels.
- (void)setRGBControlPoints:(NSArray *)points DEPRECATED_ATTRIBUTE;

- (void)setPointsWithACV:(NSString*)curveFilename;
- (void)setPointsWithACVURL:(NSURL*)curveFileURL;

// Curve calculation
- (NSMutableArray *)getPreparedSplineCurve:(NSArray *)points;
- (NSMutableArray *)splineCurve:(NSArray *)points;
- (NSMutableArray *)secondDerivative:(NSArray *)cgPoints;
- (void)updateToneCurveTexture;

@end
