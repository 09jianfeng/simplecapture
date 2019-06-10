#pragma once
#include "inttypes.h"
#include <set>
#include <deque>
#include <vector>
#include <map>
#include <math.h>

inline bool isBiggerUint32(uint32_t src, uint32_t dest)
{
	return (src != dest && src - dest < 0x7fffffff);
}

inline bool isEqualOrBiggerUint32(uint32_t src, uint32_t dest)
{
	return (src - dest < 0x7fffffff);
}

inline uint32_t getSmoothValue(uint32_t history, uint32_t current)
{
	// 当rtt变大时，变大缓慢一点
	if (current > history)
	{
		return (7 * history + current) >> 3;
	}
	else
	{
		return (7 * history + current) >> 3;
	}
}

inline bool isTooBiggerUint32(uint32_t lastMax, uint32_t current)
{
	if (lastMax == 0)
	{
		return false;
	}

	if (lastMax > 50 && lastMax * 5 < current)
	{
		return true;
	}

	if (lastMax + 500 < current)
	{
		return true;
	}
	return false;
}

inline void limit(uint32_t & x, uint32_t min, uint32_t max)
{
	if (x < min)
	{
		x = min;
	}

	if (x > max)
	{
		x = max;
	}
}

inline bool isEqual(const std::vector<uint32_t>&src, const std::vector<uint32_t>& dest)
{
	if (src.size() != dest.size())
	{
		return false;
	}

	std::vector<uint32_t>::const_iterator srcIt = src.begin();
	std::vector<uint32_t>::const_iterator destIt = dest.begin();

	while (srcIt != src.end() && destIt != dest.end())
	{
		if (*srcIt != *destIt)
		{
			return false;
		}

		++ srcIt;
		++ destIt;
	}

	return true;
}

inline bool isEqual(const std::set<uint32_t>&src, const std::set<uint32_t>& dest)
{
	if (src.size() != dest.size())
	{
		return false;
	}

	std::set<uint32_t>::const_iterator srcIt = src.begin();
	std::set<uint32_t>::const_iterator destIt = dest.begin();

	while (srcIt != src.end() && destIt != dest.end())
	{
		if (*srcIt != *destIt)
		{
			return false;
		}

		++ srcIt;
		++ destIt;
	}

	return true;
}
