//
//  platform_comm.h
//  medialibrary
//
//  Created by sunhonghui on 13-12-9.
//  Copyright (c) 2013年 sunhonghui. All rights reserved.
//

#ifndef medialibrary_platform_comm_h
#define medialibrary_platform_comm_h
#pragma once

#include "mediamodules.h"

bool IsPlatformInitalized();
bool IsApplicationInBackground();
bool IsInMainThread();
void ReportPlatformMessage(MediaLibrary::PlatformMessage msg, void *param);

//network utils
unsigned long long getDeviceUniqueId();

#endif
