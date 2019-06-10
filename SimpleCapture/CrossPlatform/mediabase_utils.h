#pragma once
#include "mediabase.h"

void MediaLibraryFreeBuffer(void *buffer);

namespace MediaLibrary
{
    void SetThreadName(char* name);
    void GetThreadName(char* name, int bufsize);
    
    /// date and time
    /// sleep current thread for a while.
    /// ms - zero : give up the current CPU slide.
    void ThreadSleep(uint32_t ms);
    
    //  using ::select for to sleep
    void selectSleep(uint32_t ms);
    
    /// get tickcount offset since Platform Initialized in milliseconds.
    /// it will meet max value about 50 days later, but it is okay for phone
    uint32_t GetTickCount();
    
    /// return local UTC time.
    uint32_t GetUTCSeconds();
    uint64_t GetUTCMilliseconds();
    uint64_t GetUTCMicroseconds();

	uint32_t GetUnixTime();
    
    /// buffer allocation
    /// alignment is the N for 2^N (0 ~ 8), 0 means no demand on alignment.
    typedef uint64_t BufferCacheHandle;
#define InvalidBufferCacheHandle    (0)
    
    BufferCacheHandle CreateBufferCache(uint32_t bufferSize, int alignment = 0);
    void DestoryBufferCache(BufferCacheHandle handle);
    
    void* AllocBufferFromCache(BufferCacheHandle handle, bool clear = false);
    void* AllocBuffer(uint32_t size, bool clear = false, int alignment = 0);
    
    /// use same FreeBuffer also for the buffer allocated from cache.
    void FreeBuffer(void *buffer);
	void setEnableBuffCache(bool isEnable);

    void ReleasePictureData(PictureData *data);
    
    /// return the buffer size of allocated by AllocBufferFromCache/AllocBuffer
    /// return 0 if the buffer is not valid.
    uint32_t GetAllocatedBufferSize(void *buffer);
    
    /// task pool
    typedef uint64_t TaskQueueId;
#define InvalidTaskQueueId  (0)
    
    enum TaskQueuePriority
    {
        kTaskQueuePriNormal = 0,
        kTaskQueuePriBackground = -2,
        kTaskQueuePriHigh = 2,
    };
    
    enum TaskQueueHint
    {
        kTaskQueueHintNone = 0,
        kTaskQueueHintLongJob = 1,
        
        // only valid with TaskQueueDispatchSerial to dispatch a task on mainthread.
        kTaskQueueHintMainThread = 2,
    };
    
    typedef void (*TaskQueueCallback)(TaskQueueId id, void *context);
    
    // NOTICE: the dispatched callback may be called before DispacthSerial/Concurrent returns, since it is quit possible for mutli-cpu cores.
    // so be careful to use the returned TaskQueueId in the callback as comparsion.
    TaskQueueId TaskQueueDispatchSerial(TaskQueueCallback callback,
                                        void *context,
                                        uint32_t laterMs = 0,
                                        TaskQueuePriority pri = kTaskQueuePriNormal,
                                        int hint = kTaskQueueHintNone);
    
    TaskQueueId TaskQueueDispatchConcurrent(TaskQueueCallback callback,
                                            void *context,
                                            uint32_t laterMs = 0,
                                            TaskQueuePriority pri = kTaskQueuePriNormal,
                                            int hint = kTaskQueueHintNone);
    
    /// cancel a task in the task queue.
    /// if syncWait is true : if that task queue is running, TaskQueueCancel will wait until that task get finished.
    /// syncWait is false : returns immediately without waiting the task queue get finished if it is running.
    void TaskQueueCancel(TaskQueueId id, bool syncWait = true);    
}

