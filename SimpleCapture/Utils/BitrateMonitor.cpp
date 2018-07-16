//
//  BitrateMonitor.cpp
//  SimpleCapture
//
//  Created by Yao Dong on 16/1/25.
//  Copyright © 2016年 duowan. All rights reserved.
//

#include <sys/time.h>
#include <map>
#include <string>
#include "BitrateMonitor.h"

const int MAX_DURATION_TIME = 5000;

uint64_t GetTickCount64()
{
    struct timeval tv;
    gettimeofday(&tv,NULL);
    double t = tv.tv_sec * 1000 + tv.tv_usec * 0.001;
    return t;
}

BitrateMonitor::BitrateMonitor()
: m_totalStreamSize(0)
, m_totalSampleCount(0)
{
}

uint32_t BitrateMonitor::actuallyBitrate() const
{
    const RateSample &firstSample = *m_rateSamples.begin();
    const RateSample &lastSample = *m_rateSamples.rbegin();
    
    uint32_t durationTime = samplesDuration();
    if(durationTime > 0) {
        uint64_t bitrate = (lastSample.streamSize - firstSample.streamSize) * 8 * 1000 / durationTime;
        return (uint32_t)bitrate;
    }
    
    return 0;
}

uint32_t BitrateMonitor::actuallyFps() const
{
    uint32_t durationTime = samplesDuration();
    if(durationTime > 0) {
        return uint32_t(m_rateSamples.size() * 1000 / durationTime);
    }
    
    return 0;
}

void BitrateMonitor::appendDataSize(int size)
{
    m_totalSampleCount++;
    m_totalStreamSize += size;
    
    RateSample rs;
    rs.timestamp = GetTickCount64();
    rs.sampleSize = size;
    rs.streamSize = m_totalStreamSize;
    
    m_rateSamples.push_back(rs);
    
    while(samplesDuration() > MAX_DURATION_TIME) {
        m_rateSamples.pop_front();
    }
}

uint32_t BitrateMonitor::maxSampleSize() const
{
    uint32_t maxSize = 0;
    for( const auto &rs : m_rateSamples) {
        if(maxSize < rs.sampleSize) {
            maxSize = rs.sampleSize;
        }
    }
    
    return maxSize;
}

uint32_t BitrateMonitor::minSampleSize() const
{
    uint32_t minSize = 0xFFFFFFFF;
    for(const auto &rs : m_rateSamples) {
        if(minSize > rs.sampleSize) {
            minSize = rs.sampleSize;
        }
    }
    
    return minSize;
}

uint32_t BitrateMonitor::totalSampleCount() const
{
    return m_totalSampleCount;
}

uint32_t BitrateMonitor::sampleCount() const
{
    return (uint32_t)m_rateSamples.size();
}

uint32_t BitrateMonitor::samplesDuration() const
{
    const RateSample &firstSample = *m_rateSamples.begin();
    const RateSample &lastSample = *m_rateSamples.rbegin();
    
    uint64_t durationTime = lastSample.timestamp - firstSample.timestamp;
    
    return (uint32_t)durationTime;
}
