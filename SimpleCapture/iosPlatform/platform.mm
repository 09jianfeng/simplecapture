#import <UIKit/UIDevice.h>
#import <CoreVideo/CoreVideo.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <stdlib.h>
#include <mach/mach_time.h>
#include <libkern/OSAtomic.h>
#include <pthread.h>
#include <time.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <malloc/malloc.h>

#include "modules_comm.h"
#include "platform.h"
#include "taskqueue.h"

static bool                            gInitialized = false;
static MediaLibraryApplicationCallback gApplicationCallback = NULL;
static PlatformObserver                gPlatformObserver = NULL;
static pthread_t                       gMainThread = NULL;
static PlatformInfo                    gPlatformInfo;

//const char* sdkVersion = "3.1.2";

namespace MediaLibrary {
    bool isSupportArmNeon()
    {
        return true;
    }
}

void InitializePlatformInfo()
{
	gPlatformInfo.iPlatformOS = kPlatformIOS;

    char cVersion[32] = {0};
    NSString *version = [[UIDevice currentDevice] systemVersion];
    strcpy(cVersion, [version UTF8String]);
    
    gPlatformInfo.manufacturer[0] = 0;
    gPlatformInfo.model[0] = 0;
    
    char *dotptr = strchr(cVersion, '.');
    if (dotptr)
    {
        *dotptr++ = 0;
        gPlatformInfo.iVersion = atof(cVersion);
        gPlatformInfo.iSubVersion = atof(dotptr);
        
		gPlatformInfo.manufacturer[0] = 'a';
        gPlatformInfo.manufacturer[1] = 'p';
        gPlatformInfo.manufacturer[2] = 'p';
        gPlatformInfo.manufacturer[3] = 'l';
        gPlatformInfo.manufacturer[4] = 'e';
        gPlatformInfo.manufacturer[5] = '\0';
        size_t size;
		sysctlbyname("hw.machine", NULL, &size, NULL, 0);
		sysctlbyname("hw.machine", gPlatformInfo.model, &size, NULL, 0);
    }
}

#ifndef USEC_PER_SEC
    #define USEC_PER_SEC  1000000
#endif

const PlatformInfo& MediaLibrary::GetPlatformInfo()
{
    return gPlatformInfo;
}

void MediaLibrary::PlatformInitialize(MediaLibraryApplicationCallback callback, PlatformObserver observer, void *reserved)
{
    gMainThread = pthread_self();
    if (!gInitialized)
    {
        gApplicationCallback = callback;
        gPlatformObserver = observer;
        gInitialized = true;

//        LOGT("MediaLibrary version %u", kMediaSdkVersion);
        
        InitializePlatformInfo();
        
        InitializeTaskQueue();
//        InitializeAudioDevice();
        
//        InitVideoCodecFactory();
    }
    
    LOGT( "MediaPlatInitialize os version [%f, %f]", gPlatformInfo.iVersion, gPlatformInfo.iSubVersion);
}

void MediaLibrary::PlatformUninitalize()
{
	LOGT( "MediaPlatUninitialize");
    if (gInitialized)
    {
//        UninitializeAudioDevice();
        UninitializeTaskQueue();
        
//        DeInitVideoCodecFactory();
        
        gInitialized = false;
        gApplicationCallback = NULL;
        gPlatformObserver = NULL;
    }
}

void MediaLibrary::PlatformHandleApplicationEvent(MediaLibraryApplicationEvent e, void *param)
{
//    AudioDeviceHandleApplicationEvent(e, param);
}

void MediaLibrary::ReleasePictureData(PictureData *data)
{
    if(data->iPlaneData)
    {
        if(data->dataType == kMediaLibraryPictureDataPlaneData)
        {
            MediaLibrary::FreeBuffer(data->iPlaneData);
        }
        else if(data->dataType == kMediaLibraryPictureDataIosPixelBuffer)
        {
            CVPixelBufferRelease((CVPixelBufferRef)data->iosPixelBuffer);
        }
        data->iPlaneData = NULL;
        data->iPlaneDataSize = 0;
    }
}

bool IsInMainThread()
{
    PlatAssert(gInitialized, "state");
    return pthread_self() == gMainThread;
}

#pragma mark - Log
void LogText(LogLevel level, LogModule module, const char *text)
{
    if(text == nil)
    {
        return ;
    }
    
    if (gApplicationCallback)
    {
        MediaLibraryAppLogCmdParam param = { level, module, text };
        gApplicationCallback(kMediaLibraryAppCmdLog, &param);
    }
    else
    {
        NSString *logText = [NSString stringWithUTF8String:text];
        NSString *log = [NSString stringWithFormat:@"%@", logText];
        log = [log stringByReplacingOccurrencesOfString:@"" withString:@""];
        switch (level)
        {
        case kLogInfo:
            NSLog(@"INFO %@", log);
            break;
        case kLogWarning:
        case kLogError:
            NSLog(@"ERRO %@", log);
            break;
        case kLogAssert:
            NSLog(@"ASRT %@", log);
            break;
        case kLogDebug:
            NSLog(@"DBUG %@", log);
            break;
        case kLogTrace:
        default:
            break;
        }
    }
}

void ReportPlatformMessage(PlatformMessage msg, void *param)
{
    if (gPlatformObserver)
        gPlatformObserver(msg, param);
}

bool IsApplicationInBackground()
{
    int inbackgrond = 0;
    gApplicationCallback(kMediaLibraryAppCmdGetBackgroundState, &inbackgrond);
    return inbackgrond != 0;
}

bool IsPlatformInitalized()
{
    return gInitialized;
}

#pragma mark - Time
void MediaLibrary::ThreadSleep(uint32_t ms)
{
    if (ms == 0)
        sched_yield();
    else
    {
        //usleep(ms * 1000);
        struct timespec slptm;
        slptm.tv_sec = 0;
        slptm.tv_nsec = (long)ms * 1000 * 1000;      //1000 ns = 1 us
        nanosleep(&slptm, NULL);
    }
}

void MediaLibrary::selectSleep(uint32_t ms)
{
    struct timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = ms*1000;
    ::select(0,NULL,NULL,NULL,&tv);
}

uint32_t MediaLibrary::GetTickCount()
{
	struct timeval now;
	gettimeofday(&now, NULL);
	return (uint32_t) (((uint64_t)now.tv_sec * USEC_PER_SEC + now.tv_usec) / 1000);
}

uint32_t MediaLibrary::GetUTCSeconds()
{
    return (uint32_t)GetUTCMilliseconds() / 1000;
}

uint64_t MediaLibrary::GetUTCMilliseconds()
{
    return GetUTCMicroseconds() / 1000;
}

uint64_t MediaLibrary::GetUTCMicroseconds()
{
    return 0;
}

uint32_t MediaLibrary::GetUnixTime()
{
	time_t tm = time(NULL);
	return (static_cast<uint32_t>(tm));
}

void MediaLibrary::SetThreadName(char* name)
{
	pthread_setname_np(name);
}

void MediaLibrary::GetThreadName(char* name, int bufsize)
{
    pthread_getname_np(pthread_self(), name, bufsize);
}

#pragma mark - AudioUnit
//void ConvertAudioFormatToStreamBasicDesc(const AudioStreamFormat &fmt, AudioStreamBasicDescription &desc)
//{
//    PlatAssert(fmt.iCodec == kAudioCodecPCM, "pcm");
//
//    desc.mFormatFlags = kAudioFormatFlagIsPacked;
//    if (IsFlagSet(fmt.iFlag, kAudioFmtFlagNotInterleaved))
//        desc.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
//
//    if (IsFlagSet(fmt.iFlag, kAudioFmtFlagFloat))
//        desc.mFormatFlags |= kAudioFormatFlagIsFloat;
//    else if (!IsFlagSet(fmt.iFlag, kAudioFmtFlagUnsignedInteger))
//        desc.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
//
//    desc.mFormatID = kAudioFormatLinearPCM;
//    desc.mFramesPerPacket = 1;  // always 1 for PCM.
//    desc.mChannelsPerFrame = fmt.iNumOfChannels;
//    desc.mBytesPerPacket = fmt.iBitsOfSample / 8 * fmt.iNumOfChannels;
//    desc.mBytesPerFrame = desc.mBytesPerPacket;
//    desc.mBitsPerChannel = fmt.iBitsOfSample;
//    desc.mSampleRate = fmt.iSampleRate;
//    desc.mReserved = 0;
//}

AudioUnit CreateAudioUnitComponent(OSType type, OSType subtype)
{
    AudioComponentDescription desc;
    desc.componentType = type;
    desc.componentSubType = subtype;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    if (inputComponent == NULL)
    {
        LOGE("find audiounit failed type %X, subtype %X", type, subtype);
        return NULL;
    }
    
    AudioComponentInstance unit = NULL;
    OSStatus status = AudioComponentInstanceNew(inputComponent, &unit);
    if (status != noErr)
    {
        LOGE("instance audiounit failed type %X, subtype %X, status %X", type, subtype, status);
        return NULL;
    }
    
    return unit;
}

static IPhoneType gPhoneType = kIphoneUnknown;
IPhoneType getIPhoneType()
{
    if (gPhoneType != kIphoneUnknown)
    {
        return gPhoneType;
    }
    
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = (char *)malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    
    if (strcasecmp(machine, "iPhone1,1") == 0)
        gPhoneType = kIPhone1G;
    else if (strcasecmp(machine, "iPhone1,2") == 0)
        gPhoneType = kIPhone3;
    else if (strcasecmp(machine, "iPhone2,1") == 0)
        gPhoneType = kIPhone3GS;
    else if (strcasecmp(machine, "iPhone3,1") == 0)
        gPhoneType = kIPhone4;
    else if (strcasecmp(machine, "iPhone4,1") == 0)
        gPhoneType = kIPhone4S;
    else if (strcasecmp(machine, "iPhone5,1") == 0)
        gPhoneType = kIPhone5;
    else if (strcasecmp(machine, "iPhone5,2") == 0)
        gPhoneType = kIPhone5S;
    else if (strcasecmp(machine, "iPod1,1") == 0)
        gPhoneType = kIPod;
    else if (strcasecmp(machine, "iPod2,1") == 0)
        gPhoneType = kIPod;
    else if (strcasecmp(machine, "iPod3,1") == 0)
        gPhoneType = kIPod;
    else if (strcasecmp(machine, "iPod4,1") == 0)
        gPhoneType = kIPod;
    else if (strcasecmp(machine, "iPad1,1") == 0)
        gPhoneType = kIPad;
    else if (strcasecmp(machine, "i386") == 0 || strcasecmp(machine, "x86_64") == 0)
        gPhoneType = kEmulator;
    
    free(machine);
    
    return gPhoneType;
}

//uint64_t getDeviceUniqueId()
//{
//    return getDeviceUniqueIdImp();
//}
