#include "mp4Parse.h"
#include "../../include/modules_comm.h"
#include "../../Android/platform.h"
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <math.h>
#include <ctype.h>
#include <assert.h>
#ifndef min
#define min(a,b) (a > b?b:a)
#endif
class CircleBuffer
{
public:
	CircleBuffer(const char *name)
	{
		assert(name != NULL);

		iBufName = name;
		iBuffer = NULL;
		iStartIdx = iDataLength = 0;
		iBufLength = 1024 * 16;
		iBuffer = (char*)MediaLibrary::AllocBuffer(iBufLength);
	}

	~CircleBuffer()
	{
		MediaLibrary::FreeBuffer(iBuffer);
	}

	void Reset()
	{
		iStartIdx = iDataLength = 0;
		iPushDataCnt = iPullDataCnt = 0;
	}

	int DataLength() const
	{
		return iDataLength;
	}

	void PushData(void *pdata, int length)
	{
		if (length <= 0)
			return;

		iPushDataCnt += length;

		if (length + iDataLength > iBufLength)
		{
			int oldDataLength = iDataLength;
			int newlength = length + iDataLength + 1024 * 4;

			char *newbuffer = (char*)MediaLibrary::AllocBuffer(newlength);
			if (iDataLength > 0)
			{
				(void)PullDataInternal(newbuffer, iDataLength);
//				assert(ret == 0 && iDataLength == 0);
			}

            if(iBuffer)
                MediaLibrary::FreeBuffer(iBuffer);
			iBuffer = newbuffer;
			iBufLength = newlength;
			iDataLength = oldDataLength;
			iStartIdx = 0;
		}

		// data end index.
		int endidx = (iStartIdx + iDataLength) % iBufLength;

		int leftlen = iBufLength - endidx;
		if (leftlen > length) leftlen = length;

		memcpy(iBuffer + endidx, pdata, leftlen);
		iDataLength += leftlen;
		length -= leftlen;
		pdata = (char*)pdata + leftlen;

		if (length > 0)
		{
			endidx = (iStartIdx + iDataLength) % iBufLength;
			memcpy(iBuffer + endidx, pdata, length);
			iDataLength += length;
		}

		assert(iDataLength <= iBufLength);

	}

	int PullData(void *pdata, int length)
	{
		int ret = PullDataInternal(pdata, length);
		if (ret >= 0)
		{
			iPullDataCnt += length;
		}

		return ret;
	}

private:

	int PullDataInternal(void *pdata, int length)
	{
		if (length <= 0)
			return 0;

		if (pdata == NULL)
			return -1;

		if (length > iDataLength)
			return -2;

		assert(iDataLength > 0);

		if (iStartIdx + iDataLength <= iBufLength)
		{
			// the data is not circled.
			memcpy(pdata, iBuffer + iStartIdx, length);
			iStartIdx += length;
			iDataLength -= length;

			if (iStartIdx >= iBufLength)
				iStartIdx = 0;
		}
		else
		{
			int seglen = iBufLength - iStartIdx;
			if (seglen > length) seglen = length;

			memcpy(pdata, iBuffer + iStartIdx, seglen);
			length -= seglen;
			pdata = (char*)pdata + seglen;
			iDataLength -= seglen;
			iStartIdx += seglen;

			if (iStartIdx >= iBufLength)
				iStartIdx = 0;

			if (length > 0)
			{
				assert(iStartIdx == 0);

				memcpy(pdata, iBuffer + iStartIdx, length);
				iStartIdx += length;
				iDataLength -= length;
			}
		}

		return 0;
	}

	int iBufLength;
	int iStartIdx;
	int iDataLength;
	char *iBuffer;
	const char *iBufName;

	unsigned int iPushDataCnt;
	unsigned int iPullDataCnt;
};

//static int fourcc_to_str(unsigned int type, char *buf, int buf_size)
//{
//	unsigned int i;
//	int ch;
//
//	if (buf == NULL || buf_size < 5)
//		return -1;
//
//	for (i = 0; i < 4; i++, buf++) {
//		ch = type >> (8 * (3 - i)) & 0xff;
//		if (isprint(ch))
//			*buf = ch;
//		else
//			*buf = '.';
//	}
//
//	*buf = 0;
//
//	return 0;
//}

/*
#define print_fourcc(Tag, level) \
{\
	char brand_str[5]; \
	fourcc_to_str(Tag, brand_str, 5); \
       printf("%s%s\n", level, brand_str); \
}
*/
#define print_fourcc(Tag, level)

#define swap32(A)   ((((unsigned int )(A) & 0xff000000) >> 24) | \
	(((unsigned int)(A) & 0x00ff0000) >> 8)    | \
	(((unsigned int)(A) & 0x0000ff00) << 8)    | \
	(((unsigned int)(A) & 0x000000ff) << 24))


#define swap16(A)   ((((unsigned short )(A) & 0xff00) >> 8) | (((unsigned short)(A) & 0x00ff) << 8))

static int ReadContent(CircleBuffer* pBuf, int nContentSize)
{
	if(nContentSize <= 0)
		return -1;

	char tmpBuf[4096];
	int nDataSize    = pBuf->DataLength();
	while(nDataSize > 0 && nContentSize > 0)
	{
		int nPullSize = min(min(nContentSize, nDataSize), 4096);
		pBuf->PullData(tmpBuf, nPullSize);

		nDataSize = pBuf->DataLength();
		nContentSize -= nPullSize;
	}
	return nContentSize;
}

static int mp4_Box_parse(CircleBuffer* pBuf, unsigned int *pBoxTag)
{
	if(pBuf->DataLength() < 8)
		return -1;

	unsigned int nSize;
	pBuf->PullData(&nSize, 4);
	nSize = swap32(nSize);

	if(nSize == 0)
		nSize = pBuf->DataLength();

	pBuf->PullData(pBoxTag, 4);
	*pBoxTag = swap32(*pBoxTag);

	return nSize;
}


CMp4Parse::CMp4Parse()
{
	m_pBuf    = new CircleBuffer("mp4p");
	memset(&m_FrameContext, 0, sizeof(m_FrameContext));
	m_FrameContext.nFrameSize = -1;
	m_nFrmCount = 0;
	m_FrmCb = NULL;
	m_Context = NULL;
	m_nTagRemainData = 0;
	m_bMdatOk = false;
	m_bFtypOk = false;
	m_nNaluSize = 4;
	m_nFtypTagSize = 0;
}

CMp4Parse::~CMp4Parse()
{
	if(m_pBuf)
	{
		delete m_pBuf;
		m_pBuf = NULL;
	}
}


int  CMp4Parse::Open(void* context, frame_cb cb)
{
	m_nFrmCount = 0;
	m_Context = context;
	m_FrmCb = cb;
    m_NalHeadType = 1;
	m_pBuf->Reset();
	memset(&m_h264Param, 0 , sizeof(H264Param));
	return 0;
}

int  CMp4Parse::Set264Param(H264Param* pParam)
{
	if(pParam)
	{
		m_h264Param.configuration_version  = pParam->configuration_version;
		m_h264Param.avc_profile_indication = pParam->avc_profile_indication;
		m_h264Param.profile_compatibility  = pParam->profile_compatibility;
		m_h264Param.avc_level_indication   = pParam->avc_level_indication;
		m_h264Param.nal_unit_size =  pParam->nal_unit_size;
		m_h264Param.seq_hdr_count =  pParam->seq_hdr_count; //seq_hdr
		m_h264Param.pp_seq_hdr = (parameter_sets **) MediaLibrary::AllocBuffer(m_h264Param.seq_hdr_count * sizeof(parameter_sets *));

		for (int i = 0; i < m_h264Param.seq_hdr_count; i++) 
		{
			m_h264Param.pp_seq_hdr[i] = (parameter_sets *) MediaLibrary::AllocBuffer(sizeof(struct parameter_sets));
			memcpy(m_h264Param.pp_seq_hdr[i], pParam->pp_seq_hdr[i], sizeof(parameter_sets));
		}

		m_h264Param.pic_hdr_count =  pParam->pic_hdr_count; //seq_hdr
		m_h264Param.pp_pic_hdr = (parameter_sets **) MediaLibrary::AllocBuffer(m_h264Param.pic_hdr_count * sizeof(parameter_sets *));

		for (int i = 0; i < m_h264Param.seq_hdr_count; i++) 
		{
			m_h264Param.pp_pic_hdr[i] = (parameter_sets *) MediaLibrary::AllocBuffer(sizeof(struct parameter_sets));
			memcpy(m_h264Param.pp_pic_hdr[i], pParam->pp_pic_hdr[i], sizeof(parameter_sets));
		}
		if(pParam->nal_unit_size > 0)
		{
			m_nNaluSize = pParam->nal_unit_size;
		}

	}
	return 0;
}

int  CMp4Parse::Parse(const char* pData, int nDataLen)
{
	m_pBuf->PushData((void*)pData, nDataLen);
	if( ParseData() < 0)
		return -1;

	return 0;
}

void CMp4Parse::Close()
{
    m_bFtypOk = false;
	m_bMdatOk = false;
	m_pBuf->Reset();

	if(m_h264Param.seq_hdr_count > 0)
	{
		for(int i = 0; i< m_h264Param.seq_hdr_count; ++i)
			MediaLibrary::FreeBuffer(m_h264Param.pp_seq_hdr[i]);

		MediaLibrary::FreeBuffer(m_h264Param.pp_seq_hdr);
		m_h264Param.pp_seq_hdr = NULL;
	}
	if(m_h264Param.pic_hdr_count > 0)
	{
		for(int i = 0; i< m_h264Param.pic_hdr_count; ++i)
			MediaLibrary::FreeBuffer(m_h264Param.pp_pic_hdr[i]);

		MediaLibrary::FreeBuffer(m_h264Param.pp_pic_hdr);
		m_h264Param.pp_pic_hdr = NULL;
	}
    
    if(m_FrameContext.pBuf)
    {
        MediaLibrary::FreeBuffer(m_FrameContext.pBuf);
        m_FrameContext.pBuf = NULL;
    }

}

//--------------------------------------------------------
int CMp4Parse::ParseData()
{
	int FindCount = 40;
	if(!m_bMdatOk )
	{
		while(FindCount)
		{
			if(m_pBuf->DataLength() < 4)
				return -1;

			unsigned int nTag = 0;
			m_pBuf->PullData(&nTag, 4);
			nTag = swap32(nTag);
			if(nTag != 0x6d646174) //mdat
			{
			    FindCount --;
				continue;
			}
				
			m_bMdatOk = true;
			m_bFirstFrame = true;
			break;
		}
	}

	if(m_bMdatOk)
	{
		//h264 data parse
		H264FrameParse();
	}
	return 0;
}


int CMp4Parse::H264FrameParse()
{
	if(!m_FrameContext.pBuf)
		if(ResetFrameContext() != 0)
			return 0;

	int nDataSize = m_pBuf->DataLength();
	while(nDataSize >= (m_FrameContext.nFrameSize - m_FrameContext.nBufPos))
	{
		int nBufLen   = m_FrameContext.nFrameSize - m_FrameContext.nBufPos;
		int nPullSize = nDataSize > nBufLen? nBufLen : nDataSize;
		m_pBuf->PullData(&m_FrameContext.pBuf[m_FrameContext.nBufPos], nPullSize);
		m_FrameContext.nBufPos += nPullSize;
		if(m_FrameContext.nBufPos == m_FrameContext.nFrameSize)
		{
			if( PushFrameOut() != 0)
				break;
		}
		nDataSize = m_pBuf->DataLength();
	}
	return 0;
}


const char FrameHeader[4] = {0, 0, 0, 1};
static int g_bWriteHeader = false;
int CMp4Parse::PushFrameOut()
{
    if(m_FrmCb)
	{
        if(m_bFirstFrame)
        {
            if(!g_bWriteHeader)
            {
                for(int i = 0; i < m_h264Param.seq_hdr_count; ++i)
                {
                    // out sps
                    int nSize = m_h264Param.pp_seq_hdr[i]->size ;
                    unsigned char* pSpsBuf = (unsigned char*)MediaLibrary::AllocBuffer(nSize);
                    memcpy(pSpsBuf , m_h264Param.pp_seq_hdr[i]->data, m_h264Param.pp_seq_hdr[i]->size);
                    m_FrmCb(m_Context, pSpsBuf, nSize, 1);
                }
                
                for(int i = 0; i < m_h264Param.pic_hdr_count; ++i)
                {
                    // out pps
                    int nSize = m_h264Param.pp_pic_hdr[i]->size ;
                    unsigned char* pPpsBuf = (unsigned char*)MediaLibrary::AllocBuffer(nSize);
                    memcpy(pPpsBuf , m_h264Param.pp_pic_hdr[i]->data, m_h264Param.pp_pic_hdr[i]->size);
                    m_FrmCb(m_Context, pPpsBuf, nSize, 2);
                }
            }
            else
            {
                for(int i = 0; i < m_h264Param.seq_hdr_count; ++i)
                {
                    // out sps
                    int nSize = m_h264Param.pp_seq_hdr[i]->size + sizeof(FrameHeader);
                    unsigned char* pSpsBuf = (unsigned char*)MediaLibrary::AllocBuffer(nSize);
                    memcpy(pSpsBuf, &FrameHeader, sizeof(FrameHeader));
                    memcpy(pSpsBuf + sizeof(FrameHeader), m_h264Param.pp_seq_hdr[i]->data, m_h264Param.pp_seq_hdr[i]->size);
                    m_FrmCb(m_Context, pSpsBuf, nSize, 1);
                }

                for(int i = 0; i < m_h264Param.pic_hdr_count; ++i)
                {
                    // out pps
                    int nSize = m_h264Param.pp_pic_hdr[i]->size + sizeof(FrameHeader);
                    unsigned char* pPpsBuf = (unsigned char*)MediaLibrary::AllocBuffer(nSize);
                    memcpy(pPpsBuf, &FrameHeader, sizeof(FrameHeader));
                    memcpy(pPpsBuf + sizeof(FrameHeader), m_h264Param.pp_pic_hdr[i]->data, m_h264Param.pp_pic_hdr[i]->size);
                    m_FrmCb(m_Context, pPpsBuf, nSize, 2);
                }
            }

            m_bFirstFrame = false;
        }
	
		m_nFrmCount ++;
		m_FrmCb(m_Context, m_FrameContext.pBuf, m_FrameContext.nFrameSize, 0);
       	m_FrameContext.pBuf = NULL;
		m_FrameContext.nFrameSize = -1;
		m_FrameContext.nBufPos = 0;
	}
    else
    {
        if(m_FrameContext.pBuf)
        {
            MediaLibrary::FreeBuffer(m_FrameContext.pBuf);
            m_FrameContext.pBuf = NULL;
		    m_FrameContext.nFrameSize  = -1;
			m_FrameContext.nBufPos = 0;
       }
    }
    
   return  ResetFrameContext();
}

int CMp4Parse::ResetFrameContext()
{
	if(m_pBuf->DataLength() < 4)
		return -1;

    unsigned char NaluSizeBuf[16];
	m_pBuf->PullData(NaluSizeBuf, m_nNaluSize);

	int nNalSize = 0;
	for (int j = 0; j < m_nNaluSize; j++) 
	{
		nNalSize |= NaluSizeBuf[j];
		if (j + 1 < m_nNaluSize)
			nNalSize <<= 8;
	}

	unsigned char* pH264Buf = NULL;
    if(m_NalHeadType == 1)
    {
        pH264Buf = (unsigned char*)MediaLibrary::AllocBuffer(nNalSize + sizeof(FrameHeader));
        memcpy(pH264Buf, &NaluSizeBuf, m_nNaluSize);
        m_FrameContext.nFrameSize = nNalSize + m_nNaluSize;
        m_FrameContext.nBufPos    = m_nNaluSize;
    }
    else
    {
        pH264Buf = (unsigned char*)MediaLibrary::AllocBuffer(nNalSize + sizeof(FrameHeader));
        memcpy(pH264Buf, &FrameHeader, sizeof(FrameHeader));
        m_FrameContext.nFrameSize = nNalSize + sizeof(FrameHeader);
        m_FrameContext.nBufPos    = 4;
    }
	m_FrameContext.pBuf       = pH264Buf;

	return 0;
}


//---------------------------------------------------------------------------

CH264ParamParse::CH264ParamParse()
{
	m_pBuf     = new CircleBuffer("264p");
	memset(m_level, 0, sizeof(m_level));
	memset(&m_h264Param, 0 , sizeof(m_h264Param));
	m_nRemainData = 0;
	m_bStsdOk = false;
	m_bStsdTagSize = 0;
	m_nStsdcount   = 0;
	m_bAvcCOk      = false;
}

CH264ParamParse::~CH264ParamParse()
{
	if(m_pBuf)
	{
		delete m_pBuf;
		m_pBuf = NULL;
	}


	if(m_h264Param.seq_hdr_count > 0)
	{
		for(int i = 0; i< m_h264Param.seq_hdr_count; ++i)
		{
			MediaLibrary::FreeBuffer(m_h264Param.pp_seq_hdr[i]);
		}

		MediaLibrary::FreeBuffer(m_h264Param.pp_seq_hdr);
	}
	if(m_h264Param.pic_hdr_count > 0)
	{
		for(int i = 0; i< m_h264Param.pic_hdr_count; ++i)
		{
			MediaLibrary::FreeBuffer(m_h264Param.pp_pic_hdr[i]);
		}

		MediaLibrary::FreeBuffer(m_h264Param.pp_pic_hdr);
	}
}

int  CH264ParamParse::Parse(const char* pData, int nDataLen)
{
	m_pBuf->PushData((void*)pData, nDataLen);
	return ParseData();
}

int  CH264ParamParse::GetH264Param(H264Param** ppParam)
{
	*ppParam = &m_h264Param;

	if(m_h264Param.pic_hdr_count > 0 && m_h264Param.seq_hdr_count > 0)
		return 0;

	return -1;
}

int CH264ParamParse::ParseData()
{
	m_nRemainData = ReadContent(m_pBuf, m_nRemainData);
	if( m_nRemainData  > 0)
		return -1;

	ParseOtherBox();
	ParseStsdBox();

	if(m_bAvcCOk)
		return 0;

	return -1;
}

int  CH264ParamParse::ParseOtherBox()
{
	while(!m_bStsdOk)
	{
		unsigned int nTag;
		int nTagSize = mp4_Box_parse(m_pBuf, &nTag);
		if(nTagSize < 0)
			return -1;

		print_fourcc(nTag, m_level);
		LOGE("TagSize %d", nTagSize);

		if(nTag == 0x6d6f6f76)       //'moov'
		{		
			strcat(m_level, "_");
		}
		else if(nTag == 0x7472616b) // 'trak'
		{
			strcat(m_level, "_");
		}
		else if(nTag == 0x6d646961) // 'mdia'
		{
			strcat(m_level, "_");
		}
		else if(nTag == 0x6d696e66) // 'minf'
		{
			strcat(m_level, "_");
		}
		else if(nTag == 0x7374626c) // 'stbl'
		{
			strcat(m_level, "_");
		}
		else if(nTag == 0x73747364) // 'stsd'
		{
			m_bStsdOk = true;
			m_bStsdTagSize = nTagSize - 8;
			strcat(m_level, "_");
			break;
		}
		else
		{
			m_nRemainData = ReadContent(m_pBuf, nTagSize - 8);
			if(m_pBuf->DataLength() <= 0)
				break;
		}
	}
	return 0;
}

int  CH264ParamParse::ParseStsdBox()
{
	if(!m_bStsdOk)
		return 0;

	if(m_pBuf->DataLength() < m_bStsdTagSize)
		return -1;

	unsigned int version_flag = 0;
	m_pBuf->PullData(&version_flag, 4);
	version_flag = swap32(version_flag);

	m_pBuf->PullData(&m_nStsdcount, 4);
	int nCount = swap32(m_nStsdcount);

	for (int i = 0; i < nCount; i++) 
	{
		unsigned int nTag;
		int nTagSize = mp4_Box_parse(m_pBuf, &nTag);
		if(nTagSize < 0)
			return -1;

		print_fourcc(nTag, m_level);

		if(nTag == 0x61766331)       //'avc1'
		{	
			nTagSize -= 8;
			ParseAvc1Box(m_pBuf, nTagSize);
			break;
		}
		else
		{
			ReadContent(m_pBuf, nTagSize - 8);
			if(m_pBuf->DataLength() <= 0)
				break;
		}
	}

	return 0;
}

int CH264ParamParse::ParseAvc1Box(CircleBuffer* pBuf, int& nBoxSize)
{
	visual_sample_entry_read(pBuf, nBoxSize);
	while (nBoxSize > 0) 
	{
		unsigned int nTag;
		int nTagSize = mp4_Box_parse(pBuf, &nTag);
		if(nTagSize < 0)
			return -1;

		print_fourcc(nTag, m_level);
		if(nTag == 0x61766343)       //'avc1'
		{	
			nTagSize -= 8;
			ParseAvcCBox(pBuf, nTagSize);
			break;
		}
		else
		{
			ReadContent(m_pBuf, nTagSize - 8);
			if(m_pBuf->DataLength() <= 0)
				break;
		}
	}
	return 0;
}

int CH264ParamParse::ParseAvcCBox(CircleBuffer* pBuf, int& nBoxSize)
{
	pBuf->PullData(&m_h264Param.configuration_version, 1);
	pBuf->PullData(&m_h264Param.avc_profile_indication, 1);
	pBuf->PullData(&m_h264Param.profile_compatibility, 1);
	pBuf->PullData(&m_h264Param.avc_level_indication, 1);

	unsigned char temp;
	pBuf->PullData(&temp, 1);
	// reserved bit(6)
	m_h264Param.nal_unit_size = 1 + (temp & 0x3);


	pBuf->PullData(&temp, 1);
	// reserved bit(3) 
	m_h264Param.seq_hdr_count = (temp & 0x1f); //seq_hdr
	m_h264Param.pp_seq_hdr = (parameter_sets **) MediaLibrary::AllocBuffer(m_h264Param.seq_hdr_count * sizeof(parameter_sets *));

	for (int i = 0; i < m_h264Param.seq_hdr_count; i++) 
	{
		parameter_sets *sets = (parameter_sets *) MediaLibrary::AllocBuffer(sizeof(struct parameter_sets));
		memset(sets, 0, sizeof(parameter_sets));

		pBuf->PullData(&sets->size, 2);
		sets->size = swap16(sets->size);

		sets->data = (unsigned char *) MediaLibrary::AllocBuffer(sizeof(unsigned char) * sets->size);
		pBuf->PullData(sets->data, sets->size);

		m_h264Param.pp_seq_hdr[i] = sets;
	}

	pBuf->PullData(&m_h264Param.pic_hdr_count, 1); //pic_hdr

	m_h264Param.pp_pic_hdr = (parameter_sets **) MediaLibrary::AllocBuffer(m_h264Param.pic_hdr_count * sizeof(parameter_sets *));

	for (int i = 0; i < m_h264Param.pic_hdr_count; i++) {
		parameter_sets *sets;

		sets = (parameter_sets *) MediaLibrary::AllocBuffer(sizeof(parameter_sets));

		pBuf->PullData(&sets->size, 2);
		sets->size = swap16(sets->size);

		sets->data = (unsigned char *) MediaLibrary::AllocBuffer(sizeof(unsigned char) * sets->size);
		pBuf->PullData(sets->data, sets->size);

		m_h264Param.pp_pic_hdr[i] = sets;
	}

	m_bAvcCOk = true;
	return 0;
}

int CH264ParamParse::visual_sample_entry_read(CircleBuffer* pBuf, int& nBoxSize)
{
	char visual_buf[80];
	pBuf->PullData((void*)&visual_buf[0], 78);
	nBoxSize -= 78;

	/* mp4_bs_read_data(bs, reserved, 6);
	data_reference_index = mp4_bs_read_u16(bs);
	pre_defined          = mp4_bs_read_u16(bs);
	reserved1            = mp4_bs_read_u16(bs);
	for (i = 0; i < 3; i++)
	pre_defined1[i] = mp4_bs_read_u32(bs);
	width  = mp4_bs_read_u16(bs);
	height = mp4_bs_read_u16(bs);
	horiz_res = mp4_bs_read_u32(bs);
	vert_res  = mp4_bs_read_u32(bs);
	reserved2 = mp4_bs_read_u32(bs);
	frames_count = mp4_bs_read_u16(bs);
	mp4_bs_read_data(bs, box->compressor_name, 32);
	compressor_name[32] = 0;
	bit_depth = mp4_bs_read_u16(bs);
	pre_defined2 = mp4_bs_read_u16(bs);
	*/

	return 0;
}
