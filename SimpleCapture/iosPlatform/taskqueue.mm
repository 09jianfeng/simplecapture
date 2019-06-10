//
//  taskqueue.cpp
//  medialibrary
//
//  Created by daiyue on 13-1-30.
//  Copyright (c) 2013年 daiyue. All rights reserved.
//

#include "taskqueue.h"
#include "platform.h"
#include <pthread.h>
#include <map>
#include <vector>
#include <dispatch/dispatch.h>
#include "mediabase_utils.h"
#include "commonutils.h"
#include "log.h"

enum TaskFlag
{
    kTaskFlagTypeSerial = 0,
    kTaskFlagTypeConcurrent = 1,
    kTaskFlagTypeLong = 2,
    kTaskFlagTypeMainThread = 3,
    kTaskFlagTypeMask = 0xF,

    kTaskFlagStateWait = 0x10,
    kTaskFlagStateRun = 0x20,
    kTaskFlagStateMask = 0xF0,
    kTaskFlagAllMask = 0xFF,
};

#define TaskId2TaskFlag(id)     ((int)((TaskQueueId)(id) >> 56))
#define TaskId2TaskType(id)     (TaskId2TaskFlag(id) & kTaskFlagTypeMask)
#define TaskId2TaskState(id)    (TaskId2TaskFlag(id) & kTaskFlagStateMask)
#define CombineTaskId(f, id)    (((TaskQueueId)(f)) << 56 | (id))
#define ClearTaskFlagState(id)  ((TaskQueueId)(id) & ~((TaskQueueId)kTaskFlagStateMask << 56))
#define ClearTaskFlag(id)       ((TaskQueueId)(id) & ~((TaskQueueId)kTaskFlagAllMask << 56))

struct TaskInfo
{
    TaskQueueId iId;    // the highest 8 bits is TaskFlag
    TaskQueuePriority iPriority;
    TaskQueueCallback iCallback;
    void *iContext;
    pthread_t iRunThread;

    // no params constructor used only for map internal.
    TaskInfo()
        : iId (InvalidTaskQueueId)
        , iCallback (NULL)
        , iContext (NULL)
        , iRunThread (NULL)
        , iPriority (kTaskQueuePriNormal)
    {
    }
    
    TaskInfo(const TaskInfo& other)
        : iId (other.iId)
        , iCallback (other.iCallback)
        , iContext (other.iContext)
        , iRunThread (other.iRunThread)
        , iPriority (other.iPriority)
    {
    }
    
    TaskInfo(TaskQueueId id, TaskQueueCallback callback, void *context, TaskQueuePriority priority)
		: iId (id)
		, iCallback (callback)
		, iContext (context)
		, iRunThread (NULL)
        , iPriority (priority)
    {
    }
};

// the taskQueueId for stdTaskInfoMap is the pure id without task type.
typedef std::map<TaskQueueId, TaskInfo> stdTaskInfoMap;

static bool gInitialized = false;

// task info for serial and mainthread task.
static MediaMutex gSerialTaskLock;
static TaskQueueId gNextSerialTaskId = 1;
static dispatch_queue_t gSerialDispatchQueue = NULL;
static stdTaskInfoMap gSerialTasks;

// task info for concurrent task.
static MediaMutex gConcurrentTaskLock;
static TaskQueueId gNextConcurrentTaskId = 1;
static stdTaskInfoMap gConcurrentTasks;

// task info for long job task.
static MediaMutex gLongTaskLock;
static TaskQueueId gNextLongTaskId = 1;
static stdTaskInfoMap gLongTasks;


void InitializeTaskQueue()
{
    if (gInitialized)
        return;
    
    if (gSerialDispatchQueue == NULL)
        gSerialDispatchQueue = dispatch_queue_create("media.platform.serial", DISPATCH_QUEUE_SERIAL);
    
    gInitialized = true;
}

void UninitializeTaskQueue()
{
    if (!gInitialized)
        return;
    
    gInitialized = false;
    
    bool wait = true;
    while (wait)
    {
        wait = false;
        for (int type = 0; type < 3 && !wait; type++)
        {
            MediaMutex *plock = NULL;
            stdTaskInfoMap *pmap = NULL;
            if (type == 0)
            {
                plock = &gConcurrentTaskLock;
                pmap = &gConcurrentTasks;
            }
            else if (type == 1)
            {
                plock = &gSerialTaskLock;
                pmap = &gSerialTasks;
            }
            else
            {
                plock = &gLongTaskLock;
                pmap = &gLongTasks;
            }
            
            plock->Lock();
            for (stdTaskInfoMap::iterator iter = pmap->begin(); !wait && iter != pmap->end(); ++iter)
            {
                if ((type == 1) && (TaskId2TaskType((*iter).second.iId) == kTaskFlagTypeMainThread))
                    continue;   // don't wait for main thread task.
                
                if (IsFlagSet(TaskId2TaskFlag((*iter).second.iId), kTaskFlagStateRun))
                {
                    wait = true;
                    break;
                }
            }
            plock->Unlock();
        }
                
        if (wait)
            ThreadSleep(2);
    }
    
    gSerialTasks.clear();
    gLongTasks.clear();
    gConcurrentTasks.clear();
}

void CommonTaskCallbackHandler(void *param)
{
    TaskQueueId queueId = *(TaskQueueId*)param;
    delete (TaskQueueId*)param;
    
    if (!gInitialized) return;
    
    int type = TaskId2TaskType(queueId);
    TaskQueueId pureid = ClearTaskFlag(queueId);   // pureid
    queueId = ClearTaskFlagState(queueId);
    
    printf("dispatch callback handler type %d, id %lld", type, queueId);
    
    TaskQueueCallback callback = NULL;
    void *context = NULL;
    
    MediaMutex *plock = NULL;
    stdTaskInfoMap *pmap = NULL;
    if (type == kTaskFlagTypeConcurrent)
    {
        plock = &gConcurrentTaskLock;
        pmap = &gConcurrentTasks;
    }
    else if (type == kTaskFlagTypeSerial || type == kTaskFlagTypeMainThread)
    {
        plock = &gSerialTaskLock;
        pmap = &gSerialTasks;
    }
    else
    {
        plock = &gLongTaskLock;
        pmap = &gLongTasks;
    }
    
    plock->Lock();
    if (pmap->count(pureid) > 0)
    {
        TaskInfo &info = (*pmap)[pureid];
        int flag = TaskId2TaskFlag(info.iId);
        if (IsFlagSet(flag, kTaskFlagStateWait) && gInitialized)
        {
            info.iId = CombineTaskId(type | kTaskFlagStateRun, pureid);    // change state to run
            info.iRunThread = pthread_self();
            callback = info.iCallback;
            context = info.iContext;
        }
    }
    plock->Unlock();
    
    printf("dispatch callback handler call type %d, id %lld, cb %X", type, queueId, callback);
    if (callback)
        callback(queueId, context);
    
    plock->Lock();
    pmap->erase(pureid);
    plock->Unlock();
}

void* LongTaskHandler(void *param)
{
	char threadName[] = "YY_yylivesdk_TaskQueue_Thread";
	MediaLibrary::SetThreadName(threadName);
	printf("[thread] create a Thread name:%s", threadName);
    CommonTaskCallbackHandler(param);
    return NULL;
}

void TaskQueueLaterDispatchCallback(void *context)
{
    TaskQueueId taskid = *(TaskQueueId*)context;
    int tasktype = TaskId2TaskType(taskid);
    TaskQueueId pureid = ClearTaskFlag(taskid);
    
    if (tasktype == kTaskFlagTypeSerial || tasktype == kTaskFlagTypeMainThread)
    {
        CommonTaskCallbackHandler(context);
        context = NULL;
    }
    else if (tasktype == kTaskFlagTypeConcurrent)
    {
        CommonTaskCallbackHandler(context);
        context = NULL;
    }
    else if (tasktype == kTaskFlagTypeLong)
    {
        gLongTaskLock.Lock();
        if (gLongTasks.count(pureid) > 0)
        {
            pthread_t newthread;
            pthread_create(&newthread, NULL, LongTaskHandler, context);
            context = NULL;
        }
        gLongTaskLock.Unlock();
    }
    
    if (context)
        delete (TaskQueueId*)context;
}

void TaskQueueAddLaterTask(TaskInfo &task, unsigned int laterMS)
{
    dispatch_queue_t queue;
    int tasktype = TaskId2TaskType(task.iId);
    if (tasktype == kTaskFlagTypeSerial)
        queue = gSerialDispatchQueue;
    else if (tasktype == kTaskFlagTypeMainThread)
        queue = dispatch_get_main_queue();
    else if (tasktype == kTaskFlagTypeLong)
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    else
        queue = dispatch_get_global_queue((dispatch_queue_priority_t)task.iPriority, 0);
    
    TaskQueueId *pid = new TaskQueueId;
    *pid = task.iId;
    
    double delayInSeconds = (double)laterMS / 1000;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after_f(popTime, queue, pid, TaskQueueLaterDispatchCallback);
}

TaskQueueId MediaLibrary::TaskQueueDispatchSerial(TaskQueueCallback callback,
                                    void *context,
                                    unsigned int laterMs,
                                    TaskQueuePriority pri,
                                    int hint)
{
    if (callback == NULL || !gInitialized)
	{
		printf("failed to TaskQueueDispatchSerial %p %u", callback, gInitialized);
		return InvalidTaskQueueId;
	}

    TaskQueueId retid = InvalidTaskQueueId;
    int type = IsFlagSet(hint, kTaskFlagTypeMainThread) ? kTaskFlagTypeMainThread : kTaskFlagTypeSerial;
    
    gSerialTaskLock.Lock();
    TaskInfo task(CombineTaskId(kTaskFlagStateWait | type, gNextSerialTaskId++), callback, context, pri);
    gSerialTasks[ClearTaskFlag(task.iId)] = task;
    retid = ClearTaskFlagState(task.iId);
    gSerialTaskLock.Unlock();
    
    if (laterMs > 0)
    {
        TaskQueueAddLaterTask(task, laterMs);
    }
    else
    {
        TaskQueueId *pid = new TaskQueueId;
        *pid = task.iId;
        
        if (type == kTaskFlagTypeSerial)
            dispatch_async_f(gSerialDispatchQueue, pid, CommonTaskCallbackHandler);
        else
            dispatch_async_f(dispatch_get_main_queue(), pid, CommonTaskCallbackHandler);
    }
    
    printf("dispatch serial id %lld, later %d, pri %d, hint %d", retid, laterMs, pri, hint);
    return retid;
}

TaskQueueId MediaLibrary::TaskQueueDispatchConcurrent(TaskQueueCallback callback,
                                        void *context,
                                        unsigned int laterMs,
                                        TaskQueuePriority pri,
                                        int hint)
{
    if (callback == NULL || !gInitialized)
		return InvalidTaskQueueId;

    TaskQueueId ret = InvalidTaskQueueId;
    if (IsFlagSet(hint, kTaskQueueHintLongJob))
    {
        gLongTaskLock.Lock();
        TaskInfo task(CombineTaskId(kTaskFlagTypeLong | kTaskFlagStateWait, gNextLongTaskId++), callback, context, pri);
        gLongTasks[ClearTaskFlag(task.iId)] = task;
        ret = ClearTaskFlagState(task.iId);
        gLongTaskLock.Unlock();
        
        if (laterMs > 0)
        {
            TaskQueueAddLaterTask(task, laterMs);
        }
        else
        {
            TaskQueueId *pid = new TaskQueueId;
            *pid = task.iId;
            
            pthread_t newthread;
            pthread_create(&newthread, NULL, LongTaskHandler, pid);
        }
    }
    else
    {
        gConcurrentTaskLock.Lock();
        TaskInfo task(CombineTaskId(kTaskFlagTypeConcurrent | kTaskFlagStateWait, gNextConcurrentTaskId++), callback, context, pri);
        gConcurrentTasks[ClearTaskFlag(task.iId)] = task;
        ret = ClearTaskFlagState(task.iId);
        gConcurrentTaskLock.Unlock();
        
        if (laterMs > 0)
        {
           TaskQueueAddLaterTask(task, laterMs);
        }
        else
        {
            TaskQueueId *pid = new TaskQueueId;
            *pid = task.iId;
            dispatch_async_f(dispatch_get_global_queue((dispatch_queue_priority_t)task.iPriority, 0), pid, CommonTaskCallbackHandler);
        }
    }
    
    printf("dispatch concurrent id %lld, later %d, pri %d, hint %d", ret, laterMs, pri, hint);
    return ret;
}

void MediaLibrary::TaskQueueCancel(TaskQueueId cancelId, bool syncWait)
{
    int type = TaskId2TaskType(cancelId);
    TaskQueueId pureid = ClearTaskFlag(cancelId);
    
    if (cancelId == InvalidTaskQueueId || !gInitialized)
        return;
    
    if (type != kTaskFlagTypeConcurrent && type != kTaskFlagTypeLong && type != kTaskFlagTypeSerial && type != kTaskFlagTypeMainThread)
        return;

    printf("dispatch cancel id %lld, type %d, wait %d", cancelId, type, syncWait);
    
    pthread_t selfid = syncWait ? pthread_self() : NULL;
    MediaMutex *plock = NULL;
    stdTaskInfoMap *pmap = NULL;
    if (type == kTaskFlagTypeConcurrent)
    {
        plock = &gConcurrentTaskLock;
        pmap = &gConcurrentTasks;
    }
    else if (type == kTaskFlagTypeSerial || type == kTaskFlagTypeMainThread)
    {
        plock = &gSerialTaskLock;
        pmap = &gSerialTasks;
    }
    else
    {
        plock = &gLongTaskLock;
        pmap = &gLongTasks;
    }
    
    bool wait = true;
    while (wait && gInitialized)
    {
        wait = false;
        
        plock->Lock();
        if (pmap->count(pureid) > 0)
        {
            TaskInfo &task = (*pmap)[pureid];
            int flag = TaskId2TaskFlag(task.iId);
            if (syncWait && selfid != task.iRunThread && IsFlagSet(flag, kTaskFlagStateRun))
                wait = true;
            else
                pmap->erase(pureid);
        }
        plock->Unlock();
                
        if (wait)
            ThreadSleep(5);
    }
}

