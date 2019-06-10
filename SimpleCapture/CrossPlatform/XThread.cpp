#include "XThread.h"
#include "common.h"
#include "UintHelper.h"
#include <sys/select.h>
#include <sys/time.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <string>
#include <sstream>
#include "log.h"
#include "mediabase_utils.h"

#define kThreadLogPrefix "XThread"
#define kPerfLogPrefix "XThreadPer"

#ifdef ANDROID
#include <jni.h>
#include "../../platform/Android/platform.h"
#include <sys/resource.h>
#include <sys/system_properties.h>

#define THREAD_PRIORITY_URGENT_AUDIO -19

int SetAndroidThreadPriority(const char* name, int priority)
{
	jclass process_class;
	jmethodID set_prio_method;
	jthrowable exc;
	JNIEnv *jni_env = 0;
	ATTACH_JVM(jni_env);
	int result = 0;

	//Get pointer to the java class
	process_class = (jclass)jni_env->NewGlobalRef(jni_env->FindClass("android/os/Process"));
	if (process_class == 0) 
	{
		LOGE("%s %s thread setThreadPriority: Not able to find os process class", kThreadLogPrefix, name);
		result = -1;
		goto on_finish;
	}

	LOGT("%s thread %s setThreadPriority: We have the class for process", kThreadLogPrefix, name);

	//Get the set priority function
	set_prio_method = jni_env->GetStaticMethodID(process_class, "setThreadPriority", "(I)V");
	if (set_prio_method == 0) 
	{
		LOGE("%s %s thread setThreadPriority: Not able to find setThreadPriority method", kThreadLogPrefix, name);
		result = -1;
		goto on_finish;
	}
	LOGT("%s %s thread setThreadPriority: We have the method for setThreadPriority", kThreadLogPrefix, name);

	//Call it
	jni_env->CallStaticVoidMethod(process_class, set_prio_method, priority);

	exc = jni_env->ExceptionOccurred();
	if (exc)
	{
		jni_env->ExceptionDescribe();
		jni_env->ExceptionClear();
		LOGE("%s %s thread setThreadPriority: Impossible to set priority using java API, fallback to setpriority", kThreadLogPrefix, name);
		setpriority(PRIO_PROCESS, 0, priority);
	}

on_finish:
	DETACH_JVM(jni_env);
	return result;
}
#endif

XThread::XThread(const char* name, uint32_t interval, bool urgent)
: m_interval(interval)
, m_uncondLoop(false)
, m_lastTimeoutStamp(0)
, m_lastWakeupStamp(0)
, m_wakeupTimes(0)
, m_callWakeUpCount(0)
, m_callResetWakeUpCount(0)
, m_bQuit(true)
, m_urgent(urgent)
, m_hThread(0)
{
	strncpy(m_name, name, kThreadNameSize);
	memset(m_runUseArray, 0, sizeof(m_runUseArray));

	int result = pthread_mutex_init(&m_mutex, 0);
	if (result != 0)
	{
		LOGT("%s %s thread failed to crease mutex", kThreadLogPrefix, m_name);
		return;
	}

	result = pthread_cond_init(&m_condition, 0);
	if (result != 0)
	{
		LOGT("%s %s thread failed to crease condition", kThreadLogPrefix, m_name);
	}

	if (pipe(m_pipeFd) < 0)
	{
		LOGT("%s %s thread pipe error", kThreadLogPrefix, m_name);
	}

	fcntl(m_pipeFd[0], F_SETFL, O_NONBLOCK);
	fcntl(m_pipeFd[1], F_SETFL, O_NONBLOCK);

	LOGT("%s thread(%s) %u %u construct", kThreadLogPrefix, m_name, interval, urgent);
}

XThread::~XThread()
{
	stopThread();
	pthread_cond_destroy(&m_condition);
	pthread_mutex_destroy(&m_mutex);
	close(m_pipeFd[0]);
	close(m_pipeFd[1]);
}

void* XThread::threadFunc(void* pParam)
{
	XThread* pThread = (XThread*) pParam;
	if (pThread)
	{
		pThread->loop();
	}
	return pParam;
}

void XThread::loop()
{
	if (m_urgent)
	{
#ifdef ANDROID
		SetAndroidThreadPriority(m_name, THREAD_PRIORITY_URGENT_AUDIO);
#endif		
	}

	showThreadPriority();
	setThreadName();

	onCreate();
	if (m_uncondLoop)
	{
		onUnconditionalLoop();
	}
	else if (m_urgent)
	{
		onUrgentLoop();
	}
	else
	{
		onTimerLoop();
	}
	onStop();
	resetWakeUpEvent();
}

void XThread::onUnconditionalLoop()
{
	while (!m_bQuit)
	{
		uint32_t now = MediaLibrary::GetTickCount();
		onThreadRun(now);
	}
}

void XThread::onUrgentLoop()
{
	for ( ; ; )
	{
		const long int E6 = 1000000;
		const long int E9 = 1000 * E6;

		unsigned long timeout = m_interval;

		pthread_mutex_lock(&m_mutex);
		timespec end_at;
		timeval value;
		struct timezone time_zone;
		time_zone.tz_minuteswest = 0;
		time_zone.tz_dsttime = 0;
		gettimeofday(&value, &time_zone);
		end_at.tv_sec = value.tv_sec;
		end_at.tv_nsec = value.tv_usec * 1000;

		end_at.tv_sec  += timeout / 1000;
		end_at.tv_nsec += (timeout - (timeout / 1000) * 1000) * E6;

		if (end_at.tv_nsec >= E9)
		{
			end_at.tv_sec++;
			end_at.tv_nsec -= E9;
		}	
		pthread_cond_timedwait(&m_condition, &m_mutex, &end_at);
		pthread_mutex_unlock(&m_mutex);

		if (m_bQuit)
		{
			break;
		}

		uint32_t now = MediaLibrary::GetTickCount();
		checkPerformance(now);
		onThreadRun(now);

		m_lastTimeoutStamp = MediaLibrary::GetTickCount();
		monitorWakeupTimes(m_lastTimeoutStamp, m_lastTimeoutStamp - now);

		if (m_bQuit)
		{
			break;
		}
	}
}

// todo test pthread_cond_timedwait
void XThread::onTimerLoop()
{
	fd_set fdSetRead;
	for ( ; ; )
	{
		FD_ZERO(&fdSetRead);
		FD_SET(m_pipeFd[0], &fdSetRead);
		int maxFd = 0;
		if (m_pipeFd[0] > maxFd)
		{
			maxFd = m_pipeFd[0];
		}

		struct timeval tv;
		tv.tv_sec = 0;
		tv.tv_usec = m_interval * 1000;

		int ret = select(maxFd + 1, &fdSetRead, NULL, NULL, m_interval == 0 ? NULL : &tv);
		if (ret < 0)
		{
			LOGT("%s %s thread onLoop select error %d", kThreadLogPrefix, m_name, ret);
			::usleep(20*1000);
			continue;
		}

		if (m_bQuit)
		{
			break;
		}

		uint32_t now = MediaLibrary::GetTickCount();
		if (m_interval != 0)
		{
			checkPerformance(now);
		}

		onThreadRun(now);
		
		m_lastTimeoutStamp = MediaLibrary::GetTickCount();
		monitorWakeupTimes(m_lastTimeoutStamp, m_lastTimeoutStamp - now);

		if (m_bQuit)
		{
			break;
		}
	}
}

void XThread::stopThread()
{
	if (m_bQuit)
	{
//		LOGT("%s faild to stop thread, %s thread has been stopped", kThreadLogPrefix, m_name);
		return;
	}

	m_bQuit = true;

	if (m_hThread == 0)
	{
		LOGT("%s !!!bug %s thread handle is null when stop", kThreadLogPrefix, m_name);
		return;
	}

	LOGT("%s stop %s thread", kThreadLogPrefix, m_name);
	wakeUp();

	pthread_join(m_hThread, NULL);
	m_hThread = 0;
	LOGT("%s %s thread stop successfully", kThreadLogPrefix, m_name);
}

void XThread::startThread()
{
	if (!m_bQuit)
	{
		LOGT("%s failed to start thread, %s thread has been started", kThreadLogPrefix, m_name);
		return;
	}

	m_bQuit = false;

	int err = 0;
	if (m_urgent)
	{
		pthread_attr_t attr;
		pthread_attr_init(&attr);
		if (pthread_attr_init(&attr) != 0)
		{
			LOGT("%s failed to call pthread_attr_init in %s thread", kThreadLogPrefix, m_name);
		}

		// Set real-time round-robin policy.
		if (pthread_attr_setschedpolicy(&attr, SCHED_RR) != 0) 
		{
			LOGT("%s failed to call pthread_attr_setschedpolicy in %s thread", kThreadLogPrefix, m_name);
		}

		struct sched_param param;
		memset(&param, 0, sizeof(param));
		param.sched_priority = 6;           // 6 = HIGH
		if (pthread_attr_setschedparam(&attr, &param) != 0) 
		{
			LOGT("%s failed to call pthread_attr_setschedparam in %s thread", kThreadLogPrefix, m_name);
		}

		err = pthread_create(&m_hThread, &attr, &threadFunc, this);
	}
	else
	{
		err = pthread_create(&m_hThread, NULL, &threadFunc, this);
	}

	if (err != 0)
	{
		m_hThread = 0;
		m_bQuit = true;
		LOGT("%s failed to create %s thread %u", kThreadLogPrefix, m_name, err);
		return;
	}

	LOGT("%s start %s thread %s interval %u", kThreadLogPrefix, m_name, m_urgent ? "urgent" : "unurgent", m_interval);
}

void XThread::wakeUp()
{
	const char *pCh = "a";
	if (write(m_pipeFd[1], pCh, 1) <= 0)
	{
		LOGT("%s %s thread wakeup error %s", kThreadLogPrefix, m_name, strerror(errno));
	}
	++ m_callWakeUpCount;
	//LOGT("%s %s thread wakeup now %u", kThreadLogPrefix, m_name, MediaLibrary::GetTickCount());
}


void XThread::resetWakeUpEvent()
{
	char buf[2048]={0};
	if (read(m_pipeFd[0], buf, 2048) <= 0)
	{
		int errorCode = errno;
		if (errorCode != EAGAIN)
		{
			LOGT("%s %s thread resetWakeUpEvent failed errCode %d info %s", kThreadLogPrefix, m_name, errorCode, strerror(errorCode));
		}
	}
	++ m_callResetWakeUpCount;
}

bool XThread::isQuit() const
{
	return m_bQuit;
}

void XThread::onCreate()
{
	LOGT("%s %s thread created %u", kThreadLogPrefix, m_name, m_interval);
}

void XThread::onStop()
{
	LOGT("%s exit %s thread %u", kThreadLogPrefix, m_name, m_interval);
}

void XThread::checkPerformance(uint32_t now)
{
	if (m_lastTimeoutStamp == 0)
	{
		return;
	}

	if (isBiggerUint32(m_lastTimeoutStamp, now))
	{
		LOGT("%s %s thread system time has been modified, last %u cur %u diff %u", kPerfLogPrefix, m_name, m_lastTimeoutStamp, now, m_lastTimeoutStamp - now);
		return;
	}

	const uint32_t kMaxInterval = 100;
	uint32_t deltaT = now - m_lastTimeoutStamp;
	if (deltaT > kMaxInterval + m_interval)
	{
		LOGT("%s %s thread process spend too long %u %u", kPerfLogPrefix, m_name, m_interval, deltaT);
	}
}

void XThread::monitorWakeupTimes(uint32_t now, uint32_t runUse)
{
	++ m_wakeupTimes;
	for (uint32_t i = 0; i < kMaxRunUseArraySize; ++ i)
	{
		if (runUse <= kRunUseThreshold[i])
		{
			++ m_runUseArray[i];
			break;
		}
	}

	if (m_lastWakeupStamp == 0)
	{
		m_lastWakeupStamp = now;
		return;
	}

	const uint32_t kTimeout = 32 * 1000;
	if (isBiggerUint32(m_lastWakeupStamp + kTimeout, now))
	{
		return;
	}

	std::ostringstream oss;
	for (uint32_t i = 0; i < kMaxRunUseArraySize; ++ i)
	{
		oss << " " << (int)kRunUseThreshold[i] << ":" << m_runUseArray[i];
	}

	LOGT("%s %s thread in past %u ms, wakeup %u times callWakeupCount %u callResetWakeUpCount %u runUse(%s)", 
		kThreadLogPrefix, m_name, now - m_lastWakeupStamp, m_wakeupTimes, m_callWakeUpCount, m_callResetWakeUpCount, oss.str().c_str());

	m_lastWakeupStamp = now;
	m_wakeupTimes = 0;
	m_callWakeUpCount = 0;
	m_callResetWakeUpCount = 0;
	memset(m_runUseArray, 0, sizeof(m_runUseArray));
}

void XThread::showThreadPriority()
{
	pthread_attr_t attr;
	int ret = pthread_attr_init(&attr);
	if (ret != 0)
	{
		LOGT("%s failed to call pthread_attr_init in %s thread", kThreadLogPrefix, m_name);
		return;
	}

	int policy = 0;
	ret = pthread_attr_getschedpolicy(&attr, &policy);
	if (ret != 0)
	{
		LOGT("%s failed to call pthread_attr_getschedpolicy in %s thread", kThreadLogPrefix, m_name);
		return;
	}

	struct sched_param param;
	memset(&param, 0, sizeof(param));
	ret = pthread_attr_getschedparam(&attr, &param);
	if (ret != 0)
	{
		LOGT("%s failed to call pthread_attr_getschedparam in %s thread", kThreadLogPrefix, m_name);
		return;
	}

	int maxPriority = sched_get_priority_max(policy);
	int minPriority = sched_get_priority_min(policy);

	LOGT("%s thread priority in %s thread, policy %d minPriority %d maxPriority %d curPriority %u", kThreadLogPrefix, m_name,
		policy, minPriority, maxPriority, param.sched_priority);
}

void XThread::resetInterval(uint32_t interval)
{
	m_interval = interval;
}

//按业务方要求，取线程名字为YST_模块名，其中，模块名：sdk名+模块名简写
//man page说使用api prctl给线程起名字，最多只能16个字符，包括最后的null字符，多出来的会被截断
//实际测试中，ios没有此限制，android有
void XThread::setThreadName()
{
	const uint32_t kThreadNameLength = 16;
	char threadName[kThreadNameLength] = "YST_yylive";
	uint32_t threadNamePrefixLength = (uint32_t)strlen(threadName);	// "YST_yylive"长度，不算null
	if (kThreadNameLength > threadNamePrefixLength)
	{
		strncpy(threadName + threadNamePrefixLength, m_name, kThreadNameLength - threadNamePrefixLength - 1);
	}

	LOGT("%s create a Thread name:%s", kThreadLogPrefix, threadName);

	MediaLibrary::SetThreadName(threadName);
}

 XTaskThread::XTaskThread(const char* name, uint32_t interval, ITask * task) : XThread(name, interval),  m_task(task)
{
	m_uncondLoop= (interval==0);
}

void XTaskThread::onThreadRun(uint32_t now)
{
	if (!m_task) {
		LOGT("erroooooooo");
		return;
	}

	m_task->proc();
}
