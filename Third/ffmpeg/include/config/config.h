#ifndef MY_CONFIG
#define MY_CONFIG

#ifdef __arm64__
    #import "./arm64/config.h"
#elif __arm__
    #import "./armv7/config.h"
#elif __i386__
    #import "./i386/config.h"
#elif __x86_64__
    #import "./x86_64/config.h"
#endif
#endif
