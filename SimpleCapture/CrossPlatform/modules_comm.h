//
//  modules_comm.h
//  medialibrary
//
//  Created by sunhonghui on 13-12-5.
//  Copyright (c) 2013年 sunhnghui. All rights reserved.
//

#ifndef medialibrary_modules_comm_h
#define medialibrary_modules_comm_h
#pragma once

#include "mediamodules.h"
#include "mediabase_utils.h"
#include "commonutils.h"
#include "log.h"

struct MediaCodec
{
    MediaCodec()
    : nCodecID(0)
    , nType(0)
    , nLevel(0)
    , bIsHardware(false)
    {
        
    }
    
	int    nCodecID;
	int    nType;   // 0: dec  1:enc
	int    nLevel;  // priority level
    bool   bIsHardware;
	void* (*Create)();
	void  (*Destroy)(void*);
};

struct MediaFilter
{
	int   nFilterID;
	void* (*Create)();
	void  (*Destroy)(void*);
};

#endif
