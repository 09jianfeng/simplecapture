/*
 * common.h
 *
 *  Created on: Nov 19, 2014
 *      Author: huangwanzhang
 */

#ifndef COMMON_H_
#define COMMON_H_

#ifdef __cplusplus
extern "C" {
#endif
    
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>  // C99
#include <limits.h>
#include <time.h>
    
#ifdef CC_ANDROID
#include <android/log.h>
#include <jni.h>
#endif
    
#include "libffmpeg_event.h"
    
extern void YMTinyVideoFFmpegLog(const char * __restrict fmt, ...);
    
#define CC_DEBUG
    
#ifndef MAX_PATH
#define MAX_PATH 260
#endif
    
#define LOG_MAX_BUFFER_SIZE                     (1024*4)
#define LOG_TAG                                 "medianative"
    
typedef void* HANDLE;

int64_t getcurrenttime_us();
char* mytime();
    
#ifdef CC_ANDROID
#define COMMON_LOG(level, fmt, args...) \
do {    \
char __temp999__[LOG_MAX_BUFFER_SIZE] = {0};   \
snprintf(__temp999__, LOG_MAX_BUFFER_SIZE, fmt, ##args); \
__android_log_print(level, LOG_TAG, fmt, ##args); \
libffmpeg_event_t event;    \
event.type = libffmpeg_event_log;   \
event.u.log_t.log_level = level;    \
event.u.log_t.log_content = __temp999__;   \
ffmpeg_event_callback(&event);   \
}while(0)
#ifdef CC_DEBUG
#define ALOGD(fmt, args...) ((void)__android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, fmt, ##args))
//#define LOGD(fmt, args...)  COMMON_LOG(ANDROID_LOG_DEBUG, fmt, ##args)
#define LOGD(fmt, args...)  ((void)__android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, fmt, ##args))
#else
#define ALOGD(fmt, args...)
#define LOGD(fmt, args...)
#endif
#define LOGI(fmt, args...) COMMON_LOG(ANDROID_LOG_INFO, fmt, ##args)
#define LOGW(fmt, args...) COMMON_LOG(ANDROID_LOG_WARN, fmt, ##args)
#define LOGE(fmt, args...) COMMON_LOG(ANDROID_LOG_ERROR, fmt, ##args)
#define ALOGI(fmt, args...) ((void)__android_log_print(ANDROID_LOG_INFO, LOG_TAG, fmt, ##args))
#define ALOGW(fmt, args...) ((void)__android_log_print(ANDROID_LOG_WARN, LOG_TAG, fmt, ##args))
#define ALOGE(fmt, args...) ((void)__android_log_print(ANDROID_LOG_ERROR, LOG_TAG, fmt, ##args))
#else
#ifdef CC_DEBUG
#define LOGD(fmt, args...) do { 									\
printf("%s[D]:", mytime()); 		\
printf(fmt, ##args); 											\
}while(0)
#else
#define LOGD(fmt, args...)
#endif
//aoe
//#define LOGI(fmt, args...) { 										\
//printf("%s[I]:", mytime()); 		\
//printf(fmt, ##args); 											\
//}
//#define LOGW(fmt, args...) { 										\
//printf("%s[W]:", mytime()); 		\
//printf(fmt, ##args); 											\
//}
//#define LOGE(fmt, args...) { 										\
//printf("%s[E]:", mytime()); 		\
//printf(fmt, ##args); 											\
//}
#define LOGI(fmt, args...) YMTinyVideoFFmpegLog(fmt,##args)
#define LOGW(fmt, args...) YMTinyVideoFFmpegLog(fmt,##args)
#define LOGE(fmt, args...) YMTinyVideoFFmpegLog(fmt,##args)
//aoe
#endif
    
    /* warning: not support nested quotations*/
    char ** argv_create(const char* cmd, int* count);
    void argv_free(char **argv, int argc);
    
    
#ifdef __cplusplus
};
#endif

#endif /* COMMON_H_ */
