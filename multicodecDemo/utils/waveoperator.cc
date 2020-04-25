#include "waveoperator.h"

///////////////////////////////////////    
// CWaveWriter类实现     

CWaveWriter::CWaveWriter(int sampleRate, int channels, int bitsPerSample)   
:m_pFile(0)   
,m_nFileLen(0)   
,m_nOffSetFileLen(0)   
,m_nDataLen(0)   
,m_nOffSetDataLen(0)
,m_sampleRate(sampleRate)
,m_nChannels(channels)
,m_nBitsPerSample(bitsPerSample)
{

}   

CWaveWriter::~CWaveWriter()   
{   
	Close();   
}   

bool CWaveWriter::IsOpened()
{
    return (m_pFile ? true : false);
}

bool CWaveWriter::Open(const char* pFileName)   
{   
	Close();   
	m_pFile = fopen(pFileName, "wb");   
	if(!m_pFile)   
		return false;   

    WriteHeader();

	return true;   
}   

void CWaveWriter::Close()   
{   
	if(m_pFile)   
	{   
        WriteTail();
		fclose(m_pFile);   
		m_pFile = 0;   
	}   
}   

int CWaveWriter::WriteHeader()   
{   
	fwrite("RIFF", 1, 4, m_pFile);   
	fwrite(&m_nFileLen, 4, 1, m_pFile);  // 占位，最后需修改    
	fwrite("WAVE", 1, 4, m_pFile);   
	fwrite("fmt ", 1, 4, m_pFile);     
	int nFormatSize = 0x00000010;        // 16 bytes 
	fwrite(&nFormatSize, 4, 1, m_pFile);
	int nFormatTag = 1;
	fwrite(&nFormatTag, 2, 1, m_pFile);
	fwrite(&m_nChannels, 2, 1, m_pFile);   
	fwrite(&m_sampleRate, 4, 1, m_pFile);
	int nAvgBytesRate = m_sampleRate * m_nBitsPerSample * m_nChannels / 8;
	fwrite(&nAvgBytesRate, 4, 1, m_pFile);
	int nblockalign = m_nBitsPerSample / 8 * m_nChannels;
	fwrite(&nblockalign, 2, 1, m_pFile);   
	fwrite(&m_nBitsPerSample, 2, 1, m_pFile);   
	fwrite("data", 1, 4, m_pFile);   
	fwrite(&m_nDataLen, 4, 1, m_pFile);  // 占位，最后需修改    

	m_nFileLen = 0x2C;   
	m_nDataLen = 0x00;   
	m_nOffSetFileLen = 0x04;   
	m_nOffSetDataLen = 0x28;   

	return 0x2C;   
}   

int CWaveWriter::WriteData(unsigned char* pData, int nLen)   
{   
	fwrite(pData, 1, nLen, m_pFile);   
	m_nDataLen += nLen;   
	m_nFileLen += nLen;   
	return nLen;   
}   

int CWaveWriter::WriteTail()   
{   
	fseek(m_pFile, m_nOffSetFileLen, SEEK_SET);   
	fwrite(&m_nFileLen, 4, 1, m_pFile);   
	fseek(m_pFile, m_nOffSetDataLen, SEEK_SET);   
	fwrite(&m_nDataLen, 4, 1, m_pFile);       
	return 0;   
}   

FILE* CWaveWriter::Handle()
{
    return m_pFile;
}

////////////////////////////////////////////    
// CWaveReader类实现    

CWaveReader::CWaveReader()   
: m_pFile(0)
, m_nDataLen(0)
{   
	memset(&m_WaveFormat, 0, sizeof(m_WaveFormat));   
}    

CWaveReader::~CWaveReader()   
{   
	Close();   
}   

bool CWaveReader::Open(const char* pFileName, WaveFormat* pWaveFormat)
{   
	Close();   
	m_pFile = fopen(pFileName, "rb");   
	if( !m_pFile )   
		return false;   

	if( !ReadHeader() )
		return false;

	memcpy(pWaveFormat, &m_WaveFormat, sizeof(m_WaveFormat));

	return true;      
}   

void CWaveReader::Close()   
{   
	if(m_pFile)   
	{   
		fclose(m_pFile);   
		m_pFile = 0;   
	}   
}   

bool CWaveReader::ReadHeader()   
{   
	if(!m_pFile)   
		return false;   

	int Error = 0;   
	do   
	{   
		char data[5] = { 0 };   

		fread(data, 4, 1, m_pFile);   
		if(strcmp(data, "RIFF") != 0)   
		{   
			Error = 1;   
			break;   
		}   

		fseek(m_pFile, 4, SEEK_CUR);   
		memset(data, 0, sizeof(data));   
		fread(data, 4, 1, m_pFile);   
		if(strcmp(data, "WAVE") != 0)   
		{   
			Error = 1;   
			break;   
		}   

		memset(data, 0, sizeof(data));   
		fread(data, 4, 1, m_pFile);   
		if(strcmp(data, "fmt ") != 0)   
		{   
			Error = 1;   
			break;   
		}   

		memset(data, 0, sizeof(data)); 
		fread(data, 4, 1, m_pFile);   

		int nFmtSize =  data[3] << 24;
		nFmtSize	+=  data[2] << 16;
		nFmtSize    +=  data[1] << 8;
		nFmtSize    +=  data[0];

		if(nFmtSize >= 16)
		{
			if( fread(&m_WaveFormat, 1, sizeof(m_WaveFormat), m_pFile)    
				!= sizeof(m_WaveFormat) )   
			{   
				Error = 1;   
				break;   
			}
			fseek(m_pFile, nFmtSize - 16, SEEK_CUR); // some are 18 Bytes Size
		}
		else 
		{
			return false;
		}

		memset(data, 0, sizeof(data));   
		bool bFindData = false;
		do
		{
			fread(data, 4, 1, m_pFile);   
			if(strcmp(data, "data") == 0)   
			{   
				bFindData = true;
				break;   
			}
			else
			{
				unsigned int len;
				fread(&len, 4, 1, m_pFile);
				fseek(m_pFile, len, SEEK_CUR);
			}
		}while(!feof(m_pFile));

		if(bFindData)
		{
			fread(&m_nDataLen, 4, 1, m_pFile);          
		}
		else
		{
			Error = 1;   
		}
	}while(0);   


	ftell(m_pFile);
	if(0 == Error)   
		return true;   
	else
		fseek(m_pFile, 0, 0);

	return false;   
}   

int CWaveReader::ReadData(unsigned char* pData, int nLen)   
{      
	if(m_pFile)   
		return fread(pData, 1, nLen, m_pFile);   

	return -1;   
}   

bool CWaveReader::GetFormat(WaveFormat* pWaveFormat)   
{   
	memcpy(pWaveFormat, &m_WaveFormat, sizeof(m_WaveFormat));   
	return true;
}   

int CWaveReader::GetTotalDataLen()
{
	return m_nDataLen;
}

FILE* CWaveReader::Handle()
{
    return m_pFile;
}

CWaveOperator::CWaveOperator()
{

}

CWaveOperator::~CWaveOperator()
{

}

bool CWaveOperator::ReadTotalWavData(const char* pFileName, std::string& data, int& sampleRate, int& channels)
{
	CWaveReader wavReader;
	WaveFormat wavFormat;
	if (!wavReader.Open(pFileName, &wavFormat))
	{
		printf("CWaveOperator Wav file: %s open fail.\n", pFileName);
		return false;
	}
	sampleRate = wavFormat.nSamplerate;
	channels = wavFormat.nChannels;
	int totalDataLen = wavReader.GetTotalDataLen();
	data.resize(totalDataLen);
	if (wavReader.ReadData((unsigned char*)data.c_str(), totalDataLen) != totalDataLen)
		return false;
	return true;
}

bool CWaveOperator::WriteTotalWavData(const char* pFileName, std::string& data, int sampleRate, int channels)
{
	CWaveWriter wavWriter(sampleRate, channels, 16);
	if (!wavWriter.Open(pFileName))
	{
		printf("CWaveOperator Wav file: %s create fail.\n", pFileName);
		return false;
	}
	wavWriter.WriteData((unsigned char*)data.c_str(), data.size());
	return true;
}

