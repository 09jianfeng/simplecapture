//
//  Common.h
//  SimpleCapture
//
//  Created by Yao Dong on 16/1/23.
//  Copyright © 2016年 duowan. All rights reserved.
//

#ifndef Common_h
#define Common_h

#define CHECK_STATUS(s) if(s != noErr) { NSLog(@"Status %d, %s:%d", (int)s, __FUNCTION__, __LINE__); }

typedef enum {
    VideoCameraPositionFront,
    VideoCameraPositionBack,
}VideoCameraPosition;

typedef enum {
    VideoCaptureSize1920x1080,
    VideoCaptureSize1280x720,
    VideoCaptureSize640x480,
}VideoCaptureSizePreset;

typedef enum {
    VideoOrientationLandscape,
    VideoOrientationPortrait,
}VideoOrientation;

typedef struct tagVideoConfig {
    VideoCameraPosition cameraPosition;
    VideoOrientation orientation;
    VideoCaptureSizePreset preset;
    int frameRate;
    int bitrateInKbps;
    bool enableStabilization;
    bool enableBeautyFilter;
    OSType devicePixelFormatType;
    OSType outputPixelFormatType;
} VideoConfig;

uint64_t GetTickCount64();

enum MediaLibraryPictureFormat
{
    kMediaLibraryPictureFmtUnknown = 0,
    kMediaLibraryPictureFmtI410,  /* Planar YUV 4:1:0 Y:U:V */
    kMediaLibraryPictureFmtI411,  /* Planar YUV 4:1:1 Y:U:V */
    kMediaLibraryPictureFmtI420,  /* Planar YUV 4:2:0 Y:U:V 8-bit */
    kMediaLibraryPictureFmtI422,  /* Planar YUV 4:2:2 Y:U:V 8-bit */
    kMediaLibraryPictureFmtI440,  /* Planar YUV 4:4:0 Y:U:V */
    kMediaLibraryPictureFmtI444,  /* Planar YUV 4:4:4 Y:U:V 8-bit */
    kMediaLibraryPictureFmtNV12,  /* 2 planes Y/UV 4:2:0 */
    kMediaLibraryPictureFmtNV21,  /* 2 planes Y/VU 4:2:0 */
    kMediaLibraryPictureFmtNV16,  /* 2 planes Y/UV 4:2:2 */
    kMediaLibraryPictureFmtNV61,  /* 2 planes Y/VU 4:2:2 */
    kMediaLibraryPictureFmtYUYV,  /* Packed YUV 4:2:2, Y:U:Y:V */
    kMediaLibraryPictureFmtYVYU,  /* Packed YUV 4:2:2, Y:V:Y:U */
    kMediaLibraryPictureFmtUYVY,  /* Packed YUV 4:2:2, U:Y:V:Y */
    kMediaLibraryPictureFmtVYUY,  /* Packed YUV 4:2:2, V:Y:U:Y */
    kMediaLibraryPictureFmtRGB15, /* 15 bits RGB padded to 16 bits */
    kMediaLibraryPictureFmtRGB16, /* 16 bits RGB */
    kMediaLibraryPictureFmtRGB24, /* 24 bits RGB */
    kMediaLibraryPictureFmtRGB32, /* 24 bits RGB padded to 32 bits */
    kMediaLibraryPictureFmtRGBA,  /* 32 bits RGBA */
};

enum MediaLibraryPictureDataType
{
    kMediaLibraryPictureDataNull = 0,
    kMediaLibraryPictureDataPlaneData = 1,
    kMediaLibraryPictureDataIosPixelBuffer = 2,
    kMediaLibraryPictureDataAndroidSurface = 3,
};

struct FrameTraceAttribute
{
    uint32_t frameIndex;
    uint32_t frameType;
    uint32_t captureStamp;										// dts
    uint32_t recvStamp;
    uint32_t pendingStamp;
    uint32_t prepareDecodeStamp;
    uint32_t decodedStamp;
    uint32_t playStamp;											// ∂∂∂Øª∫≥ÂÀ„≥ˆµƒ∆⁄Õ˚≤•∑≈ ±º‰
    uint32_t prepareRenderStamp;								// ◊º±∏∞—÷°◊™µΩrenderQueueµƒ ±º‰
    uint32_t inRenderQueueStamp;								// ∑≈»ÎrenderQueueµƒ ±º‰
    uint32_t outRenderQueueStamp;								// ≥ˆrenderQueue ±º‰
    uint32_t renderStamp;										//  µº ‰÷»æµƒ ±º‰
    uint32_t decodedFrameId;									// æ≠π˝Ω‚¬Î∫Û÷ÿ–¬≈≈–ÚµƒframeId
    uint32_t pts;
    uint32_t m_audioRenderDelta;								// “Ù∆µ≤•∑≈delta
    bool bFastAccess;
    bool bDiscard;												// iosÕÀµΩ∫ÛÃ®µƒ ±∫Ú≤ªΩ‚¬Î,÷±Ω”∑µªÿ÷°∂™∆˙.
};

typedef struct PictureData
{
    enum MediaLibraryPictureFormat   iFormat;
    
    uint32_t    iWidth;
    uint32_t    iHeight;
    uint32_t    iStrides[4];       // strides for each color plane.
    uint32_t    iPlaneOffset[4];   // byte offsets for each color plane in iPlaneData.
    uint32_t    iPlaneDataSize;    // the total buffer size of iPlaneData.
    
    // NOTICE: iPlaneData buffer must be created by AllocBuffer/AllocBufferFromeCache.
    int32_t		idxPic;
    struct FrameTraceAttribute fat;
    
    OSType      pixelFormat;
    CFStringRef matrixKey;
    
    enum MediaLibraryPictureDataType dataType;
    union {
        void        *iPlaneData;
        void        *iosPixelBuffer;
        void        *androidSurface;
    };
}PictureData;

typedef struct BufferHeader
{
    unsigned int iHeadSignature;
    unsigned int iBufSize;
    unsigned int iTailSignature;
}BufferHeader;

typedef struct BufferTail
{
    unsigned int iTailSignature;
}BufferTail;

#endif /* Common_h */
