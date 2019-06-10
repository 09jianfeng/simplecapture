#include "log.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>

/*
#define AHS_DEBUG(file, fmt, ...)					\
{FILE *fp = fopen(file, "a+");					\
	if (fp)											\
{												\
	fprintf(fp, fmt, __VA_ARGS__);				\
	fprintf(fp, " %u\n", timeGetTime());		\
	fclose(fp);									\
}}
*/

#define MAX_BUF_SIZE 2048

int g_nLogLevel = kLogDebug;
void SetLogLevel(int nLevel)
{
	g_nLogLevel = nLevel;
}

void PlatLog(LogLevel level, LogModule module, const char *format, ...)
{
  if (level < g_nLogLevel)
      return;
    
    char buf[MAX_BUF_SIZE] = { 0 };
    va_list args;

	//format threadid.
	uint32_t uLen = 0;
#ifdef ANDROID
	snprintf(buf, 20, "[%u] ", (uint32_t)gettid());
#else
//  int tid = syscall(SYS_gettid);//always return -1 in iOS
    int tid = -1;
	snprintf(buf, 20, "[%d] ", tid);
#endif
	uLen = (uint32_t)strlen(buf);

    va_start(args, format);
    vsnprintf((char*)(buf + uLen), (MAX_BUF_SIZE - 1 - uLen), format, args);
    va_end(args);
    
    buf[MAX_BUF_SIZE - 1] = 0;
    LogText(level, module, buf);
}

void PlatAssertHelper(bool condition, const char *file, const char *func, const char *format, ...)
{
    if (condition)
        return;
    
    char buf[MAX_BUF_SIZE] = { 0 };
    snprintf(buf, MAX_BUF_SIZE - 1, "LibAssert : [%s] [%s], info: ", file, func);
    LogText(kLogAssert, kLogUnknown, buf);
    
    va_list args;
    va_start(args, format);
    vsnprintf(buf, MAX_BUF_SIZE - 1, format, args);
    va_end(args);
    buf[MAX_BUF_SIZE - 1] = 0;
    LogText(kLogAssert, kLogUnknown, buf);
}
