//
//  YUVFileTransform.m
//  SimpleCapture
//
//  Created by JFChen on 2017/3/31.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "YUVFileTransform.h"
#import "YUVFileReader.h"
#import "VideoFileDecoder.h"
#import "VideoTool.h"
#import "VideoEncoder.h"
#import "H264VideoDecoder.h"
#import "SCCommon.h"

@interface YUVFileTransform() <VideoEncoderDelegate,H264VideoDecoderDelegate>
@property(nonatomic, strong) YUVFileReader *yuvfilere;
@property(nonatomic, strong) dispatch_queue_t encodeQueue;
@property(nonatomic, strong) dispatch_queue_t readFileQueue;
@property(nonatomic, strong) VideoEncoder *videoEncoder;
@property(nonatomic, strong) H264VideoDecoder *h264dec;
@property(nonatomic, copy)   NSString *selectedFileName;
@property(nonatomic, copy)   NSString *outPutFileName;
@end

@implementation YUVFileTransform{
    VideoFormat format;
    bool _isNoFirstT;
    
    int _frameIndexRead;
    int _farmeIndexEncode;
    int _frameIndexDecode;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _whDenominator = 3;
        _bitrate = 600;
        _encodeQueue = dispatch_queue_create("encodeYUVQueue", NULL);
        _readFileQueue = dispatch_queue_create("readFileQueue", NULL);
        _videoEncoder = [VideoEncoder new];
        [_videoEncoder setDelegate:self queue:_encodeQueue];
        _h264dec = [H264VideoDecoder new];
        _h264dec.delegate = self;
    }
    return self;
}

- (void)encoderStartWithInputFileName:(NSString *)inputFile{
    self.selectedFileName = inputFile;
    format = [YUVFileReader analyseVideoFormatWithFileName:inputFile];
    self.yuvfilere = [[YUVFileReader alloc] initWithFileFormat:format];    
    
    CGSize size = CGSizeMake(format.width/_whDenominator, format.heigh/_whDenominator);
    self.outPutFileName = [NSString stringWithFormat:@"%dx%d_%@_%@",(int)size.width,(int)size.height,self.selectedFileName,[NSDate date]];
    self.videoEncoder.videoSize = size;
    self.videoEncoder.frameRate = 24;
    self.videoEncoder.bitrate = _bitrate;
    [self.videoEncoder beginEncode];
    
    dispatch_async(_readFileQueue, ^{
        
        NSData *yuvData = [self.yuvfilere readOneFrameYUVDataWithFile:inputFile error:nil];

        while (yuvData && yuvData.length > 0) {
            @autoreleasepool {
                uint8_t *picBytes= (uint8_t *)[yuvData bytes];
                
                PictureData picData;
                picData.iWidth = format.width;
                picData.iHeight = format.heigh;
                picData.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
                picData.matrixKey = kCVImageBufferYCbCrMatrix_ITU_R_601_4;
                picData.iPlaneData = picBytes;
                picData.dataType = kMediaLibraryPictureDataPlaneData;
                picData.iStrides[0] = format.width;
                picData.iPlaneOffset[0] = 0;
                picData.iStrides[1] = format.width/2;
                picData.iPlaneOffset[1] = format.width*format.heigh;
                picData.iStrides[2] = format.width/2;
                picData.iPlaneOffset[2] = format.width*format.heigh+format.width/2*format.heigh/2;
                
                CVPixelBufferRef pixelBuffer = [VideoTool allocPixelBufferFromPictureData:&picData];
                CMSampleBufferRef sampleBuffer = [VideoTool allocSampleBufRefFromPixelBuffer:pixelBuffer];
                [self.videoEncoder encode:sampleBuffer];
                
                /*// 从文件读取的
                if (_delegate && [_delegate respondsToSelector:@selector(getYUVPixelBuffer:)]) {
                    [_delegate getYUVPixelBuffer:pixelBuffer];
                }*/
                
                CFRelease(sampleBuffer);
                CVPixelBufferRelease(pixelBuffer);
                NSLog(@"FrameIndexRead:%d",_frameIndexRead++);
                yuvData = [self.yuvfilere readOneFrameYUVDataWithFile:inputFile error:nil];
            }
        }
        
        [self.videoEncoder endEncode];
    });
}

#pragma mark - VideoEncoderDelegate

- (void) encoderOutput:(CMSampleBufferRef)sampleBuf{
    
    NSLog(@"FrameIndexEncode:%d",_farmeIndexEncode++);
    
    [VideoTool printVideoFrameInfo:sampleBuf];
    
    // Check if we have got a key frame first
    CMSampleBufferRef sampleBuffer = sampleBuf;
    bool isKeyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuf, true), 0)), kCMSampleAttachmentKey_NotSync);
    if (isKeyframe)
    {
        CMFormatDescriptionRef viformat = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        //get sps
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(viformat, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(viformat, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // Found pps
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                
                if (!_isNoFirstT) {
                    _isNoFirstT = true;
                    [self.h264dec resetVideoSessionWithsps:[sps bytes] len:(uint32_t)sps.length pps:[pps bytes] ppsLen:(uint32_t)pps.length];
                }
                //[encoder.delegate pushVideoPPS:pps SPS:sps pts:(uint32_t)(time.value)];
            }
        }
    }
    
    //get dts
    //    CMTime dtstime = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
    //    uint32_t dts = CMTimeGetSeconds(dtstime);
    //get pts
    //    CMTime ptstime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    //    uint32_t pts = CMTimeGetSeconds(ptstime);
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    NSMutableData* data = nil;
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        VideoFrameTypeIos frameType = VideoFrameUnknow;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            //            NSLog(@"bufferoffset = %lu", bufferOffset);
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            if ( data ) {
                //                char* len = dataPointer+bufferOffset+AVCCHeaderLength;
                //                VideoFrameTypeIos frameType = [encoder.delegate getFrameType:len[0]];
                const Byte* lengthString = [VideoTool valueForLengthString:NALUnitLength];
                NSData *lenField=[[NSData alloc] initWithBytesNoCopy:(void*)lengthString length:4 freeWhenDone:NO];
                [data appendData:lenField];
                [data appendBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            }
            else
            {
                char* len = dataPointer+bufferOffset+AVCCHeaderLength;
                frameType = [VideoTool getFrameType:len[0]];
                const Byte* lengthString = [VideoTool valueForLengthString:NALUnitLength];
                NSData *lenField=[[NSData alloc] initWithBytesNoCopy:(void*)lengthString length:4 freeWhenDone:NO];
                data = [[NSMutableData alloc] initWithCapacity:0];
                [data appendData:lenField];
                [data appendBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            }
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
        [self.h264dec decodeFramCMSamplebufferh264Data:[data bytes] h264DataSize:data.length];
//        [encoder.delegate pushVideoData:data frameType:frameType pts:(uint32_t)(time.value) dts:(uint32_t)(time.value)];
    }
}

#pragma mark H264VideoDecoderDelegate

- (void)decodedPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    
    if (_delegate && [_delegate respondsToSelector:@selector(getYUVPixelBuffer:)]) {
        [_delegate getYUVPixelBuffer:pixelBuffer];
    }
    
    uint8_t *yuv420Pointer = NULL;
    int yuv420Length = 0;
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int heigh = (int)CVPixelBufferGetHeight(pixelBuffer);
    [VideoTool allyuv420FromCVpixelBuffer:pixelBuffer
                                    width:width
                                    heigh:heigh
                         outPutYUV420Data:&yuv420Pointer
                                yuvLength:&yuv420Length];
    
    NSData *yuv420Data = [NSData dataWithBytes:yuv420Pointer length:yuv420Length];
    
    NSLog(@"FrameIndexDecode:%d",_frameIndexDecode++);
    [self.yuvfilere writeYUVDataToFile:self.outPutFileName data:yuv420Data error:nil];
    free(yuv420Pointer);
}

@end
