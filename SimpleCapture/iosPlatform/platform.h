//
//  platform.h
//  medialibrary
//
//  Created by daiyue on 13-1-30.
//  Copyright (c) 2013年 daiyue. All rights reserved.
//

#ifndef __medialibrary__platform__
#define __medialibrary__platform__

#include <stddef.h>
#include <iostream>
#import <AudioToolbox/AudioToolbox.h>
#include "mediamodules.h"
#include "platform_comm.h"

using namespace MediaLibrary;

// convert our audio format to ios format. Only supported for PCM.
//void ConvertAudioFormatToStreamBasicDesc(const AudioStreamFormat &fmt, AudioStreamBasicDescription &desc);
AudioUnit CreateAudioUnitComponent(OSType type, OSType subtype);

typedef enum
{
    kIphoneUnknown,
    kIPhone1G,
    kIPhone3,
    kIPhone3GS,
    kIPhone4,
    kIPhone4S,
    kIPhone5,
    kIPhone5S,
    kIPod,
    kIPad,
    kEmulator,
} IPhoneType;

IPhoneType getIPhoneType();

//

#endif /* defined(__medialibrary__platform__) */
