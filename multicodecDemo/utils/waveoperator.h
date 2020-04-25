#pragma once

#ifndef _WAVE_H 
#define _WAVE_H 
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <string>
 
#pragma pack(1)
typedef struct _WaveFormat 
{ 
    unsigned short nFormatag;       // ��ʽ���0x01ΪPCM��ʽ���������� 
    unsigned short nChannels;       // ������  
    unsigned int nSamplerate;     // ������  
    unsigned int nAvgBytesRate;   // ����  
    unsigned short nblockalign; 
    unsigned short nBitsPerSample;  // �������      
} WaveFormat; 
#pragma pack() 
 
/******************************************************************************* 
    CWaveWriter�ඨ�壬����дWave��ʽ��Ƶ�ļ�  
*******************************************************************************/ 
class CWaveWriter 
{ 
public: 
     
    CWaveWriter(int sampleRate, int channels, int bitsPerSample); 
    ~CWaveWriter(); 
    bool Open(const char* pFileName); 
    void Close(); 
    int WriteData(unsigned char* pData, int nLen); 
    bool IsOpened();
	FILE* Handle();
private:
    int WriteHeader();
    int WriteTail(); 
private: 
 
    FILE* m_pFile; 
    int m_nFileLen; 
    int m_nOffSetFileLen;     
    int m_nDataLen; 
    int m_nOffSetDataLen; 
    int m_sampleRate;
	int m_nChannels;
	int m_nBitsPerSample;
}; 
 
/******************************************************************************* 
    CWaveReader�ඨ�壬���ڶ�ȡ.wav�ļ��е���Ƶ����  
*******************************************************************************/ 
class CWaveReader 
{ 
public: 
    CWaveReader(); 
    ~CWaveReader(); 
    bool Open(const char* pFileName, WaveFormat* pWaveFormat);
    void Close(); 
    int  ReadData(unsigned char* pData, int nLen); 
    bool GetFormat(WaveFormat* pWaveFormat);
	int GetTotalDataLen();
    FILE* Handle();
private:
    bool ReadHeader(); 
private: 
    FILE* m_pFile; 
    int m_nDataLen; 
    WaveFormat m_WaveFormat; 
}; 

class CWaveOperator
{
public:
	CWaveOperator();
	~CWaveOperator();
	bool ReadTotalWavData(const char* pFileName, std::string& data, int& sampleRate, int& channels);
	bool WriteTotalWavData(const char* pFileName, std::string& data, int sampleRate, int channels);
};
 
#endif 
