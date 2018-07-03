//
//  AVAssetDecodeEncode.h
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import "VideoItem.h"
#import "AudioItem.h"
#import "VideoFileKit.h"

@interface AVAssetDecodeEncode : NSObject
/**
 * @brief 源视频asset
 */
@property (nonatomic, strong, readonly) AVAsset * originAsset;

/**
 * Indicates whether video composition is enabled for export, and supplies the instructions for video composition.
 *
 * You can observe this property using key-value observing.
 */
@property (nonatomic, copy) AVVideoComposition * videoComposition;

/**
 * Indicates whether non-default audio mixing is enabled for export, and supplies the parameters for audio mixing.
 */
@property (nonatomic, copy) AVAudioMix * audioMix;

/**
 * The type of file to be written by the session.
 *
 * The value is a UTI string corresponding to the file type to use when writing the asset.
 * For a list of constants specifying UTIs for standard file types, see `AV Foundation Constants Reference`.
 *
 * You can observe this property using key-value observing.
 */
@property (nonatomic, copy) NSString * outputFileType;

/**
 * The URL of the export session’s output.
 *
 * You can observe this property using key-value observing.
 */
@property (nonatomic, copy) NSURL *outputURL;

/**
 * The settings used for input video track.
 *
 * The dictionary’s keys are from <CoreVideo/CVPixelBuffer.h>.
 */
@property (nonatomic, copy) NSDictionary *videoInputSettings;

/**
 * The settings used for encoding the video track.
 *
 * A value of nil specifies that appended output should not be re-encoded.
 * The dictionary’s keys are from <AVFoundation/AVVideoSettings.h>.
 */
@property (nonatomic, copy) NSDictionary *videoSettings;

/**
 * The settings used for encoding the audio track.
 *
 * A value of nil specifies that appended output should not be re-encoded.
 * The dictionary’s keys are from <CoreVideo/CVPixelBuffer.h>.
 */
@property (nonatomic, copy) NSDictionary *audioSettings;

/**
 * The time range to be exported from the source.
 *
 * The default time range of an export session is `kCMTimeZero` to `kCMTimePositiveInfinity`,
 * meaning that (modulo a possible limit on file length) the full duration of the asset will be exported.
 *
 * You can observe this property using key-value observing.
 *
 */
@property (nonatomic, assign) CMTimeRange timeRange;

/**
 * The result outputSize
 */
@property (nonatomic, assign) CGSize outputSize;

@property (nonatomic, assign) CGFloat rotateAngle;

/**
 * The crop rect
 */
@property (nonatomic, assign) CGRect cropRect;

/**
 * Indicates whether the movie should be optimized for network use.
 *
 * You can observe this property using key-value observing.
 */
@property (nonatomic, assign) BOOL shouldOptimizeForNetworkUse;

/**
 * The metadata to be written to the output file by the export session.
 */
@property (nonatomic, copy) NSArray *metadata;

/**
 * Describes the error that occurred if the export status is `AVAssetExportSessionStatusFailed`
 * or `AVAssetExportSessionStatusCancelled`.
 *
 * If there is no error to report, the value of this property is nil.
 */
@property (nonatomic, strong, readonly) NSError *error;

/**
 * The progress of the export on a scale from 0 to 1.
 *
 *
 * A value of 0 means the export has not yet begun, 1 means the export is complete.
 *
 * Unlike Apple provided `AVAssetExportSession`, this property can be observed using key-value observing.
 */
@property (nonatomic, assign, readonly) float progress;

/**
 * The status of the export session.
 *
 * For possible values, see “AVAssetExportSessionStatus.”
 *
 * You can observe this property using key-value observing. (TODO)
 */
@property (nonatomic, assign, readonly) AVAssetExportSessionStatus status;

- (instancetype)initWithVideoItems:(NSArray<VideoItem *> *)videoItems audioItems:(NSArray<AudioItem *> *)audioItems;

- (void)exportCropAsynchronouslyWithCompletionHandler:(void (^)(void))handler avasset:(AVAsset *)videoAVAsset;

/**
 * Cancels the execution of an export session.
 *
 * You can invoke this method when the export is running.
 */
- (void)cancelExport;

@end
