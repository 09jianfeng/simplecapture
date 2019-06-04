//
//  BitrateMonitor.hpp
//  SimpleCapture
//
//  Created by Yao Dong on 16/1/25.
//  Copyright © 2016年 duowan. All rights reserved.
//

#ifndef BitrateMonitor_h
#define BitrateMonitor_h

#include <stdio.h>
#include <list>

class BitrateMonitor
{
public:
    BitrateMonitor();
    
    uint32_t actuallyBitrate() const;
    uint32_t actuallyFps() const;
    void appendDataSize(int size);
    uint32_t maxSampleSize() const;
    uint32_t minSampleSize() const;
    uint32_t totalSampleCount() const;
    uint32_t sampleCount() const;
    
private:
    struct RateSample
    {
        uint64_t timestamp;
        uint32_t sampleSize;
        uint64_t streamSize;
    };
    
    uint32_t samplesDuration() const;
    
    uint64_t m_totalStreamSize;
    std::list<RateSample> m_rateSamples;
    int m_totalSampleCount;
};

#endif /* BitrateMonitor_h */
