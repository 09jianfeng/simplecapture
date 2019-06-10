#pragma once
#include <pthread.h>
#include "inttypes.h"

const uint32_t kThreadNameSize = 100;

const uint32_t kMaxRunUseArraySize = 16;
const uint32_t kRunUseThreshold[kMaxRunUseArraySize] = {5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80, 100, 200, 500, 1000, (uint32_t)-1};

class XThread
{
public:
    XThread(const char* name, uint32_t interval, bool urgent = false);
    virtual ~XThread();
    
public:
    static void* threadFunc(void* p);
    
public:
    virtual void loop();
    virtual void onThreadRun(uint32_t now) = 0;
    virtual void onCreate();
    virtual void onStop();
    
public:
    void stopThread();
    void startThread();
    void wakeUp();
	void resetWakeUpEvent();
	void resetInterval(uint32_t interval);
    bool isQuit() const;
    
private:
    void onUnconditionalLoop();
    void onTimerLoop();
    void onUrgentLoop();
    void checkPerformance(uint32_t now);
	void monitorWakeupTimes(uint32_t now, uint32_t runUse);
    void showThreadPriority();
	void setThreadName();

protected:
    uint32_t m_interval;
    bool m_uncondLoop; // unconditional loop

private:
	uint32_t m_lastTimeoutStamp;
	uint32_t m_lastWakeupStamp;
	uint32_t m_wakeupTimes;
	uint32_t m_callWakeUpCount;
	uint32_t m_callResetWakeUpCount;
	uint32_t m_runUseArray[kMaxRunUseArraySize];
	char m_name[kThreadNameSize];
	int m_pipeFd[2];
    bool m_bQuit;
	bool m_urgent;
    pthread_t m_hThread;
    pthread_cond_t m_condition;
    pthread_mutex_t m_mutex;
};





//
class ITask
{
public:
    virtual void proc() = 0;
};

// generic task as a delegate template

template<class XSubject>
class TGenericTask : public ITask
{
public:
    typedef void (XSubject::*Proc_PMF)();
    
    TGenericTask() : m_pSubject(NULL), m_pmfProc(NULL)
    {}
    
    void delegateBy(XSubject * pSubject, Proc_PMF pmfProc)
    {
        m_pSubject = pSubject;
        m_pmfProc = pmfProc;
    }
    
    virtual void proc()
    {
        (m_pSubject->*m_pmfProc)();
    }
    
private:
    
    XSubject *	m_pSubject;
    Proc_PMF	m_pmfProc;
};

#ifdef __OBJC__
class TObjcTask : public ITask
{
public:
    
    TObjcTask() : m_subject(nil), m_proc(nil)
    {}
    
    void delegateBy(id subject, SEL procSelector)
    {
        m_subject = subject;
        m_proc = procSelector;
    }
    
    virtual void proc()
    {
        [m_subject performSelector:m_proc];
    }
    
private:
    
    id      m_subject;
    SEL     m_proc;
};
#endif

class XTaskThread : public XThread
{
public:
    XTaskThread(const char* name, uint32_t interval, ITask * task = 0);
    void setTask(ITask * task) {
        m_task = task;
    }
    
    virtual void onThreadRun(uint32_t now);
    
private:
    
    ITask * m_task;
};





