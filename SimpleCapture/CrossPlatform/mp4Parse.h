#ifndef __MP4Parse_H_
#define __MP4Parse_H_
class CircleBuffer;
//nType: 0, data; 1 , sps; 2, pps
//pFramedata need use MediaLibrary::FreeBuffer free
typedef int  (*frame_cb)(void* context, unsigned char* pFrameData, int nDataLen, int nType);

/* used by SPS and PPS */
struct parameter_sets 
{
	unsigned short size;
	unsigned char *data;
};

struct H264Param
{
	unsigned char configuration_version;
	unsigned char avc_profile_indication;
	unsigned char profile_compatibility;
	unsigned char avc_level_indication;
	int           nal_unit_size;
	int           seq_hdr_count;
	parameter_sets ** pp_seq_hdr;
	int           pic_hdr_count;
	parameter_sets ** pp_pic_hdr;
};

class CMp4Parse
{
public:
	struct H264FrameContext
	{
		unsigned char* pBuf;
		int   nBufPos;
		int   nFrameSize;
	};

	CMp4Parse();
	~CMp4Parse();
	int  Open(void* context, frame_cb cb);
	int  Set264Param(H264Param* pParam);
	int  Parse(const char* pData, int nDataLen);
	void Close();
private:
	int ParseData();
	int H264FrameParse();
	int ResetFrameContext();
	int PushFrameOut();
private:
	bool  m_bFtypOk;
	bool  m_bMdatOk;
	bool  m_bFirstFrame;
    bool  m_NalHeadType;
	unsigned int m_nFtypTagSize;
	CircleBuffer*    m_pBuf;
	H264FrameContext m_FrameContext;

	frame_cb  m_FrmCb;
	void*     m_Context;
	int       m_nFrmCount;
	int       m_nTagRemainData;
	H264Param m_h264Param;
	int       m_nNaluSize;
};

class CH264ParamParse
{
public:
	CH264ParamParse();
	~CH264ParamParse();
	int  Parse(const char* pData, int nDataLen);
	int  GetH264Param(H264Param** ppParam);
private:
	int  ParseData();
	int  ParseOtherBox();
	int  ParseStsdBox();
private:
	int  ParseAvcCBox(CircleBuffer* pBuf, int& nBoxSize);
	int  ParseAvc1Box(CircleBuffer* pBuf, int& nBoxSize);
	int  visual_sample_entry_read(CircleBuffer* pBuf, int& nBoxSize);
private:
	H264Param m_h264Param;
	CircleBuffer*     m_pBuf;
	int               m_nRemainData;
	bool              m_bStsdOk;
	bool              m_bAvcCOk;
	int               m_bStsdTagSize;
	unsigned int      m_nStsdcount;
	char              m_level[10];
};
#endif