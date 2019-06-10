#pragma once

#include "modules_base.h"
#include <memory.h>
#include <string.h>
#include <string>
#include <vector>
#include "mediabase_utils.h"
#include "UintHelper.h"

class IRenderView;

enum MediaLibraryCodecMode
{
    kMediaLibraryDecoder = 0,
    kMediaLibraryEncoder = 1,
};

enum MediaLibraryVideoCodec
{
    kMediaLibraryVideoCodecUnknown  = 0,
    kMediaLibraryVideoCodecPicture  = 1,
    kMediaLibraryVideoCodecH264     = 2,
    kMediaLibraryVideoCodecVP8      = 4,
	kMediaLibraryVideoCodecH265     = 5,
};

enum MediaLibraryAudioDeviceCapability
{
    kMediaLibraryAudioDeviceCapNone = 0,
    
    // indicate the existence of playing a small tip file directly using the system audio file player api concurrently.
    // when there is audio output device being started.
    // so the outputs of playing file and output device will be mixed by platform internally.
    kMediaLibraryAudioDeviceCapPlaySmallFile = 1,
    
    // reserved.
    kMediaLibraryAudioDeviceCapHardwareAAC = 2,
};

namespace MediaLibrary
{
	//platform related define
	enum PlatformMessage
	{
		// param - AudioDeviceType: inform the middle that current available audio device changed.
		kPlatMsgAudioDeviceAvailable,
		kPlatAudioSessionInterruption,
	};

	enum AudioDeviceType
	{
		kAudioDeviceTypeNone    = 0,
		kAudioDeviceTypeInput   = 1,
		kAudioDeviceTypeOutput  = 2,
		kAudioDeviceTypeBoth    = 3,
	};

	struct VideoFrameCaptureInfo
	{
		uint32_t m_captureStamp;
		uint32_t m_width;
		uint32_t m_height;
		bool m_bFrontCamera;	// 是否前置摄像头

		VideoFrameCaptureInfo()
		: m_captureStamp(0)
		, m_width(0)
		, m_height(0)
		, m_bFrontCamera(false)
		{

		}

		VideoFrameCaptureInfo(uint32_t capStamp, uint32_t w, uint32_t h, bool bFrontCamera)
		: m_captureStamp(capStamp)
		, m_width(w)
		, m_height(h)
		, m_bFrontCamera(bFrontCamera)
		{

		}

		void reset()
		{
			m_captureStamp = 0;
			m_width = 0;
			m_height = 0;
			m_bFrontCamera = false;
		}
	};

	struct FrameDesc
	{
		VideoFrameType iFrameType;
		unsigned int iPts;
		unsigned int iRealPts;
		uint64_t streamId;
        uint32_t seiSegmPts;

		FrameDesc(VideoFrameType frameType, uint32_t pts, uint32_t realPts, uint64_t streamId, uint32_t seiSegmPts)
		: iFrameType(frameType)
		, iPts(pts)
		, iRealPts(realPts)
		, streamId(streamId)
        , seiSegmPts(seiSegmPts)
		{

		}

		FrameDesc()
		: iFrameType(kVideoUnknowFrame)
		, iPts(0)
		, iRealPts(0)
		, streamId(0)
        , seiSegmPts(0)
		{

		}
	};

	struct VideoEncodedData
	{
		VideoFrameType  iFrameType;
		unsigned int    iPts;
		unsigned int    iDts;
		unsigned int    iDataLen;
		void           *iData;

		VideoEncodedData()
		: iFrameType(kVideoUnknowFrame)
		, iPts(0)
		, iDts(0)
		, iDataLen(0)
		, iData(NULL)
		{

		}
		
		VideoEncodedData(VideoFrameType frameType, uint32_t pts)
		: iFrameType(frameType)
		, iPts(pts)
		, iDts(0)
		, iDataLen(0)
		, iData(NULL)
		{
			
		}

	};

	struct VideoEncodedList
	{
		int  iSize;
		VideoEncodedData *iPicData; //VideoEncodedData points array

		VideoEncodedList()
		: iSize(0)
		, iPicData(NULL)
		{

		}
	};

    
    enum VideoDeviceCapability
    {
        kVideoDeviceCapNone = 0,
        
        // device surport encoder type (h264 ...)
        kVideoDeviceCapEnc = 1,
    };
    
    struct VideoStreamFormat
    {
        MediaLibraryVideoCodec    iCodec;
        int           iProfile;
        MediaLibraryPictureFormat iPicFormat;
        unsigned int  iWidth;
        unsigned int  iHeight;
        unsigned int  iFrameRate;
		unsigned int  iBitRate;
		unsigned int  iEncodePreset;
        int           iRawCodecId;
        unsigned int  iStabilization;
		unsigned int  iEncodeRotation;
    };
    
	enum VideoMessage
	{
		// video input device output recorded data.
		// param - pointer to VideoEncodedList
		// set PicEncData's iData to NULL, if the observer taking the ownership of the picture data.
		kVideoMsgInputRecord = 700,
		kVideoMsgInputCaptureInfo = 701,
		kVideoMsgVideoCaptureAndEncodeInfo = 702,

	};

	struct VideoCaptureAndEncodeInfoParam
	{
		int originalCameraWidth;
		int originalCameraHeight;
		int originalCameraFramerate;

		int expectedEncodeWidth;
		int expectedEncodeHeight;
		int expectedEncodeFramerate;
		int expectedEncodeBitrateInKbps;

		int realEncodeWidth;
		int realEncodeHeight;
		int realEncodeFramerate;
		int realEncodeBitrateInKbps;

		int dynamicBitrateInKbps;

		VideoCaptureAndEncodeInfoParam() {
			memset(this, 0, sizeof(VideoCaptureAndEncodeInfoParam));
		}
	};

	struct VideoDecodeInfoParam
	{
		int width;
		int height;
		int framerate;
		int bitrateInKbps;

		VideoDecodeInfoParam()
		: width(0)
		, height(0)
		, framerate(0)
		, bitrateInKbps(0)
		{
		}
	};
    
    // VideoMessage's parameter
    struct VideoCameraMsgParam
    {
        MediaLibraryPictureFormat iFormat; //kPictureFmtYUV420
		unsigned int  iTimestamp; //0
        void  *iData; //
        unsigned int iLength; //length
        int   nFrameWidth;
        int   nFrameHeight;
        bool  iFrontCamera; //true/false
		int rotateAngle;
		unsigned int nStride;
    };
	
	// Encoded Video Data
    struct EncodedVideoDataParam
    {
        int   isHeaderData;
        unsigned int iDts; //0
        unsigned int iPts; //0
        void  *iData; //
        unsigned int iLength; //length
    };
    
    enum MediaLibraryWaterMarkOrig
    {
        kMediaLibraryOrigLeftTop,
        kMediaLibraryOrigLeftBottom,
        kMediaLibraryOrigRightTop,
        kMediaLibraryOrigRightBottom
    };
    
    ////EK  2015-9-9 USING_GPU_PROC_FOR_VIDEO_STREAM
    enum MediaLibraryFilterType
    {
        MediaLibraryFilter_Shutdown = 0,
        MediaLibraryFilter_Crop = 1<<0,
        MediaLibraryFilter_Beauty = 1<<1,
        MediaLibraryFilter_WaterMarker = 3,
        MediaLibraryFilter_Wenxin = 1<<2,
		MediaLibraryFilter_Noble = 5,
        MediaLibraryFilter_BlackWhite = 1<<3,
        MediaLibraryFilter_Sweet  = 1<<4,
        MediaLibraryFilter_Mint   = 1<<5,
        MediaLibraryfilter_SuperBeauty = 1<<6,
        MediaLibraryfilter_BilatBeauty = 65,
        MediaLibraryFilter_BeautyPlus = 1<<7,
    };
    struct MediaLibraryFilter
    {
        unsigned char* pRGBAData;
        int nImgW;
        int nImgH;
        int nDataLen;
        float fVal;
        float fVal1;
        float fVal2;
        int  wmkW;
        int  wmkH;
        int  wmkRectx;
        int  wmkRecty;
        int  wmkRectW;
        int  wmkRectH;
        MediaLibraryFilterType FilterType;
    };
    
    enum GPUState
    {
        GPUSTATE_PAUSE = 1,
        GPUSTATE_RESUME,
        GPUSTATE_ORIENT,
    };
    
    struct MediaLibraryGPU
    {
        GPUState gst;
        int orient;
    };
    
    ////END USING_GPU_PROC_FOR_VIDEO_STREAM
    struct MediaLibraryWatermark
    {
        unsigned char* pRGBAData;
        int nImgW;
        int nImgH;
        int nDataLen;
        MediaLibraryWaterMarkOrig OrigType;
        int nOffsetX;
        int nOffsetY;
    };
    
    struct VideoCaptureCapability
    {
        int nWidth;
        int nHeight;
        int nFrameRate;
    };
    
    enum VideoOutputRotation
    {
        kVideoOutputRotation0,
        kVideoOutputRotation90,
        kVideoOutputRotation180,
        kVideoOutputRotation270,
    };
    
    enum VideoDeviceParamName
    {
        // Camera data
        kVideoDeviceParamRawData    = 0,
        // change Camera front:0  back:1 other:err
        kVideoDeviceParamDevType    = 1,
        // change touch mode:	TouchModeOff  = 0,  TouchModeOn   = 1, TouchModeAuto = 2, other: err
        kVideoDeviceParamTouchMode  = 2,
        // videoEncoderData
        kVideoDeviceParamEncData    = 3,
        // video encoder device err
        kVideoDeviceParamErr        = 4,
        // video encoder Header: sps pps ....
        kVideoDeviceParamEncHeader  = 5,
        
        // used for VideoOutputDevice
        // param - int : non-zero - pause the output device render process; zero - resume the output device render process.
        kVideoDeviceParamPause      = 6,
        //used for VideoOutputDevice
        // param - int :  < 1000 * 1000/fps
        kVideoRenderInterVal        = 7,
        //Set WaterMark
        kVideoWaterMark             = 8,
        

		kVideoDeviceParamCapability = 9,
		kVideoEncoderParam          = 10,
		kVideoZoomFactor			= 11,
        kVideoFilterParam           = 12,////EK  2015-9-9 USING_GPU_PROC_FOR_VIDEO_STREAM
        kVideoGPUParam              = 13,
		kvideoViewResumeType        = 14,
        // Encoded Video Data
        kVideoDeviceParamEncodedVideoData = 15,
		kVideoDeviceParamCameraPreviewInfo = 16,
		kVideoDeviceParamHardwareEncoderVideoInfo = 17,
        kVideoCaptureCameraSnapshot = 30,
    };
    
    typedef enum
    {
        // Scale the video until both dimensions fit the visible bounds of the view exactly. The aspect ratio of the movie is not preserved
        kVideoScalingModeFill,
        
        // Scale the video uniformly until one dimension fits the visible bounds of the view exactly.
        // In the other dimension, the region between the edge of the movie and the edge of the view is filled with a black bar.
        // The aspect ratio of the movie is preserved.
        kVideoScalingModeAspectFit,
        
        // Scale according to the smaller one between width and height, than clip the part outside the view bounds.
        kVideoScalingModeClipToBounds,
    } VideoScalingMode;    
    
    /// video device
    class VideoDecoder
    {
    public:
        
        /// codecData - currently, PPS and SPS data is set when creating H264 decoder.
        static int  Create(MediaLibraryVideoCodec codec, void *codecData, uint32_t dataLength, VideoDecoder*& ppDecoder, bool bHardWare, bool bOmxDecodeEnabled);
        static void Release(VideoDecoder *decoder);
        
        static bool IsCodecSupported(MediaLibraryVideoCodec codec);
        
        /// decode a frame, and outData points the decoded picture if there is.
        /// but the decoded picture is not the corresponding output of input data,
        /// because the decoded order is not same with playing order.
        /// caller will take the owner of outData, and release it via FreeBuffer.
        /// outPics need to be released by FreeBuffer
        virtual int Decode(void *data, unsigned int dataLength, const FrameDesc* desc, PictureData*& outPics, int& numPics) = 0;

		virtual bool IsHardware() { return false; }
		virtual uint32_t GetDecodeDelay() { return 0; }
		virtual uint32_t getDecodeType() { return 0; }
		virtual int GetWidth() { return 0; }
		virtual int GetHeight() { return 0; }
        
    protected:
        VideoDecoder();
        virtual ~VideoDecoder();
    };
    
    class VideoEncoder
    {
    public:
        
        /// codecData - currently, cache files directory.
        static int  Create(MediaLibraryVideoCodec codec, void *codecData, unsigned int dataLength, VideoEncoder*& ppEncoder, bool userHardware = true);
        static void Release(VideoEncoder *encoder);
        
        static bool IsCodecSupported(MediaLibraryVideoCodec codec);
        
        /// Encoder a frame, and outData points the Encoder data if there is.
        /// caller will take the owner of outData, and release it via FreeBuffer.
        virtual int Encode(void *data, unsigned int dataLength, const FrameDesc& desc, VideoEncodedList &outData) = 0;
        virtual void setTargetBitrate(int bitrateInKbps) = 0;
		virtual int getTargetBitrate() = 0;

		virtual uint32_t actuallyBitrate() const = 0;
		virtual uint32_t actuallyFps() const = 0;
        
        virtual std::string getStatusText() const = 0;
        
    protected:
        VideoEncoder();
        virtual ~VideoEncoder();
    };

    class VideoInputDevice
    {
    public:
        static VideoDeviceCapability GetCapabilities();
        static bool GetSupportedFormat(VideoStreamFormat &preferredFormat, bool nochanged = true);
//        static int  Create(VideoStreamFormat format, ObserverAnchor *msgObserver, VideoInputDevice*& ppDevice, int useHardWareEncode = 1, int camType = 1, CaptureVideoOrientation capOrientation = CaptureVideoOrientationPortrait);
        static int  Release(VideoInputDevice *inputDevice);
        
        virtual int StartPreview(IRenderView *renderView) = 0;
        virtual int StopPreview() = 0;
        virtual bool IsPreviewStarted() const = 0;

        virtual int StartEncoder(ObserverAnchor *dataObserver) = 0;
        virtual int StopEncoder()  = 0;
        virtual bool IsEncoderStarted() const = 0;
        
        virtual int GetParameter(unsigned int name, void *value) const = 0;
        virtual int SetParameter(unsigned int name, void *value) = 0;
        
        virtual uint32_t actuallyBitrate() const = 0;
        virtual uint32_t actuallyFps() const = 0;
        
    protected:
        VideoInputDevice();
        virtual ~VideoInputDevice();
        
    };


	class SimpleFramerateAndBitrateCounter {
	public:
		bool ComeOneFrame(uint32_t frameSize) {
			++mFrames;
			mBytes += frameSize;
			uint32_t t2 = MediaLibrary::GetTickCount();
			if (isBiggerUint32(t2, t1) && t2 - t1 > mIntervalInMilliSecs)
			{
				mFramerate = 1000.0 * mFrames / (t2 - t1);
				mBitrateInKbps = 8.0 * mBytes / (t2 - t1);
				t1 = t2;
				mFrames = 0;
				mBytes = 0;
				return true;
			}
			return false;
		}

		void ComeOneFrameSkipRateCalculate(uint32_t frameSize) {
			++mFrames;
			mBytes += frameSize;
		}

		void CalculateRate() {
			uint32_t t2 = MediaLibrary::GetTickCount();
			if (isBiggerUint32(t2, t1))
			{
				mFramerate = 1000.0 * mFrames / (t2 - t1);
				mBitrateInKbps = 8.0 * mBytes / (t2 - t1);
				t1 = t2;
				mFrames = 0;
				mBytes = 0;
			}
		}

		void InitCounting(int intervalInMilliSecs) {
			mFramerate = 0;
			mBitrateInKbps = 0;
			mFrames = 0;
			mBytes = 0;
			mIntervalInMilliSecs = intervalInMilliSecs;
			t1 = MediaLibrary::GetTickCount();
		}

		int CurrentFramerate() {
			return mFramerate + 0.5;
		}

		int CurrentBitrateInKbps() {
			return mBitrateInKbps + 0.5;
		}

	private:
		float mFramerate;
		float mBitrateInKbps;
		uint32_t mFrames;
		uint32_t mBytes;
		uint32_t t1;
		uint32_t mIntervalInMilliSecs;
	};
    
    
    // the max size for video output device is 2048 * 2048
#define MaxWidthOfVideoOutputDevice    (2048)
#define MaxHeightOfVideoOutputDevice   (2048)
    class VideoOutputDevice
    {
    public:
        
        // check if a picture format is supported by video output device.
        static bool IsSupportedPicFormat(MediaLibraryPictureFormat format);
        
        // check if the output device support sub view on output device.
        // a sub view is a sub region in the output device to render a seperated frame data. It will be clipped into the output device's size.
        // when VideoOutputDevice instance is release, all its sub view will be destoried also.
        // if returning false, all subview functions doesn't work.
        // a sub view id is positive integer.
        // set subviewid to zero for controlling the output device's render view.
        static bool IsSubViewSupported();
        
        // platdata is a os-dependency data struct for providing the UI info to create a output device.
        // for IOS: it is NULL.
        // for Android: it is the native window on which the output device will render frames.
        static int Create(int width, int height, VideoScalingMode scalingmode, VideoOutputRotation rotation, void *platdata, VideoOutputDevice *& pdevice);
        static void Release(VideoOutputDevice *pdevice);
        
        virtual int SetSubViewProperty(int streamId, int showModel, int rotationModel, int nRenX, int nRenY, int nRenW, int nRenH) = 0;
        // zorder - higher value will make the subview displayed on top of other sub views. (0 - 100)
        // all sub views display on top of the view of VideoOutputDevice.
        // return > 0 - sub view id; < 0 - err code.
        virtual int CreateSubView(int x, int y, int width, int height, int zorder) = 0;
        virtual int ReleaseSubView(int subviewid) = 0;
        
        // when subviewid is zero, x and y are always zero.
        virtual void GetBound(int subviewid, int &x, int &y, int &width, int &height) = 0;
        
        // only work for subView, the videoOutputDevice's size can't be changed.
        virtual int SetBound(int subviewid, int x, int y, int width, int height) = 0;
        
        virtual VideoScalingMode GetScalingMode(int subviewid) = 0;
        virtual int SetScalingMode(int subviewid, VideoScalingMode mode) = 0;
        
        virtual VideoOutputRotation GetRotation(int subviewid) = 0;
        virtual int SetRotation(int subviewid, VideoOutputRotation rotation) = 0;
        
        // platform-dependent handle.
        // Don't access this handle after releasing the video output device.
        // for IOS: it returns a pointer to UIView that is rendering the frames.
        // before releasing the video output device, the UIView must be removed from UI view trees.
        virtual void* GetHandle() const = 0;
        
        // ask output device to render a picture.
        // NOTICE: when returning kErrNone - the PictureData's iPlaneData ownership was taken by VideoOutputDevice.
        // the caller can't release it.
        virtual int Render(int subviewid, const PictureData &data) = 0;
        
        virtual int GetParameter(unsigned int  name, void *value) const = 0;
        virtual int SetParameter(unsigned int  name, void *value) = 0;
        
    protected:
        VideoOutputDevice();
        virtual ~VideoOutputDevice();
    };
    
    //audio
    
    
    enum AudioDeviceHint
    {
        kAudioDeviceHintNone = 0,
        kAudioDeviceHintVoice = 1,
        kAudioDeviceHintMusic = 2,
        kAudioDeviceHintKrok = 4,
        kAudioDeviceHintVAD = 8,
    };
    
    // for now, we just support 8/16/32 bits sample data.
    
    enum AudioMessage
    {
        // handle audio output device's 'to be played' data.
        // valid param: iData/iLength/iFormat/iTimestamp.
        kAudioMsgOutputPlay,
        
        // audio output device ask for data to play.
        // valid param: iData/iLength/iFormat/iTimestamp.
        // reset the filled length to iLength.
        kAudioMsgOutputFeed,
        
        // audio input device output recorded data.
        // valid param: iData/iLength/iFormat/iTimestamp.
        kAudioMsgInputRecord,
        
        // audio mixer ask for data input streams to mix.
        // valid param: iData/iLength/iFormat.
        // reset the filled length to iLength.
        kAudioMsgMixerFeed,

         // audio capture error while start input recorder
        // valid param: iData/iLength/iFormat.
        // reset the filled length to iLength.
        kAudioMsgCaptureError,

        // audio render error while recording
        // valid param: iData/iLength/iFormat.
        // reset the filled length to iLength.
        kAudioMsgRenderError,

		//Receive a Phone Call
        kAudioMsgReceivePhoneCall,
        
        //Headset Plugin
        kAudioMsgHeadsetPlugin,
    };
    
    // AudioMessage's parameter
    struct AudioMsgParam
    {
//        AudioStreamFormat iFormat;
        uint32_t iTimestamp; // float => uint32_t
        float iDuration;
        void *iData;
        unsigned int iLength;
		int iIndex;
        int iBufdelay;
        int iAudioDetectActive;
		uint32_t bufferSize;
		uint32_t error_type;
		bool isIncall;
        bool isHeadsetIn;
		uint32_t volume;

		AudioMsgParam()
		: iTimestamp(0)
		, iDuration(0.0)
		, iData(NULL)
		, iLength(0)
		, iIndex(0)
		, iBufdelay(0)
		, iAudioDetectActive(0)
		, bufferSize(0)
		, error_type(0)
		, isIncall(false)
        , isHeadsetIn(false)
		, volume(0)
		{
		}
    };
    
    /*
     * audio device data mode: pull mode.
     * an audio device state is : opened -> started -> opened -> closed.
     * at any time, only one input/output device can be opened/started.
     * the input device should provide good guality voice data as much as possible all the time (like: noise suppression, AEC) internally,
     * before delivering data to caller.
     * Thread-Safe
     */
    enum AudioDeviceParamName
    {
        // get/set output/input volume
        // param - float (0.0 ~ 1.0)
        kAudioDeviceParamVolume = 1,
        
        // get output/input format
        // param - AudioStreamFormat
        kAudioDeviceParamFormat = 2,
        
        // get hardware device delay in ms.
        // param - unsigned int
        kAudioDeviceParamDelay = 3,
    };
    
    enum AudioOutputRoute
    {
        kAudioOutputRouteUnknown = 0,
        kAudioOutputRouteDefault,
        kAudioOutputRouteSpeaker,
        kAudioOutputRouteReciever,
        kAudioOutputRouteHeadphone,
    };
    class AudioDevice
    {
    public:
        
        static MediaLibraryAudioDeviceCapability GetCapabilities();
        
        /// on android devices, we need to check the supported converted format for the format what we prefer.
        /// then use the returned supported format to open input/output device, shouldn't never fails.
        // if nochanged is true, the function will not change the preferredFormat the closest supported format.
//        static bool GetSupportedInputFormat(AudioStreamFormat &preferredFormat, bool nochanged = true);
//        static bool GetSupportedOutputFormat(AudioStreamFormat &preferredFormat, bool nochanged = true);
        
        /// open input device if there is not any input device opened.
        /// an audio processor can be chained to input device's output before delivering input samples to caller.
        /// and the processor's filter can be set dynamically.
//        static int OpenInputDevice(AudioStreamFormat format,
//                                   ObserverAnchor *observer,
//                                   AudioDeviceHint hint,
//                                   AudioDevice*& ppDevice);
        
        /// a mixer can be chained to output device, so that the output device can autoly pull data for multi streams.
//        static int OpenOutputDevice(AudioStreamFormat format,
//                                    ObserverAnchor *observer,
//                                    AudioDeviceHint hint,
//                                    AudioDevice*& ppDevice);
        
        /// the device can't be closed if it is being started.
        /// the device will not be destoried if returning error.
        static int CloseDevice(AudioDevice *device);
        
        /// for most cases, we can start/stop input/output devices together,
        /// because it is easier for platform to start both devices together.
        /// and also, we can start one device on the fly, it means the platform need to enable AEC on the fly, too.
        /// after starting devices, its callback timestamp start from zero.
        static int StartDevices(AudioDevice *inputDevice, AudioDevice *outputDevice);
        static int StopDevices(AudioDevice *inputDevice, AudioDevice *outputDevice);

		static int CreateAudioEngine();
		static int DestroyAudioEngine();

//        static int StartAudioEngine(AudioEngineFeature_t AudioEngineFeature, VoiceDetectionMode mode = voiceDetectionUnknown);
//        static int SetMode(AudioEngineFeature_t audioEngineFeature);
		static int StopAudioEngine();
        static bool IsAudioEngineStarted();
//        static int SetVADMode(VoiceDetectionMode mode);

		static bool IsInputDeviceOpened();
        static bool IsOutputDeviceOpened();
        
		static AudioDevice* GetInputDevice();
		
        /// check if the audio device currently is avalible for opening.
        static bool IsAudioDeviceAvailable(AudioDeviceType type);
        
        /// set current audio output route.
        /// only valid input for ChangingOutputRoute is kAudioOutputRouteDefault/kAudioOutputRouteReciever.
        static int ChangeOutputRoute(AudioOutputRoute route);
        static AudioOutputRoute GetCurrentOutputRoute();
        
        /// a helper api to play a small audio file, like a system sound.
        /// if kAudioDeviceCapPlaySmallFile is set in audio device capability.
        static int PlaySmallAudioFile(const char *filename);
        
        static bool SetVirtualSpeakerVolume(uint32_t volume);
		static bool SetVirtualMicVolume(uint32_t volume);
//        static IAudioFilePlayer* CreateAudioFilePlayer();
        static bool GetHeadSetMode();

		static void SetReverbMode(uint32_t mode);
        static void EnableDenoise(uint32_t enable);
        static bool IsDenoiseEnabled();
        static void SetVoiceChangeSemitone(float val);
        static void EnableReverb(bool enable);
        static void EnableVoiceChanger(bool enable);
		static void SetReverbExMode(uint32_t mode);
        //static void SetVADEnable(bool enable);
        static void SetReverbExParameter( double roomSize,
                                          double preDelay,
                                          double reverberance,
                                          double hfDamping,
                                          double toneLow,
                                          double toneHigh,
                                          double wetGain,
                                          double dryGain,
                                          double stereoWidth);
        static void SetReverbParameter(double roomsize,
                                       double revtime,
                                       double damping,
                                       double inputbandwidth,
                                       double drylevel,
                                       double earlylevel,
                                       double taillevel);
        static void SetVoiceChangeSemitoneEx(int val);
        static void EnableReverbEx(bool enable);
        static void SetEqGain(int nBandIndex, float fBandGain);
        static void SetCompressorParam(uint32_t mode);
        static void EnableVoiceChangerEx(bool enable);
        static void SetVeoMode(int mode);
        static bool SetBuildInMicLocation(int location);
		static void EnableAutoGainControl(bool enable);
        static void EnableMicrophone(bool enable);
		static bool StartAudioSaver(const char* fileName, uint32_t mode);
		static bool StopAudioSaver();
		static bool CheckPhoneCallState();
		static void EnableBeatTrackCallBack(bool enable);
        static void SetBeatTrackDelay(int val);
        static bool SetPlayBackModeOn(bool enable);
        
        static void StartAudioPreview();
        static void StopAudioPreview();
        static void EnableStereoPlayWhenHeadsetIn(bool enable);
        static void EnableDumpAudioEngineFile(bool enable);
    
//        virtual IAudioRender* CreateAudioRender() {return NULL;}
//        virtual IAudioCapture* CreateAudioCapture() {return NULL;}

        virtual int GetParameter(unsigned int name, void *value) const = 0;
        virtual int SetParameter(unsigned int name, void *value) = 0;
        
        bool IsStarted() const { return iStarted; }
        AudioDeviceType GetType() const { return iType; }
        void SetStarted(bool started) { iStarted = started; }
	
		static void PushOuterAudioData(const char* dataBlock, int dataSize, int mixType, int sampleRate, int channel);
        static void EnableCaptureVolumeDisplay(bool enable);
        static void EnableRenderVolumeDisplay(bool enable);
        
        static bool GetAudioCaptureAndEncodeHiidoStatInfo(char*& pCaptureAndEncodeInfo, int& stringLen);
        static bool GetAudioRenderHiidoStatInfo(char*& pRenderInfo, int& stringLen);
        static bool GetAudioStreamDecodeHiidoStatInfo(uint32_t uid, char*& pDecoderInfo, int& stringLen);
    protected:
        AudioDevice(AudioDeviceType type);
        virtual ~AudioDevice();
        
        AudioDeviceType iType;
        bool iStarted;
    };
    
    /*
     * Mixer rules:
     * Mixer use same format for output and all input streams, just mixing the every enabled input stream with its volume settings.
     * After creating a mixer, use PullData to get mixed data, that calls observer's callback to get data for each enabled input stream.
     * Using Reset() to clear all bufferred data in mixer.
     * Volume is range (0.0 ~ 1.0)
     * Thread-Unsafe
     */
#define MaxNumOfMixerInputStreams   (8)
    
    struct AudioMixerInputConfig
    {
        int iIndex;
        bool iEnabled;
        float iVolume;
    };
    
    enum AudioMixerParameterName
    {
        // return the mixer's audio format.
        // param - AudioStreamFormat
        kAudioMixerParamFormat = 1,
        
        // set/get input stream config
        // param - AudioMixerInputConfig
        // to get config, set iIndex as input
        kAudioMixerParamInputConfig = 3,
        
        // get enabled input stream number.
        // param - unsigned int
        kAudioMixerParamEnabledCnt = 4,
    };
    
    class AudioSamplesMixer
    {
    public:
//        static AudioSamplesMixer* CreateAudioMixer(const AudioStreamFormat& fmt, int numStreams);
        
        struct AudioDataInfo
        {
            int iBufferSize;
            int iLeftLength;
            void *iLeftData;
            bool iEnabled;
        };
        
        virtual ~AudioSamplesMixer() {}
        virtual bool MixData(void* output, int packetnum, int packetlen, double sampletime, AudioDataInfo* samples, int numStream) = 0;
        virtual void Reset() =0;
        virtual int EnableStream(unsigned int idx, enabletype enable, float volume) = 0;
    };
    
    enum StreamType
    {
        kStreamTypeUnknown = 0,
        kStreamTypeAudio,
        kStreamTypeVideo,
    };
    
    struct StreamFormat
    {
        StreamType iType;
        union
        {
//            AudioStreamFormat iAudioFormat;
            VideoStreamFormat iVideoFormat;
        };
    };

	struct CodecData
	{
		uint64_t userGroupId;
		uint64_t streamId;
		uint32_t micPos; //  0（首麦）, 1（被连麦）, -1 未知

		CodecData()
		: userGroupId(0)
		, streamId(0)
		, micPos((uint32_t)-1)
		{

		}
	};
    
    typedef struct
    {
        void *clientData;
        unsigned int interruptionState;
    } PlatAudioSessionInterruptionParam;
    
    /// PlatformInitialize is the first function to make the platform layer to work
    /// otherwise, any call to platform layer will fail.
    typedef void (*PlatformObserver)(PlatformMessage msg, void *param);
    void PlatformInitialize(MediaLibraryApplicationCallback callback, PlatformObserver observer, void *reserved);
    void PlatformUninitalize();
    void PlatformHandleApplicationEvent(MediaLibraryApplicationEvent e, void *param);
    
    /// platform info
    enum PlatformOS
    {
        kPlatformIOS,
        kPlatformAndroid,
        kPlatformWindows,
    };
    
    struct PlatformInfo
    {
        PlatformOS  iPlatformOS;
        float       iVersion;
        float       iSubVersion;
		float       iBuilder;
        
        /*	for example:
         manufacturer=samsung, model=GT-I9300,//Galaxy S
         manufacturer=Xiaomi,  model=MI-ONE Plus,
         manufacturer=samsung, model=Nexus S,
         manufacturer=samsung, model=Nexus 10
         */
		char manufacturer[30];
		char model[30];
		char deviceID[32];//serial number
        char systemVersion[30];

		PlatformInfo()
		: iPlatformOS(kPlatformAndroid)
		, iVersion(0)
		, iSubVersion(0)
		, iBuilder(0)
		{
			memset(manufacturer, 0, sizeof(manufacturer));
			memset(model, 0, sizeof(model));
			memset(deviceID, 0, sizeof(deviceID));
            memset(systemVersion, 0, sizeof(systemVersion));
		}
    };
    
    const PlatformInfo& GetPlatformInfo();
}

const MediaLibrary::StreamFormat *GetStreamFormatByNetCodec(int netcodec);

void GetSupportAudioCodecTypes(std::vector<unsigned>& codecTypes);

const char* convertWifiLevel(uint32_t rssi);
