#pragma once
#include "medialibrary.h"
#include "ITransMod.h"
#include <string>

class IRenderView;
class MediaInvoker;
class MediaCallBacker;
class MediaUploadManager;
class SessionAudioOutput;
class MediaStatisticReporter;
class IYYSdkProxy;

namespace MediaLibrary
{
struct EncodedAVDataParam;
class MediaJobAVRecorder;
}

namespace MediaLibrary
{
class MediaJobSession
	: public MediaJobBase
{
public:

	virtual void Init(AccountInitData& initData) = 0;
	virtual void AppRejectAudio(bool toReject) = 0;
	virtual void InterruptRejectAudio(bool toReject) = 0;
	virtual void RejectAudioByUid(uint32_t uid, bool toReject) = 0;
	virtual void SwitchSubSid(uint32_t subsid) = 0;
	virtual void requireRender(uint64_t groupId, uint64_t streamId, AVframe &frame) = 0;
	virtual void notifyStreamUnSubscribe(uint64_t groupId, uint64_t streamId) = 0;
	virtual void enableAudioInputStream(enabletype enable, uint32_t uid) = 0;
	virtual void StopEncodedAudioDataUpload() = 0;  
	virtual void StopEncodedVideoDataUpload() = 0;
	virtual void notifyVideoEncodeParams(uint32_t bitRate, uint32_t frameRate, uint32_t width, uint32_t height, bool bResolutionChanged) = 0;
	virtual void notifyAudioEncodeParams(uint32_t quality) = 0;
	virtual void onTimeout(uint32_t checkTimes) = 0;
	virtual void initTransMod(uint32_t signalPort) = 0;
	virtual int  SetKnownUidVolume(uint32_t uid, uint32_t val) = 0;
	virtual void reqAudioDiagnose(uint32_t uDiagnose) = 0;
	virtual void notifyAudioPlayMode() = 0;
	virtual void notifyAudioLinkMicStatus(bool isLinkMic) = 0;
	virtual bool SetAudioSceneMode(MediaLibrary::AudioSeceneMode audioSceneMode) = 0;
	virtual bool GetAudioCaptureAndEncodeHiidoStatInfo(char*& pCaptureAndEncodeInfo, int& stringLen) = 0;
    virtual bool GetAudioRenderHiidoStatInfo(char*& pRenderInfo, int& stringLen) = 0;
    virtual bool GetAudioStreamDecodeHiidoStatInfo(uint32_t uid, char*& pDecoderInfo, int& stringLen) = 0;
public:
	virtual bool IsAudioRejected() = 0;
	virtual bool IsAudioUploadStarted(void) = 0;
	virtual bool IsAudioDeviceStarted(void) = 0;
	virtual bool IsOpenAudioFailed(void) = 0;

public:
	virtual int UploadEncodedAVData(MediaJobAVRecorder *recorder, const EncodedAVDataParam& avParam) = 0;
	virtual int ActiveSession() = 0;
	virtual int DeActiveSession() = 0;
	virtual uint32_t onAudioDeviceStarting() = 0;
    virtual void ResetAudioEngineIfNeed() = 0;
	virtual void SetAudioEngineMode(int mode) = 0;
    virtual void ResetAudioEngineMode() = 0;
	virtual bool CheckIfNeedResetAudioUpload(bool isLinkMic, int& audioMode, int& quality) = 0;

public:
	virtual MediaInvoker* getMediaInvoker() = 0;
	virtual MediaCallBacker* getMediaCallBacker() = 0;
	virtual MediaUploadManager* getMediaUploadManager() = 0;
	virtual SessionAudioOutput* getAudioOutput() = 0;
    virtual MediaStatisticReporter* getMediaStatisticReporter() = 0;
	virtual IYYSdkProxy* getYYSdkProxy() = 0;

protected:
	MediaJobSession(ObserverAnchor *observer)
	: MediaJobBase(kMediaLibraryJobType_Session, observer)
	{
	}

	virtual ~MediaJobSession() {}
};


class MediaJobAudioPlayer : public MediaJobBase
{
public:
    virtual const MediaLibraryAudioPlayerInfo GetState() const = 0;
    
    // when playing MP4 file, total duration will return zero if the file content is not completed for parsing.
    virtual uint32_t GetTotalDuration() const = 0;
    
    // start play from the start time to the end time (start time + duration)
    // if duration is zero, playing will continue to the end of file.
    // if no data avail at startms, play will not start.
    // playing will be paused autoly if no more data for reading, or stopped by file error.
    // if play is paused autoly, it must be resumed by caller after feeding more data.
    virtual int Play(uint32_t startms, uint32_t duration) = 0;
    virtual int Stop() = 0;
    
    // try to seek the current time between the begintime and endtime based on *targetms.
    // return the new playing time in *targetms.
    // seek will not work if targetms is out of range of current available.
    virtual int Seek(uint32_t *targetms) = 0;
    
    // pause/resume the current playing.
    virtual int Pause() = 0;
    virtual int Resume() = 0;
    
    // the available file length must be set incrementally
    virtual void SetAvailableFileLength(uint32_t length) = 0;
    
    // only work for MP4 file to read user data that was saved in mp4 user data container.
    // pass data as NULL to get the data size into length.
    // kind : the user data kind, can be ignored.
    static const uint32_t UDataName_Lyr = 0xA96C7972;
    static const uint32_t UDataName_Crd = 0xA9637264;
    virtual int ReadUserData(uint32_t name, void *data, uint32_t &length, uint32_t *kind) const = 0;
    
protected:
    MediaJobAudioPlayer(ObserverAnchor *observer);
    virtual ~MediaJobAudioPlayer();
};

class MediaJobAudioRecorder : public MediaJobBase
{
public:

    // toActive is true - start recording, the last recording info will be erased.
    // toActive is false - stop recording.
    virtual int ActiveRecorder() = 0;
    virtual int DeActiveRecorder() = 0;
    
    virtual const MediaLibraryAudioRecorderState GetRecordingState() const = 0;
    
    // return the YY netcodec mapping the encoder type used for encoding the mic data.
    // this function can be called anytime after initing a job instance.
    // return negative if no netcodec mapping the encoder type.
    virtual int GetNetCodec() const = 0;
    
    // get the size of a encoded audio frame corresponding to the NetCodec.
    virtual uint32_t GetFrameSize() const = 0;
    
protected:
    MediaJobAudioRecorder(ObserverAnchor *observer);
    virtual ~MediaJobAudioRecorder();
};

// MediaJobAVRecorder is used to record audio and video on device,
// when recording video, call OpenPreview to get the UI view to display the living video frames on local.
// case 1: record mic audio and upload in session:
// Create an instance of MediaJobAVRecorder, then ConnectJobSession with an instance of MediaJobSession, and call StartRecorder to start recording.
// case 2: upload a started MediaJobAVRecorder's stream in session:
// Create an instance of MediaJobAVRecorder, call StartRecorder to start recording, then ConnectJobSession to link with a session job to upload AV streams.
class MediaJobAVRecorder : public MediaJobBase
{
public:

    // video - true : start/stop video recording; false - start/stop audio recording.
    virtual int StartRecording(streamtype type, MediaLibraryAVRecorderMediaQualityLevel qualityLevel, void *hwdata) = 0;
    virtual int StopRecording(streamtype type) = 0;
    virtual bool IsRecordingStarted(streamtype type) const = 0;

    // the preview handle is only valid during recording progress.
    // it will be closed internally when calling StopRecording/ClosePreview,
    // the caller may not access the handle anymore after that.
    virtual int OpenPreview(IRenderView *renderView) = 0;
    virtual int ClosePreview() = 0;

	virtual int SetVideoParam(int paramName, void *param) = 0;
	virtual int GetVideoParam(int paramName, void *param) = 0;

	virtual uint32_t actuallyBitrate() const = 0;
	virtual uint32_t actuallyFps() const = 0;

protected:
    MediaJobAVRecorder(ObserverAnchor *observer);
    virtual ~MediaJobAVRecorder();
};
}

