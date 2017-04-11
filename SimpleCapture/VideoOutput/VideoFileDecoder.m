//
//  VideoFileDecoder.m
//  SimpleCapture
//
//  Created by JFChen on 17/3/22.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "VideoFileDecoder.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <CoreVideo/CoreVideo.h>
#import <libyuv/libyuv.h>
#import "YUVFileReader.h"
#import "VideoTool.h"

//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
static const DDLogLevel ddLogLevel = DDLogLevelInfo;

static const NSString *SerialQueue = @"SerialQueue";

@interface VideoFileDecoder()
@property(nonatomic, strong) dispatch_queue_t decodeQueue;
@property(nonatomic, assign) BOOL cancleDecoding;
@property(nonatomic, strong) YUVFileReader *yuvFileReader;
@end

@implementation VideoFileDecoder

- (instancetype)init{
    self = [super init];
    if (self) {
        _decodeInterval = 40000;
        _decodeQueue = dispatch_queue_create([SerialQueue UTF8String], DISPATCH_QUEUE_SERIAL);
        _yuvFileReader = [YUVFileReader new];
    }
    return self;
}

- (void)invalidDecoder{
    _cancleDecoding = YES;
    dispatch_barrier_sync(_decodeQueue, ^{
        DDLogInfo(@"_decodequeue finish");
    });
}

- (void)dealloc{
    DDLogDebug(@"%s dealloc",__PRETTY_FUNCTION__);
}

- (void)decodeVideoWithVideoPath:(NSString *)videoPath{
    dispatch_async(_decodeQueue, ^{
        @autoreleasepool {
         [self decodeVideoVideo:videoPath];
        }
    });
}

- (void)decodeVideoVideo:(NSString *)videoPath{
    int m_frameCount = 0;
    AVFormatContext	*pFormatCtx = NULL;
    int				i, videoindex;
    AVCodecContext	*pCodecCtx;
    AVCodec			*pCodec;
    AVFrame         *pFrame;
    AVPacket        *packet;
    
    char input_str_full[500]={0};
    sprintf(input_str_full,"%s",[videoPath UTF8String]);
    DDLogDebug(@"inputPath %@",videoPath);
    
    av_register_all();
    avformat_network_init();
    pFormatCtx = avformat_alloc_context();
    
    int errorCode = avformat_open_input(&pFormatCtx,input_str_full,NULL,NULL);
    if( errorCode != 0){
        char *errbuf = malloc(sizeof(char)*100);
        av_strerror(errorCode, errbuf, 100);
        DDLogDebug(@"Couldn't open input stream. error: %s \n",errbuf);
        free(errbuf);
        return ;
    }
    if(avformat_find_stream_info(pFormatCtx,NULL)<0){
        DDLogDebug(@"Couldn't find stream information.\n");
        return;
    }
    
    
    videoindex=-1;
    for(i=0; i<pFormatCtx->nb_streams; i++)
        if(pFormatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO){
            videoindex=i;
            break;
        }
    if(videoindex==-1){
        DDLogDebug(@"Couldn't find a video stream.\n");
        return;
    }
    pCodecCtx=pFormatCtx->streams[videoindex]->codec;
    pCodec=avcodec_find_decoder(pCodecCtx->codec_id);
    if(pCodec==NULL){
        DDLogDebug(@"Couldn't find Codec.\n");
        return;
    }
    if(avcodec_open2(pCodecCtx, pCodec,NULL)<0){
        DDLogDebug(@"Couldn't open codec.\n");
        return;
    }
    
    pFrame=av_frame_alloc();
    packet=(AVPacket *)av_malloc(sizeof(AVPacket));
    
    DDLogDebug(@"[Format] %s",pFormatCtx->iformat->name);
    DDLogDebug(@"[Codec] %s", pCodecCtx->codec->name);
    DDLogDebug(@"[Width] %d [Height] %d", pCodecCtx->width, pCodecCtx->height);
    
    //TODO! decodeOneFrameData
    while(av_read_frame(pFormatCtx, packet)>=0 && !_cancleDecoding){
        int width = 0;
        int height = 0;
        PictureData outPicture;
        
        if (packet->stream_index == videoindex) {
            DDLogDebug(@"[dts] dts:%lld",packet->dts);
            
            usleep(_decodeInterval);
            
            if ([self decodeOneFrameData:&outPicture context:pCodecCtx avFrame:pFrame packet:packet width:&width height:&height] == 0) {
                DDLogDebug(@"[frameIndex] frameIndex:%d  framePts:%d", m_frameCount, outPicture.fat.captureStamp);
                ++m_frameCount;
                
                CVPixelBufferRef pixelBuff = [VideoTool allocPixelBufferFromPictureData:&outPicture];
                FreeBuffer(outPicture.iPlaneData);
                DDLogDebug(@"[framePixelBuffer] pixelBuff:%@",pixelBuff);
                if ([_delegate respondsToSelector:@selector(outPutPixelBuffer:)]) {
                    [_delegate outPutPixelBuffer:pixelBuff];
                }
                CVPixelBufferRelease(pixelBuff);
            }
        }
        
        av_free_packet(packet);
    }
    
    //decode the rest frame in the decoder
    while (!_cancleDecoding) {
        int width = 0;
        int height = 0;
        PictureData outPicture;
        
        usleep(_decodeInterval);
        
        DDLogDebug(@"decode rest frame");
        if ([self decodeOneFrameData:&outPicture context:pCodecCtx avFrame:pFrame packet:packet width:&width height:&height] == 0) {
            DDLogDebug(@"frameIndex:%d  framePts:%d", m_frameCount, outPicture.fat.captureStamp);
            ++m_frameCount;
            
            CVPixelBufferRef pixelBuff = [VideoTool allocPixelBufferFromPictureData:&outPicture];
            FreeBuffer(outPicture.iPlaneData);
            DDLogDebug(@"pixelBuff:%@",pixelBuff);
            if ([_delegate respondsToSelector:@selector(outPutPixelBuffer:)]) {
                [_delegate outPutPixelBuffer:pixelBuff];
            }
            //CVPixelBufferRelease(pixelBuff);
        }else{
            return;
        }
    }
    
    avcodec_close(pCodecCtx);
    avformat_close_input(&pFormatCtx);
}

- (BOOL)decodeOneFrameData:(PictureData* )outPicture
                   context:(AVCodecContext *)m_context
                   avFrame:(AVFrame *)m_avFrame
                    packet:(AVPacket *)m_avPacket
                     width:(int *)m_width
                    height:(int *)m_height{
    int gotFrame = 0;
    int len = avcodec_decode_video2(m_context, m_avFrame, &gotFrame, m_avPacket);
    if (len < 0) {
        DDLogDebug(@"decodeVideoData fail");
        return -1;
    }
    if (!gotFrame) {
        DDLogDebug(@"decoder got nothing");
        return -1;
    }
    
    outPicture->iWidth = m_avFrame->width;
    outPicture->iHeight = m_avFrame->height;
    outPicture->iFormat = kMediaLibraryPictureFmtI420;
    *m_width = m_avFrame->width;
    *m_height = m_avFrame->height;
    
    if((outPicture->iWidth % 2) == 1 || (outPicture->iHeight % 2) == 1) {
        DDLogDebug(@"width:%d  heigh:%d", *m_width, *m_height);
    }
    
    int pictureDataSize = outPicture->iHeight * (m_avFrame->linesize[0] + m_avFrame->linesize[1] + m_avFrame->linesize[2]);
    unsigned char* pictureData = (unsigned char*)AllocBuffer(pictureDataSize,false,0);
    if (pictureData == NULL) {
        DDLogDebug(@"failed to allocate memory for new frame.");
        return -1;
    }
    
    int planeOffset = 0;
    for (int i = 0; i < 3; ++i) {
        outPicture->iStrides[i] = m_avFrame->linesize[i];
        outPicture->iPlaneOffset[i] = planeOffset;
        if (m_avFrame->linesize[i] > 0) {
            int planeSize = 0;
            if (i == 0) {
                planeSize = m_avFrame->height * m_avFrame->linesize[i];
            } else {
                planeSize = m_avFrame->height / 2 * m_avFrame->linesize[i];
            }
            memcpy(pictureData + planeOffset, m_avFrame->data[i], planeSize);
            planeOffset += planeSize;
        }
    }
    
    outPicture->dataType = kMediaLibraryPictureDataPlaneData;
    outPicture->iPlaneData = pictureData;
    outPicture->iPlaneDataSize = pictureDataSize;
    outPicture->fat.captureStamp = (uint32_t)m_avFrame->pkt_pts;
    
    if (m_avFrame->color_range == AVCOL_RANGE_JPEG) {
        // full range
        outPicture->pixelFormat = kCVPixelFormatType_420YpCbCr8PlanarFullRange;
    } else {
        // limited range
        outPicture->pixelFormat = kCVPixelFormatType_420YpCbCr8Planar;
    }
    if (m_avFrame->colorspace == AVCOL_SPC_BT709) {
        // 709
        outPicture->matrixKey = kCVImageBufferYCbCrMatrix_ITU_R_709_2;
    } else {
        // 601
        outPicture->matrixKey = kCVImageBufferYCbCrMatrix_ITU_R_601_4;
    }
    
    return 0;
}

#pragma mark - C

static unsigned int gHeadSignature = 0xEAAEEAAE;
static unsigned int gTailSignature = 0xCDCEECDC;

void* AllocBuffer(unsigned int size, bool clear, int alignment)
{
    unsigned int realsize = size + sizeof(BufferHeader) + sizeof(BufferTail);
    if (size > 0)
    {
        BufferHeader *header = (BufferHeader*)malloc(realsize);
        if (header == NULL)
        {
            DDLogDebug(@"ERROR! Alloc Failed with size %d", realsize);
            return NULL;
        }
        
        header->iHeadSignature = gHeadSignature;
        header->iTailSignature = gTailSignature;
        header->iBufSize = size;
        
        void *ret = (header + 1);
        if (clear)
            memset(ret, 0, size);
        
        BufferTail *tail = (BufferTail*)((char*)ret + size);
        tail->iTailSignature = gTailSignature;
        return ret;
    }
    
    return NULL;
}

void FreeBuffer(void *buffer)
{
    if (buffer)
    {
        BufferHeader *header = (BufferHeader*)((char*)buffer - sizeof(BufferHeader));
        if (buffer)
        {
            free(header);   // not buffer !!
        }
    }
}

@end
