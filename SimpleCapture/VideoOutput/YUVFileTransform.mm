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
#import "VideoTool.h"
#import "BitrateMonitor.h"

@interface YUVFileTransform() <VideoEncoderDelegate,H264VideoDecoderDelegate>
@property(nonatomic, strong) YUVFileReader *yuvfilere;
@property(nonatomic, strong) dispatch_queue_t encodeQueue;
@property(nonatomic, strong) dispatch_queue_t encodeCallBackQueue;
@property(nonatomic, strong) dispatch_queue_t readFileQueue;
@property(nonatomic, strong) VideoEncoder *videoEncoder;
@property(nonatomic, strong) H264VideoDecoder *h264dec;
@property(nonatomic, copy)   NSString *selectedFileName;
@property(nonatomic, copy)   NSString *outPutFileName;

@property(nonatomic, retain) NSMutableArray<FrameContext*> *decodePixelbuffers;
@end

@implementation YUVFileTransform{
    VideoFormat format;
    bool _isNoFirstT;
    
    int _frameIndexRead;
    int _farmeIndexEncode;
    int _frameIndexDecode;
    int _frameIndexWrite;
    dispatch_source_t _encoderTimer;
    dispatch_source_t _fileReaderTimer;
    NSMutableArray *_fileReaderBuffer;
    
    //bitrate and fps
    BitrateMonitor _bitrateMonitor;
    int _actuallyBitrate;
    int _actuallyFps;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _whDenominator = 3;
        _bitrate = 600;
        _encodeQueue = dispatch_queue_create("encodeQueue", NULL);
        _encodeCallBackQueue = dispatch_queue_create("encodeCallBackYUVQueue", NULL);
        _readFileQueue = dispatch_queue_create("readFileQueue", NULL);
        _videoEncoder = [VideoEncoder new];
        [_videoEncoder setDelegate:self queue:_encodeCallBackQueue];
        _h264dec = [H264VideoDecoder new];
        _h264dec.delegate = self;
        _decodePixelbuffers = [NSMutableArray new];
        _fileReaderBuffer = [NSMutableArray new];
    }
    return self;
}

- (void)encoderStartWithInputFileName:(NSString *)inputFile{
    _frameIndexRead = 0;
    _frameIndexDecode = 0;
    _farmeIndexEncode = 0;
    _frameIndexWrite = 0;
    
    [self readYUVDataFromeFile:inputFile];
    [self beginEncode];
    
}

- (void)readYUVDataFromeFile:(NSString *)inputFile{
    self.selectedFileName = inputFile;
    format = [YUVFileReader analyseVideoFormatWithFileName:inputFile];
    self.yuvfilere = [[YUVFileReader alloc] initWithFileFormat:format];
    
    _fileReaderTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _readFileQueue);
    dispatch_source_set_timer(_fileReaderTimer, DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_fileReaderTimer, ^{
        //最多缓存10帧
        if (_fileReaderBuffer.count < 10) {
            NSData *yuvData = [self.yuvfilere readOneFrameYUVDataWithFile:inputFile error:nil];
            if (yuvData && yuvData.length > 0) {
                [_fileReaderBuffer addObject:yuvData];
            }else{
                dispatch_cancel(_fileReaderTimer);
            }
        }else{
            NSLog(@"缓存中超过10帧");
        }
    });
    dispatch_resume(_fileReaderTimer);
}

- (void)beginEncode{
    CGSize size = CGSizeMake(format.width/_whDenominator, format.heigh/_whDenominator);
    self.outPutFileName = [NSString stringWithFormat:@"%dx%d_%@_%@",(int)size.width,(int)size.height,self.selectedFileName,[NSDate date]];
    self.videoEncoder.videoSize = size;
    self.videoEncoder.frameRate = 24;
    self.videoEncoder.bitrate = _bitrate;
    [self.videoEncoder setTargetBitrate:_bitrate];
    [self.videoEncoder beginEncode];
    
    while (_fileReaderBuffer.count < 10) {
        NSLog(@"等待缓存文件中");
        usleep(1000);
    }
    
    _encoderTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _encodeQueue);
    dispatch_source_set_timer(_encoderTimer, DISPATCH_TIME_NOW, 0.04 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_encoderTimer, ^{
        if (_fileReaderBuffer && _fileReaderBuffer.count > 0) {
            NSData *yuvData = _fileReaderBuffer[0];
            [_fileReaderBuffer removeObjectAtIndex:0];
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
        }else{
            dispatch_cancel(_encoderTimer);
            [self.videoEncoder endEncode];
            [self clearBufferAndWriteToFile];
        }
    });
    dispatch_resume(_encoderTimer);
}

#pragma mark - VideoEncoderDelegate

- (void) encoderOutput:(CMSampleBufferRef)sampleBuf frameCont:(FrameContext *)frameCont{
    NSLog(@"FrameIndexEncode:%d",_farmeIndexEncode++);
    
    
    [VideoTool printVideoFrameInfo:sampleBuf];
    char *dataHead = NULL;
    CMBlockBufferRef blockbuf = CMSampleBufferGetDataBuffer(sampleBuf);
    CMBlockBufferGetDataPointer(blockbuf, 0, 0, 0, (char**)&dataHead);
    VideoFrameTypeIos frametype = [VideoTool getFrameType:dataHead[4]];
    frameCont.frameType = frametype;
    
    size_t sampleSize = CMSampleBufferGetTotalSampleSize(sampleBuf);
    dispatch_async(dispatch_get_main_queue(), ^{
        _bitrateMonitor.appendDataSize((int)sampleSize);
        _actuallyBitrate = _bitrateMonitor.actuallyBitrate();
        _actuallyFps = _bitrateMonitor.actuallyFps();
        NSLog(@"_actuallyBitrate: %dkb   _actuallyFps:%d",_actuallyBitrate/1000,_actuallyFps);
    });
    
    // Check if we have got a key frame first
    CMSampleBufferRef sampleBuffer = sampleBuf;
    bool isKeyframe = !CFDictionaryContainsKey( (CFDictionaryRef)(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuf, true), 0)), kCMSampleAttachmentKey_NotSync);
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
                    [self.h264dec resetVideoSessionWithsps:(const uint8_t *)[sps bytes] len:(uint32_t)sps.length pps:(const uint8_t *)[pps bytes] ppsLen:(uint32_t)pps.length];
                }
                //[encoder.delegate pushVideoPPS:pps SPS:sps pts:(uint32_t)(time.value)];
            }
        }
    }
    
    
    NSMutableData* data = nil;
    {//从cmsampleBuffer中提取nalu，然后从nalu中提取完整的h264data
        CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        size_t length, totalLength;
        char *dataPointer;
        OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
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
        }
        
        NSString *h264fileName = [NSString stringWithFormat:@"%dkb_%@_%@_h.264",_bitrate,self.selectedFileName,[NSDate date]];
        [self.yuvfilere writeH264DataToFile:h264fileName data:data error:nil];
        [self.h264dec decodeFramCMSamplebufferh264Data:(const uint8_t *)[data bytes] h264DataSize:data.length frameCon:frameCont];
    }
}

#pragma mark H264VideoDecoderDelegate

- (void)clearBufferAndWriteToFile{
    //end out pixelbuffer
    while (!(_frameIndexRead == _frameIndexDecode)) {
        sleep(40);
    }
    
    for (int i = 0; i < _decodePixelbuffers.count ; i++) {
        [self pixelBufferToScreenAndToFile:_decodePixelbuffers[i].decodedPixelBuffer];
    }

}

- (void)decodedPixelBuffer:(CVPixelBufferRef)pixelBuffer frameCont:(FrameContext *)frameCon{
    NSLog(@"FrameIndexDecode:%d",_frameIndexDecode++);
    
    CVPixelBufferRetain(pixelBuffer);
    frameCon.decodedPixelBuffer = pixelBuffer;
    [self addFrameToBuffer:frameCon];
    
    if ([self haveAvaliableFrame]) {
        [self pixelBufferToScreenAndToFile:_decodePixelbuffers[0].decodedPixelBuffer];
        CVPixelBufferRelease(_decodePixelbuffers[0].decodedPixelBuffer);
        [_decodePixelbuffers removeObjectAtIndex:0];
    }
}

- (void)addFrameToBuffer:(FrameContext*)frameContext{
    if (_decodePixelbuffers.count <= 0) {
        [_decodePixelbuffers addObject:frameContext];
        return;
    }
    
    int i = (int)_decodePixelbuffers.count;
    for (; i > 0; i--) {
        if (_decodePixelbuffers[i-1].pts < frameContext.pts) {
            [_decodePixelbuffers insertObject:frameContext atIndex:i];
            break;
        }
    }
    if (i <= 0) {
        [_decodePixelbuffers insertObject:frameContext atIndex:0];
    }
}

- (BOOL)haveAvaliableFrame{
    if (_decodePixelbuffers.count <= 0) {
        return NO;
    }
    
    if (_decodePixelbuffers[0].frameType == VideoFrameI || _decodePixelbuffers[0].frameType == VideoFrameIDR){
        return YES;
    }
    
    int pframeCount = 0;
    for (FrameContext *frameCon in _decodePixelbuffers) {
        if (frameCon.frameType == VideoFrameP) {
            pframeCount++;
        }else{
        }
    }
    
    return pframeCount >= 2;
}

- (void)pixelBufferToScreenAndToFile:(CVPixelBufferRef)pixelBuffer{
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
    [self.yuvfilere writeYUVDataToFile:self.outPutFileName data:yuv420Data error:nil];
    free(yuv420Pointer);
}

@end
