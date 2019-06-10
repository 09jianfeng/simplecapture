#pragma once

#include <stddef.h>
#include <string.h>
#include "inttypes.h"

enum enabletype {DISABLE_FUNCTION = 0, ENABLE_FUNCTION};
enum streamtype {STREAM_AUDIO = 0, STREAM_VIDEO};
enum actiontype {MAY_ACTION = 0, MUST_ACTION};
enum ConnectionType {TCP_CONNECTION = 0, UDP_CONNECTION};

class MediaMutex;

#if (!defined(ANDROID))
#include <CoreFoundation/CoreFoundation.h>
#include <CoreVideo/CVPixelBuffer.h>
#endif

enum LogLevel
{
	kLogTrace = 0,
	kLogDebug,
	kLogInfo,
	kLogWarning,
	kLogError,
	kLogAssert,
};

enum LogModule
{
	kLogUnknown,
    
	/// platform layer modules.
	kLogPlatform = 100, // platform module start
	kLogCodec,
	kLogAudio,
	kLogVideo,
	kLogSocket,
	kLogTaskQueue,
	kLogBuffer,
	KLogP2p,
    
	/// middle layer modules.
	kLogBiz = 1000, // biz module start
	kLogCache,
	kLogLink,
	kLogProtocol,
	kLogSession,
	kLogJob,
	kLogCall,
	kLogRecorder,
	kLogPlayer,
	kLogParser,
    kLogJbuffer,
	/// wrapper layer modules.
	kLogWrapper = 2000,
};

enum MediaLibraryNetworkType
{
    kMediaLibraryNetworkTypeUnknown = 0,
    kMediaLibraryNetworkTypeWifi = 3,
    kMediaLibraryNetworkType2G = 1,
    kMediaLibraryNetworkType3G = 2,
    kMediaLibraryNetworkType4G = 4,
    kMediaLibraryNetworkTypeLegacy = 10,
};

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

typedef void (*MediaLibraryApplicationCallback)(int cmd, void *param);

enum MediaLibraryApplicationEvent
{
    /// application is going to background.
    /// param : NULL
    kMediaLibraryAppEventBackground = 1,
    
    /// application is going to foreground.
    /// param : NULL
    kMediaLibraryAppEventForeground,
    
    // screen locked/unlocked event is reserved, and nothing to be cared about on ios/android.
    // ios: only take care about application background event.
    kMediaLibraryAppEventScreenLocked,
    kMediaLibraryAppEventScreenUnlocked,
    
    // the device's audio output volume was changed fparam = (0.0 ~ 1.0)
    kMediaLibraryAppEventAudioOutputVolumeChanged,
    
    // the device's audio route just changed. iparam = AudioInputRoute/AudioOutputRoute.
    kMediaLibraryAppEventAudioOutputRouteChanged,
    kMediaLibraryAppEventAudioInputRouteChanged,
    
    // ios: the device's audio device will not available after handling audio interruption, so the audio device need to be closed at same time.
    // the audio device need to be reopened after recieving interruption-ended.
    // android: reserved not used.
    // iparam - AudioInterruption.
    kMediaLibraryAppEventAudioInterruption,
    
    // ios: the iphone mediaserverd process died unexpectedly, all audio devices can't be used anymore.
    // the application need to be restarted to recover audio functions.
    // android: reserved not used.
    kMediaLibraryAppEventAudioFatalError,
};

struct MediaLibraryAppLogCmdParam
{
    LogLevel iLevel;
    LogModule iModule;
    const char *iText;
};

enum MediaLibraryApplicationCommand
{
    // return the current audio route.
    kMediaLibraryAppCmdGetAudioInputRoute,
    kMediaLibraryAppCmdGetAudioOutputRoute,
    
    // get current audio output volume (0.0 ~ 1.0)
    kMediaLibraryAppCmdGetAudioOutputVolume,
    
    // param: int - set to 1 if application is in background; otherwise, set to 0.
    kMediaLibraryAppCmdGetBackgroundState,
    kMediaLibraryAppCmdGetScreenLocked,
    
    // get current network type, returning Unknown if it can't be detected.
    kMediaLibraryAppNetworkType,
    
    /// response to log the media library's log string.
    /// param - AppLogCmdParam
    kMediaLibraryAppCmdLog,    
    
    kMediaLibraryAppAudioSessionInterruption
    
};

enum MediaLibrarySocketType
{
    kMediaLibrarySocketTypeNone = 0,
    kMediaLibrarySocketTypeTCP = 1,
    kMediaLibrarySocketTypeUDP,
};

enum MediaLibraryVideoProtocolVersion
{
    kMediaLibraryVideoProtocolNone = 0,
    kMediaLibraryVideoProtocolV1,
    kMediaLibraryVideoProtocolV2,
};

namespace MediaLibrary
{
    struct PictureData
    {
        MediaLibraryPictureFormat   iFormat;
        
        uint32_t    iWidth;
        uint32_t    iHeight;
        uint32_t    iStrides[4];       // strides for each color plane.
        uint32_t    iPlaneOffset[4];   // byte offsets for each color plane in iPlaneData.
        uint32_t    iPlaneDataSize;    // the total buffer size of iPlaneData.
        
        // NOTICE: iPlaneData buffer must be created by AllocBuffer/AllocBufferFromeCache.
        int32_t		idxPic;

#if (!defined(ANDROID))
        OSType      pixelFormat;
        CFStringRef matrixKey;
#endif
        
        MediaLibraryPictureDataType dataType;
        union {
            void        *iPlaneData;
            void        *iosPixelBuffer;
            void        *androidSurface;
        };

		void reset()
		{
			iFormat = kMediaLibraryPictureFmtUnknown;
			iWidth = 0;
			iHeight = 0;
			memset(iStrides, 0, sizeof(iStrides));
			memset(iPlaneOffset, 0, sizeof(iPlaneOffset));
			iPlaneDataSize = 0;
			idxPic = 0;
			dataType = kMediaLibraryPictureDataNull;
			iPlaneData = NULL;
			iosPixelBuffer = NULL;
			androidSurface = NULL;
#if (!defined(ANDROID))
            pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange; // OSType
            matrixKey = kCVImageBufferYCbCrMatrix_ITU_R_601_4;
#endif
        }
    };

	struct EncodedAVDataParam 
	{
		uint32_t audioAppId;
		uint32_t videoAppId;
		uint32_t roomType; 
		uint32_t channels;
		uint32_t sampleRate;
		int qualityLevel;

		uint32_t videoWidth;
		uint32_t videoHeight;
		uint32_t frameRate;
		uint32_t bitrate;
		uint32_t encodeType;	//definition is ref. enum EncodeType
	};
    
    /// the callback need to be implemented by observers to listen host's message.
    /// msg - the msg id that is defined by host, and must be positive.
    /// param - the type of param is defined by host corresponding to the msg id.
    /// return ture - if the ObserverAnchor's Unpin() is called on anchor in this callback to minus the anchor's pincount by one;
    /// otherwise - return false in most cases.
    /// NOTICE : Unpin can by called only once in the callback.
    typedef bool (*ObserverAnchorCallback)(class ObserverAnchor *anchor, void *sender, int msg, void *param);
    class ObserverAnchor
    {
    public:
        static ObserverAnchor* Create(ObserverAnchorCallback callback);
        
        /// the only way to destory an anchor instance.
        /// anchor - a pointer to an anchor instance or null. It will be set to NULL after the calling.
        /// this function will be blocked to wait for the anchor's pin count to be zero.
        static void SafeDestory(ObserverAnchor *& anchor);

		static bool SendObserverMessage(ObserverAnchor* anchor, void *sender, int msg, void *param);

		static void createObserveAnchorsLock();
        
        /// check if the observer's pin count is positive.
        bool IsObserverHandling() const;
        
        /// check if this anchor instance is still valid.
        bool IsValid() const;
        
        /// set client data of observers.
        /// the context's ownership is not taken by ObserverAnchor.
        void SetContext(void *context) { iContext = context; }
        void* GetContext() const { return iContext; }
        
        /// called by host to send observer messages. the observer's callback get called in calling this function.
        /// return true - if the anchor instance is valid, and its callback get called; false - this anchor instance is not a valid one.
        /// sender - the host instance pointer.
        bool innerSendObserverMessage(void *sender, int msg, void *param);
        
        /// only used in observer's callback function.
        void Unpin();

	public:
		static MediaMutex* iLivingAnchorLock;

	public:
		MediaMutex* iPinMutex;		//用来同步iPinCount，声明为公有便于在外面释放

    private:
        ObserverAnchor(ObserverAnchorCallback callback);
        ~ObserverAnchor();
        
        ObserverAnchorCallback iCallback;
        int     iPinCount;
        void   *iContext;
    };
    
    enum LibError
    {
        kErrNone            = 0,        // success.
        kErrUnknown         = -1000,
        kErrArgument,
        kErrNoImpl,
        kErrNotActived,
        kErrNoAddress,
        kErrNotAvailable,
        kErrNotInit,
        kErrNoLink,
        kErrNotSupported,
        kErrAudioDevice,
        kErrAudioMixer, //-990
        kErrAudioProcessor,
        kErrAudioFmt,
        kErrAudioSession,
        kErrAudioCategory,
        kErrAudioResample,
        kErrAudioProperty,
        kErrAudioDecoder,
        kErrAudioEncoder,
        kErrVideoDevice,
        kErrVideoEncoder, //-980
        kErrNoPermission,
        kErrTimeout,
        kErrClosed,
        kErrSocket,
        kErrDuplicate,
        kErrNoCodec,
        kErrNoDevice,
        kErrNotOpened,
        kErrNotStarted,
        kErrNotFound, //-970
        kErrNoRoom,
        kErrNoData,
        kErrAudioInput,
        kErrAudioOutput,
        kErrSampleRate,
        kErrIndex,
        kErrAlready,
        kErrState,
        kErrNotConnected,
        kErrFatal, //-960
        kErrCookie,
        kErrTimestamp,
        kErrLate,
        kErrMemory,
        kErrFile,
        kErrHint,
        kErrId,
        kErrSubView,
		kErrVideoDecoder,
        kErrInProgress,
        kErrGPUFilter,///EK 2015-9-9 USING_GPU_PROC_FOR_VIDEO_STREAM
    };

    //tempory hold here, move out to namespace in next step
    enum VideoFrameType
    {
        kVideoUnknowFrame = 0xFF,   // 8bits
        kVideoIFrame = 0,
        kVideoPFrame,
        kVideoBFrame,
        kVideoPFrameSEI = 3,        // 0 - 3 is same with YY video packet's frame type.
        kVideoIDRFrame,
        kVideoSPSFrame,
        kVideoPPSFrame,
        kVideoHeaderFrame,
        kVideoEncodedDataFrame,
        kVideoH265HeadFrame = 9,
    };

}
