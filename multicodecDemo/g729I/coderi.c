/*   ITU-T G.729 Annex I Software Package Release 2 (November 2006) */
/*
   ITU-T G.729 Annex I  - Reference C code for fixed point
                         implementation of G.729 Annex I
   Version 1.2    Last modified: October 2006 
*/
/*
----------------------------------------------------------------------
                    COPYRIGHT NOTICE
----------------------------------------------------------------------
   ITU-T G.729 Annex I fixed point ANSI C source code
   Copyright (C) 1999, AT&T, France Telecom, NTT, University of
   Sherbrooke, Conexant, Ericsson. All rights reserved.
----------------------------------------------------------------------
*/

/*
 File : CODERI.C
 */
/* from codere.c G.729 Annex E Version 1.2  Last modified: May 1998 */
/* from coderd.c G.729 Annex D Version 1.2  Last modified: May 1998 */
/* from coder.c G.729 Annex B Version 1.3  Last modified: August 1997 */
/* from coder.c G.729 Version 3.3  */

/*--------------------------------------------------------------------------------------*
 * Main program of the ITU-T G.729 annex I   11.8/8/6.4 kbit/s encoder.
 *
 *    Usage : coderi speech_file  bitstream_file  DTX_flag [bit_rate or file_bit_rate]
 *--------------------------------------------------------------------------------------*/

/* ------------------------------------------------------------------------ */
/*                            MAIN PROGRAM                                  */
/* ------------------------------------------------------------------------ */

/*
 8K采样率 一帧80bit 10ms
 */

#include <stdio.h>
#include <stdlib.h>

#include "typedef.h"
#include "basic_op.h"
#include "ld8k.h"
#include "ld8cp.h"
#include "dtx.h"
#include "octet.h"

#include <string.h> /* memset */
#include <unistd.h> /* close */
#include "SelfDefineQua.h"


void divideIntoSideStream(Word16 prm[2][PRM_SIZE_D + 2], Word16 prm_odd[2][PRM_SIZE_D + 2], Word16 prm_even[2][PRM_SIZE_D + 2]);
extern void syncTwoStream(Word16 prm[2][PRM_SIZE_D + 2], Word16 prm_odd[2][PRM_SIZE_D + 2], Word16 prm_even[2][PRM_SIZE_D + 2], int lostCount);

//all 60bit
Word16 multi_bitsno[PRM_SIZE*2] = {
    8, /* MA + 1st stage */
    8, /* 2nd stage */
    8, 0, 13, 4, 7, /* first subframe  */
    5, 0, 0, 7,
    //
    8, /* MA + 1st stage */
    8, /* 2nd stage */
    8, 0, 13, 4, 7, /* first subframe  */
    5, 0, 0, 7 }; /* second subframe */

void multi_bit2byte(Word16 para, int bitlen, unsigned char * bits, int bitpos);
Word16 multi_byte2bit(int bitlen, unsigned char * bits, int bitpos);

void multi_prm2bits_ld8c(Word16 *para, unsigned char *bits)
{
    int i;
    int bitpos = 0;
    for (i = 0; i<PRM_SIZE*2; i++)
    {
        multi_bit2byte(*para++, multi_bitsno[i], bits, bitpos);
        bitpos += multi_bitsno[i];
    }
    
}

void multi_bit2byte(Word16 para, int bitlen, unsigned char * bits, int bitpos)
{
    int i;
    int bit = 0;
    unsigned char newbyte = 0;
    
    unsigned char *p = bits + (bitpos / 8);
    for (i = 0; i<bitlen; i++)
    {
        bit = (para >> (bitlen - i - 1)) & 0x01;
        newbyte = (1 << (7 - bitpos % 8));
        if (bit == 1)
            *p |= newbyte;
        else
            *p &= ~newbyte;
        bitpos++;
        if (bitpos % 8 == 0)
            p++;
    }
}

void multi_bits2prm_ld8c(unsigned char *bits, Word16 *para)
{
    int i;
    int bitpos = 0;
    for (i = 0; i<PRM_SIZE*2; i++)
    {
        *para++ = multi_byte2bit(multi_bitsno[i], bits, bitpos);
        bitpos += multi_bitsno[i];
    }
    
}

Word16 multi_byte2bit(int bitlen, unsigned char * bits, int bitpos)
{
    int i;
    int bit = 0;
    Word16 newbyte = 0;
    Word16 value = 0;
    
    unsigned char *p = bits + (bitpos / 8);
    for (i = 0; i< bitlen; i++)
    {
        bit = (*p >> (7 - bitpos % 8)) & 0x01;
        if (bit == 1)
        {
            newbyte = (1 << (bitlen - i - 1));
            value |= newbyte;
        }
        bitpos++;
        if (bitpos % 8 == 0)
            p++;
    }
    return value;
}

void intToBigEndian(uint8_t* output, int data)
{
    uint8_t * bytes = (uint8_t*)&data;
    
    output[0] = bytes[3];
    output[1] = bytes[2];
    output[2] = bytes[1];
    output[3] = bytes[0];
}



int getIntFromBigEndian(uint8_t *data)
{
    int data0 = data[3];
    int data1 = data[2];
    int data2 = data[1];
    int data3 = data[0];
    return (data0 << 0) | (data1 << 8) | (data2 << 16) | (data3 << 24);
}


int encoder_main(int argc, const char *argv[] )
{
    FILE *f_speech;               /* File of speech data                   */
    FILE *f_serial;               /* File of serial bits for transmission  */
    FILE  *f_rate;
    Word16 rate;
    
    extern Word16 *new_speech;     /* Pointer to new speech data            */
    
    Word16 prm[PRM_SIZE_D+2];          /* Analysis parameters.                  */
    unsigned char serial[SERIAL_SIZE_E];    /* Output bitstream buffer               */
    
    Word16 i, frame;               /* frame counter */
    Word32 count_frame;
    
    Word16 dtx_enable;
    
    if ( (f_speech = fopen(argv[1], "rb")) == NULL) {
        printf("%s - Error opening file  %s !!\n", argv[0], argv[1]);
        exit(0);
    }
    
    if ( (f_serial = fopen(argv[2], "wb")) == NULL) {
        printf("%s - Error opening file  %s !!\n", argv[0], argv[2]);
        exit(0);
    }
    
    dtx_enable = (Word16)atoi(argv[3]);
    if (dtx_enable == 1)
        printf(" DTX enabled\n");
    else
        printf(" DTX disabled\n");
    f_rate = NULL; /* to avoid  visual warning */
    rate = G729;  /* to avoid  visual warning */
    
    Init_Pre_Process();
    Init_Coder_ld8c(dtx_enable);
    
    for(i=0; i<PRM_SIZE_D; i++) prm[i] = (Word16)0;
    
    /* Loop for each "L_FRAME" speech data. */
    frame=0;
    count_frame = 0L;
    
    while( fread(new_speech, sizeof(Word16), L_FRAME, f_speech) == L_FRAME) {
        if (frame == 32767) frame = 256;
        else frame++;
        
        Pre_Process(new_speech, L_FRAME);
        
        count_frame++;
        printf(" Frame: %d\r", count_frame);
        Coder_ld8c(prm, frame, dtx_enable, rate);
        
        prm2bits_ld8c( prm+1, serial);
        
        if (fwrite(serial, sizeof(char), 10, f_serial) != (size_t)10)
            printf("Write Error for frame %d\n", count_frame);
        
    }
    printf("\n");
    printf("%d frames processed\n", count_frame);
    
    if(f_serial) fclose(f_serial);
    if(f_speech) fclose(f_speech);
    if(f_rate) fclose(f_rate);

    return(0);
    
} /* end of main() */



static Word16 rate = G729;
extern Word16 *new_speech;     /* Pointer to new speech data            */
static Word16 frame;               /* frame counter */
static Word32 count_frame;
static Word16 dtx_enable = 0;

static FILE *f_serial;               /* File of serial bits for transmission  */

void initG729Codec(void){
    Init_Pre_Process();
    Init_Coder_ld8c(0);
    
    /* Loop for each "L_FRAME" speech data. */
    frame=0;
    count_frame = 0L;
    
    char buffer[256];
    strcpy(buffer,getenv("TMPDIR"));
    strcat(buffer,"encodeMulti");
    if ( (f_serial = fopen(buffer, "wb")) == NULL) {
        printf("- Error opening file liveencode !!\n");
        exit(0);
    }
}

/// speechData的长度必须是80
void encodeAudioData(short speechData[160], unsigned char serial[2][19]){
    //printf("\nen %d",speechData[0]);
    
    Word16 prm[2][PRM_SIZE_D+2];          /* Analysis parameters.                  */
    
    for (int findex = 0; findex < 2; findex++) {
        for (int i = 0; i < L_FRAME; i++) {
            new_speech[i] = speechData[i + findex * 80];
        }
        
        Pre_Process(new_speech, L_FRAME);
        count_frame++;
        Coder_ld8c(prm[findex], frame, dtx_enable, rate);
        
//        prm2bits_ld8c( &prm[findex][1], serial[findex]);
    }
    
    
    Word16 prm_odd[2][PRM_SIZE_D + 2];
    Word16 prm_even[2][PRM_SIZE_D + 2];
    divideIntoSideStream(prm, prm_odd, prm_even);
    
    Word16 multi_prm[2][PRM_SIZE * 2];
    
     //2个帧交叉多描述的帧
    for (int i0 = 0; i0 < PRM_SIZE; i0++)
    {
        multi_prm[0][i0] = prm_odd[0][i0 + 1];
    }
    for (int i1 = PRM_SIZE; i1 < PRM_SIZE * 2; i1++)
    {
        multi_prm[0][i1] = prm_odd[1][i1 - PRM_SIZE + 1];
    }
    
    for (int i0 = 0; i0 < PRM_SIZE; i0++)
    {
        multi_prm[1][i0] = prm_even[0][i0 + 1];
    }
    for (int i1 = PRM_SIZE; i1 < PRM_SIZE * 2; i1++)
    {
        multi_prm[1][i1] = prm_even[1][i1 - PRM_SIZE + 1];
    }

    
    intToBigEndian(&serial[0][0], count_frame-2);
    multi_prm2bits_ld8c(multi_prm[0], &serial[0][4]);
    intToBigEndian(&serial[1][0], count_frame-1);
    multi_prm2bits_ld8c(multi_prm[1], &serial[1][4]);

    int writeFile = 0;
    if (writeFile) {
        if (fwrite(serial[0], sizeof(char), 19, f_serial) != (size_t)19)
            printf("Write Error for frame %d\n", count_frame);
        if (fwrite(serial[1], sizeof(char), 19, f_serial) != (size_t)19)
            printf("2Write Error for frame %d\n", count_frame);
    }
}


void divideIntoSideStream(Word16 prm[2][PRM_SIZE_D + 2], Word16 prm_odd[2][PRM_SIZE_D + 2], Word16 prm_even[2][PRM_SIZE_D + 2]){
    
    //i表示帧的索引号
    for (int i = 0; i < 2; i++){
        ///LSP
        int sub1 = -1;
        int sub2 = -1;
        /*
         Word16 L1 = prm[i][1] & 0x007f;
         //sub1 5bit, sub2 6bit.
         LSPL1DividedIntoTwo(L1, &sub1, &sub2);
         Word16 modIndex = (prm[i][1] & 0x0080) >> 7;
         prm_odd[i][1] = shl(modIndex, 5) | sub1;
         prm_even[i][1] = shl(modIndex, 6) | sub2;
         //printf("\n-:%d", modIndex);
         */
        //L1 7bit x 2
        prm_odd[i][1] = prm[i][1];
        prm_even[i][1] = prm[i][1];
        //L3 5bit x 2
        int L3 = (prm[i][2] >> NC1_B) & 0x001F;
        LSPL3DividedIntoTwo(L3, &sub1, &sub2);
        prm_odd[i][2] = L3;
        prm_even[i][2] = L3;
        //L2 sub1 3bit + sub2 2bit  为了方便传输，L2被分为3bit + 3bit。
        int L2 = prm[i][2] & 0x001F;
        LSPL2DividedIntoTwo(L2, &sub1, &sub2);
        prm_odd[i][2] += sub1 << 5;
        prm_even[i][2] += sub2 << 5;
        //printf("\n-:%d %d %d", sub1, sub2, L3);
        
        
        
        /// Adaptive-codebook index ( pitch )   14bit x 2
        int p1 = prm[i][3];
//        int p0 = prm[i][4];
        int p2 = prm[i][8];
        prm_odd[i][3] = p1;
        prm_odd[i][4] = 0; //这个校验位可以省
        prm_odd[i][8] = p2;
        prm_even[i][3] = p1;
        prm_even[i][4] = 0; //这个校验位可以省
        prm_even[i][8] = p2;
        
        
        
        ///fix codebookIndex  34bit
        Word16 posn[2][4];
        Word16 sn[2][4];
        Word16 tmp;
        Word16 index[2];
        // 13bit subframe1 4 pulse
        index[0] = prm[i][5];
        // 13bit subframe2 4 pulse
        index[1] = prm[i][9];
        Word16 sign[2];
        sign[0] = prm[i][6];
        sign[1] = prm[i][10];
        for (char sf = 0; sf < 2; sf++) {
            Word16 i, j;
            
            /* Decode the positions */
            tmp = index[sf];
            i = tmp & (Word16)7;
            posn[sf][0] = i;
            
            tmp = shr(tmp, 3);
            i = tmp & (Word16)7;
            posn[sf][1] = i;
            
            tmp = shr(tmp, 3);
            i = tmp & (Word16)7;
            posn[sf][2] = i;
            
            tmp = shr(tmp, 3);
            posn[sf][3] = tmp;
            
            /* Decode sign */
            tmp = sign[sf];
            for (j = 0; j < 4; j++) {
                i = tmp & (Word16)1;
                
                if (i != 0)
                    sn[sf][j] = 32767;
                else
                    sn[sf][j] = -32768;
                
                tmp = shr(tmp, 1);
            }
            //printf("\n %d %d %d %d", posn[sf][0], posn[sf][1], posn[sf][2], posn[sf][3]);
        }
        
        //exchange
        tmp = posn[0][0];
        posn[0][0] = posn[1][0];
        posn[1][0] = tmp;
        tmp = sn[0][0];
        sn[0][0] = sn[1][0];
        sn[1][0] = tmp;
        tmp = posn[0][3];
        posn[0][3] = posn[1][3];
        posn[1][3] = tmp;
        tmp = sn[0][3];
        sn[0][3] = sn[1][3];
        sn[1][3] = tmp;
        
        //recombine
        for (Word16 sf = 0; sf < 2; sf++)
        {
            Word16 i;
            /* find codebook index;  17-bit address */
            i = 0;
            if (sn[sf][0] > 0) i = add(i, 1);
            if (sn[sf][1] > 0)  i = add(i, 2);
            if (sn[sf][2] > 0)  i = add(i, 4);
            if (sn[sf][3] > 0)  i = add(i, 8);
            sign[sf] = i;
            
            i = add(posn[sf][0], shl(posn[sf][1], 3));
            i = add(i, shl(posn[sf][2], 6));
            i = add(i, shl(posn[sf][3], 9));
            index[sf] = i;
        }
        prm_odd[i][5] = index[0];
        prm_odd[i][6] = sign[0];
        prm_odd[i][9] = 0;
        prm_odd[i][10] = 0;
        
        prm_even[i][5] = index[1];
        prm_even[i][6] = sign[1];
        prm_even[i][9] = 0;
        prm_even[i][10] = 0;
        
        
        
        
        
        ///gain G1 7bit, G2 7bit。 14bit x 2
        Word16 G1 = prm[i][7];
        Word16 G2 = prm[i][11];
        prm_odd[i][7] = G1;
        prm_odd[i][11] = G2;
        prm_even[i][7] = G1;
        prm_even[i][11] = G2;
        
        //allbit  (gain)13x2 + (fixed)34 + (pitch)14x2 + (L3)5x2 + (L1)8x2 + (L2)5 = 119bit。
        //stream1: 14+17+14+5+7+2 =  59bit; stream1: 14+17+14+5+7+3 = 60bit;
        //80bit + （冗余）39bit. 50%.
        //优化方案。Gain可以把子帧只传1路，省14bit，分数会比现在掉0.1~0.2.冗余25bit，30%.
    }
}
