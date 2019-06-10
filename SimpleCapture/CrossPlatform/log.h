#ifndef _LOG_H_
#define _LOG_H_

#pragma once
#include "mediabase.h"

void PlatLog(LogLevel level, LogModule module, const char *format, ...);
void PlatAssertHelper(bool condition, const char *file, const char *func, const char *format, ...);   
void SetLogLevel(int nLevel);
extern void LogText(LogLevel level, LogModule module, const char *text);

#if defined(_WINDOWS)
#define PlatAssert(e, format, ...)  do { PlatAssertHelper(e, __FILE__, __func__, format, ##args); } while(0)
#define LibAssert(e, format, ...)  do { PlatAssertHelper(e, __FILE__, __func__, format, ##args); } while(0)
#define Log(level, format, ...)			 do { PlatLog(level, kLogPlatform, format, ##args); } while(0)
#define LogM(level, module, format, ...)	do { PlatLog(level, module, format, ##args); } while(0)

#define  LOGD(format,...)  Log(kLogDebug,format,##args)
#define  LOGI(format,...)  Log(kLogInfo,format,##args)
#define  LOGE(format,...)  Log(kLogError,format,##args)
#define  LOGW(format,...)  Log(kLogWarning,format,##args)
#define  LOGT(format,...)  Log(kLogInfo,format,##args)

#else

#define PlatAssert(e, format, args...)  do { PlatAssertHelper(e, __FILE__, __func__, format, ##args); } while(0)
#define LibAssert(e, format, args...)  do { PlatAssertHelper(e, __FILE__, __func__, format, ##args); } while(0)
#define Log(level, format, args...)			 do { PlatLog(level, kLogPlatform, format, ##args); } while(0)
#define LogM(level, module, format, args...)	do { PlatLog(level, module, format, ##args); } while(0)

#define  LOGD(format,args...)  Log(kLogDebug,format,##args)
#define  LOGI(format,args...)  Log(kLogInfo,format,##args)
#define  LOGE(format,args...)  Log(kLogError,format,##args)
#define  LOGW(format,args...)  Log(kLogWarning,format,##args)
#define  LOGT(format,args...)  Log(kLogInfo,format,##args)

#endif

class InfoTracker
{
public:
	InfoTracker()
	: m_info(NULL)
	, m_value(0)
	, m_level(kLogTrace)
	{
	}
	
	InfoTracker(const char* msg, int value, bool force)
	{   //the msg point should keep alive after the InfoTracker instance be released
		m_info = msg;
		m_value = value;
		m_level = kLogTrace;
		if (force)
		{
			m_level = kLogInfo;
		}
		Recorder(0);
	}
	
	~InfoTracker()
	{
		if (m_info != NULL)
		{
			Recorder(1);
		}
	}
	
private:
	void Recorder(int mode)
	{
		if (mode == 0)
		{
			LogM(m_level, kLogBiz, "[FUNC] Enter %s para = %d", m_info, m_value);
		}
		else
		{
			LogM(m_level, kLogBiz, "[FUNC] Leave %s para = %d", m_info, m_value);
		}
	}
	
	const char* m_info;
	int m_value;
	LogLevel m_level;
};

void PlatformSetLogFilter(const char *filter);
//
#define ENTRY_TRACK(x)		InfoTracker local_info_tracker((x), 0, false);
#define ENTRY_TRACK_EX(x, y)  InfoTracker local_info_tracker((x), (y), false);
#define ENTRY_TRACK_EX_FORCE(x, y)  InfoTracker local_info_tracker((x), (y), true);

#endif