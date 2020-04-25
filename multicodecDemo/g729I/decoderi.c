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
 File : DECODERI.C
 */
/* from decodere.c G.729 Annex E Version 1.2  Last modified: May 1998 */
/* from decoderd.c G.729 Annex D Version 1.2  Last modified: May 1998 */
/* from decoder.c G.729 Annex B Version 1.3  Last modified: August 1997 */
/* from decoder.c G.729 Version 3.3  */

/*--------------------------------------------------------------------------------------*
 * Main program of the ITU-T G.729 annex I   11.8/8/6.4 kbit/s encoder.
 *
 *    Usage : decoderi bitstream_file  output_file
 *--------------------------------------------------------------------------------------*/

/* ------------------------------------------------------------------------ */
/*                            MAIN PROGRAM                                  */
/* ------------------------------------------------------------------------ */

#include <stdlib.h>
#include <stdio.h>

#include "typedef.h"
#include "basic_op.h"
#include "ld8k.h"
#include "ld8cp.h"
#include "dtx.h"
#include "octet.h"
#include "../utils/dataserialize.h"
#include "SelfDefineQua.h"

#include <string.h> /* memset */
#include <unistd.h> /* close */

#define POSTPROC

#define SKP_ADD32_ovflw(a, b)               ((int32_t)((uint32_t)(a) + (uint32_t)(b)))
#define SKP_MLA_ovflw(a32, b32, c32)        SKP_ADD32_ovflw((a32), (uint32_t)(b32) * (uint32_t)(c32))
#define SKP_RAND(seed)                   (SKP_MLA_ovflw(907633515, (seed), 196314165))


int GlobalLSPL3[32] = {0};
int GlobalLSPL2[32] = {0};
int GlobalLSPL1[128] = {0};

extern void multi_bits2prm_ld8c(unsigned char *bits, Word16 *para);
void syncTwoStream(Word16 prm[2][PRM_SIZE_D + 2], Word16 prm_odd[2][PRM_SIZE_D + 2], Word16 prm_even[2][PRM_SIZE_D + 2], int lostCount);

static int shouldDiscard(float rate, uint32_t *randseed){
    *randseed = SKP_RAND(*randseed);
//    int randomValue = rand();
    
    int intRate = rate * 1000;
    
    int randValueNormal = *randseed%1000;
    if (randValueNormal < intRate) {
        return 1;
    }
    return 0;
}

void saveToFile(Word16 *m_parm){
    // L1
    int L1 = m_parm[1] & 0x7F;
    
    // L2
    int L2 = m_parm[2] & 0x001F;
    
    // L3
    int L3 = m_parm[2] >> NC1_B & 0x001F;
    
    openFileWithTag(FILEWRITETYPELSPL1);
    openFileWithTag(FILEWRITETYPELSPL2);
    openFileWithTag(FILEWRITETYPELSPL3);
    
    writeIntValueToFile(L1, FILEWRITETYPELSPL1);
    writeCharDataToFile("\n", 1, FILEWRITETYPELSPL1);
    writeIntValueToFile(L2, FILEWRITETYPELSPL2);
    writeCharDataToFile("\n", 1, FILEWRITETYPELSPL2);
    writeIntValueToFile(L3, FILEWRITETYPELSPL3);
    writeCharDataToFile("\n", 1, FILEWRITETYPELSPL3);
    
    GlobalLSPL1[L1]++;
    GlobalLSPL2[L2]++;
    GlobalLSPL3[L3]++;
}

void randomDiscardParam(Word16 *m_parm){
    static int L1get = 0;
    static int L1getdis = 0;
    
    static int L2get = 0;
    static int L2getdis = 0;
    
    static int L3get = 0;
    static int L3getdis = 0;
    
    //LSP
    static uint32_t LSPSeed = 0;
    if (shouldDiscard(0.0,&LSPSeed))
    {
#if 0
        m_parm[1] = 0;
        m_parm[2] = 0;
#else
        int b, p;
        
        
        // L1
        int openL1Loss = 1;
        if (openL1Loss)
        {
            int useTable = 1;
            if (useTable)
            {
                // L1
                int L1 = m_parm[1] & 0x7F;
                int sub1 = -1;
                int sub2 = -1;
                LSPL1DividedIntoTwo(L1, &sub1, &sub2);
                int rebuildL1 = LSPL1GetCombineValue(sub1, -1);
                if (rebuildL1 == L1) {
                    L1get++;
                    printf("\n\n L1 get value:%d count:%d", L1, L1get);
                }
                else{
                    printf("\n\n L1 didn't get value:%d count:%d", L1, L1getdis);
                    L1getdis++;
                }
                m_parm[1] = m_parm[1] & 0xFF80;
                m_parm[1] = m_parm[1] | rebuildL1;
            }else{
                b = rand() % (NC0_B);
                p = rand() % 5;
                if (p != 0)
                {
                    b = 1 << (b);
                    m_parm[1] = m_parm[1] ^ b;
                }
            }
        }
        
        // L2
        int openL2Loss = 1;
        if (openL2Loss)
        {
            int useTable = 1;
            if (useTable)
            {
                int L2 = m_parm[2] & 0x001F;
                int sub1 = -1;
                int sub2 = -1;
                LSPL2DividedIntoTwo(L2, &sub1, &sub2);
                
                int rebuildL2 = LSPL2GetCombineValue(sub1, -1);
                if (rebuildL2 == L2) {
                    L2get++;
                    printf("\n\n L2 get value:%d", L2get);
                }
                else{
                    L2getdis++;
                    printf("\n\n L2 didn't get value:%d", L2getdis);
                }
                m_parm[2] = m_parm[2] & 0xFFe0;
                m_parm[2] = m_parm[2] | rebuildL2;
            }
            else{
                b = rand() % (NC1_B);
                p = rand() % 4;
                if (p != 0)
                {
                    b = 1 << (b);
                    m_parm[2] = m_parm[2] ^ b;
                }
            }
        }
        
        // L3
        int openL3Loss = 1;
        if (openL3Loss)
        {
            int useTable = 1;
            if (useTable)
            {
                int L3 = m_parm[2] >> NC1_B & 0x001F;
                int sub1 = -1;
                int sub2 = -1;
                LSPL3DividedIntoTwo(L3, &sub1, &sub2);
                
                int rebuildL3 = LSPL3GetCombineValue(sub1, -1);
                if (rebuildL3 == L3) {
                    L3get++;
                    printf("\n\n L3 get value:%d", L3get);
                }
                else{
                    L3getdis++;
                    printf("\n\n L3 didn't get value:%d", L3getdis);
                }
                m_parm[2] = m_parm[2] & 0x001F;
                m_parm[2] = m_parm[2] | (rebuildL3 << NC1_B);
            }else{
                b = rand() % (NC1_B);
                p = rand() % 4;
                if (p != 0)
                {
                    b = 1 << (b + NC1_B);
                    m_parm[2] = m_parm[2] ^ b;
                }
            }
        }
#endif
    }
    
    
    // Adaptive-codebook delay
    static uint32_t delaySeed = 0;
    if (shouldDiscard(0.0,&delaySeed))
    {
        m_parm[3] = 0;
        m_parm[8] = 0;
    }
    
    // gains
    static uint32_t gainsSeed = 0;
    if (shouldDiscard(0.0,&gainsSeed))
    {
        m_parm[7] = 0; //Fitst frame
        m_parm[11] = 0; //second frame
    }
    
    // codebook
    static uint32_t codebookSeed = 0;
    if (shouldDiscard(0.0,&codebookSeed))
    {
#if 1
        //first subframe
        m_parm[5] = 0; // Fixed-codebook index
        m_parm[6] = 0; // Fixed-codebook sign
        //second subframe
        m_parm[9] = 0;
        m_parm[10] = 0;
#else
        m_parm[5] = rand() % 0x2000;
        m_parm[6] = rand() % 16;
        m_parm[9] = rand() % 0x2000;
        m_parm[10] = rand() % 16;
#endif
    }
    
    // second frame set to zero
    /*
     for (int i = PRM_SIZE - 4; i < PRM_SIZE; i++) {
     m_parm[i] = 0;
     }*/
}

/*-----------------------------------------------------------------*
 *            Main decoder routine                                 *
 *-----------------------------------------------------------------*/

int decoder_main(int argc, const char *argv[] )
{
    Word16 Vad;
    Word16  synth_buf[L_ANA_BWD], *synth; /* Synthesis                   */
    Word16  parm[PRM_SIZE_E+3];             /* Synthesis parameters        */
    unsigned char  serial[SERIAL_SIZE_E];            /* Serial stream               */
    Word16  Az_dec[M_BWDP1*2], *ptr_Az;       /* Decoded Az for post-filter  */
    Word16  T0_first;                         /* Pitch lag in 1st subframe   */
    Word16  pst_out[L_FRAME];                 /* Postfilter output           */
    
    Word16  voicing;                          /* voicing from previous frame */
    Word16  sf_voic;                          /* voicing for subframe        */
    
    Word16  i;
    Word32 frame;
    Word16  ga1_post, ga2_post, ga_harm;
    Word16  long_h_st, m_pst;
    Word16  serial_size;
    Word16  bwd_dominant;
    FILE    *f_syn, *f_serial;
    Word16 discardNum = 0;
    
    /* Open file for synthesis and packed serial stream */
    if( (f_serial = fopen(argv[1],"rb") ) == NULL ) {
        printf("%s - Error opening file  %s !!\n", argv[0], argv[1]);
        exit(0);
    }
    if( (f_syn = fopen(argv[2], "wb") ) == NULL ) {
        printf("%s - Error opening file  %s !!\n", argv[0], argv[2]);
        exit(0);
    }
    
    /*-----------------------------------------------------------------*
    *           Initialization of decoder                             *
    *-----------------------------------------------------------------*/
    for (i=0; i<L_ANA_BWD; i++) synth_buf[i] = 0;
    synth = synth_buf + MEM_SYN_BWD;
    
    Init_Decod_ld8c();
    Init_Post_Filter();
    Init_Post_Process();
    
    voicing = 60;

    ga1_post = GAMMA1_PST_E;
    ga2_post = GAMMA2_PST_E;
    ga_harm = GAMMA_HARM_E;
    /* for G.729b */
    Init_Dec_cng();
    
    frame = 0L;
    /*-----------------------------------------------------------------*
    *            Loop for each "L_FRAME" speech data                  *
    *-----------------------------------------------------------------*/
    serial_size = 10;
    while( fread(serial, sizeof(char), 10, f_serial) == 10) {
//        fread(&serial[2], sizeof(Word16), serial_size, f_serial);
        
        frame++;
//        printf(" Frame: %d\r", frame);
        bits2prm_ld8c(serial, parm+2);

        parm[5] = Check_Parity_Pitch(parm[4], parm[5]);
        parm[0] = 0;           /* No frame erasure */
        parm[1] = 3; //bitrate
        
        saveToFile(&parm[1]);
        randomDiscardParam(&parm[1]);
        
        /* ---------- */
        /*  Decoding  */
        /* ---------- */
        /* 丢帧补偿
        if (shouldDiscard(0.2)) {
            parm[0] = 0;
            discardNum++;
            printf("discard:%d \n",discardNum);
        }*/
        
        Decod_ld8c(parm, voicing, synth_buf, Az_dec, &T0_first, &bwd_dominant,
            &m_pst, &Vad);
        
        /* ---------- */
        /* Postfilter */
        /* ---------- */
        ptr_Az = Az_dec;
        
        /* Adaptive parameters for postfiltering */
        /* ------------------------------------- */
        long_h_st = LONG_H_ST;
        ga1_post = GAMMA1_PST;
        ga2_post = GAMMA2_PST;
        ga_harm = GAMMA_HARM;

        for(i=0; i<L_FRAME; i++) pst_out[i] = synth[i];
        
        voicing = 0;  /* XXX */
        for(i=0; i<L_FRAME; i+=L_SUBFR) {
            Poste(T0_first, &synth[i], ptr_Az, &pst_out[i], &sf_voic,
                ga1_post, ga2_post, ga_harm, long_h_st, m_pst, Vad);
            if (sf_voic != 0) voicing = sf_voic;
            ptr_Az += m_pst+1;
        }
        
        
        Post_Process(pst_out, L_FRAME);
        
        static uint32_t allFrameSeed = 0;
        if (shouldDiscard(0.0, &allFrameSeed)) {
            memset(pst_out,0,L_FRAME);
            discardNum++;
            printf("discard:%d \n",discardNum);
//            continue;
        }
        fwrite(pst_out, sizeof(Word16), L_FRAME, f_syn);
    }
    printf("\n");
    if(f_serial) fclose(f_serial);
    if(f_syn) fclose(f_syn);

    closeAllFileHandle();
    
    return(0);
}



static Word16 Vad;
static Word16  synth_buf[L_ANA_BWD], *synth; /* Synthesis                   */
static Word16  Az_dec[M_BWDP1*2], *ptr_Az;       /* Decoded Az for post-filter  */
static Word16  T0_first;                         /* Pitch lag in 1st subframe   */
static Word16  pst_out[L_FRAME];                 /* Postfilter output           */

static Word16  voicing;                          /* voicing from previous frame */
static Word16  sf_voic;                          /* voicing for subframe        */

static Word16  i;
static Word16  ga1_post, ga2_post, ga_harm;
static Word16  long_h_st, m_pst;
static Word16  bwd_dominant;
static FILE *f_serial;

void initG729Decoder(void){
    
    for (i=0; i<L_ANA_BWD; i++) synth_buf[i] = 0;
    synth = synth_buf + MEM_SYN_BWD;
    
    Init_Decod_ld8c();
    Init_Post_Filter();
    Init_Post_Process();
    
    voicing = 100;
    
    ga1_post = GAMMA1_PST_E;
    ga2_post = GAMMA2_PST_E;
    ga_harm = GAMMA_HARM_E;
    /* for G.729b */
    Init_Dec_cng();
    
    char buffer[256];
    strcpy(buffer,getenv("TMPDIR"));
    strcat(buffer,"decodeMulti");
    if ( (f_serial = fopen(buffer, "wb")) == NULL) {
        printf("- Error opening file liveencode !!\n");
        exit(0);
    }
}

void decodeG729Data(unsigned char serial[30], short outData[160] , int status){
    
    int writeFile = 0;
    if (writeFile) {
        if (fwrite(&serial[0], sizeof(char), 15, f_serial) != (size_t)15)
            printf("Write Error for frame\n");
        if (fwrite(&serial[15], sizeof(char), 15, f_serial) != (size_t)15)
            printf("2Write Error for frame\n");
    }
    
    Word16 prm[2][PRM_SIZE_D+2];          /* Analysis parameters.                  */
    Word16 prm_odd_de[2][PRM_SIZE_D + 2];
    Word16 prm_even_de[2][PRM_SIZE_D + 2];
    Word16 multi_prm_de[2][PRM_SIZE * 2];
    
    multi_bits2prm_ld8c(&serial[0], multi_prm_de[0]);
    multi_bits2prm_ld8c(&serial[15], multi_prm_de[1]);
    
     //2个帧交叉多描述的帧
    //2个帧交叉多描述的帧
    for (int i0 = 0; i0 < PRM_SIZE; i0++)
    {
        prm_odd_de[0][i0 + 1] = multi_prm_de[0][i0];
    }
    for (int i1 = PRM_SIZE; i1 < PRM_SIZE * 2; i1++)
    {
        prm_odd_de[1][i1 - PRM_SIZE + 1] = multi_prm_de[0][i1];
    }
    
    for (int i0 = 0; i0 < PRM_SIZE; i0++)
    {
        prm_even_de[0][i0 + 1] = multi_prm_de[1][i0];
    }
    for (int i1 = PRM_SIZE; i1 < PRM_SIZE * 2; i1++)
    {
        prm_even_de[1][i1 - PRM_SIZE + 1] = multi_prm_de[1][i1];
    }
    
    syncTwoStream(prm, prm_odd_de, prm_even_de, status);
    
    for (int j = 0; j < 2; j++) {
        Word16  parm[PRM_SIZE_E+3];             /* Synthesis parameters        */
        for (int i = 0; i < PRM_SIZE_D + 2; i++) {
            parm[i+2] = prm[j][i+1];
        }
        
        parm[5] = Check_Parity_Pitch(parm[4], parm[5]);
        
        if (status == 3) {
         	parm[0] = 1; //丢帧补偿处理
        }else{
            parm[0] = 0;           /* No frame erasure */
        }
        
        parm[1] = 3; //bitrate
        
        Decod_ld8c(parm, voicing, synth_buf, Az_dec, &T0_first, &bwd_dominant,
                   &m_pst, &Vad);
        
        /* ---------- */
        /* Postfilter */
        /* ---------- */
        ptr_Az = Az_dec;
        
        /* Adaptive parameters for postfiltering */
        /* ------------------------------------- */
        long_h_st = LONG_H_ST;
        ga1_post = GAMMA1_PST;
        ga2_post = GAMMA2_PST;
        ga_harm = GAMMA_HARM;
        
        for(i=0; i<L_FRAME; i++) pst_out[i] = synth[i];
        
        voicing = 0;  /* XXX */
        for(i=0; i<L_FRAME; i+=L_SUBFR) {
            Poste(T0_first, &synth[i], ptr_Az, &pst_out[i], &sf_voic,
                  ga1_post, ga2_post, ga_harm, long_h_st, m_pst, Vad);
            if (sf_voic != 0) voicing = sf_voic;
            ptr_Az += m_pst+1;
        }
        
        
        Post_Process(pst_out, L_FRAME);
        
        for (int i = 0; i < 80; i++) {
            outData[i+j*80] = pst_out[i];
        }
    }
}


void syncTwoStream(Word16 prm[2][PRM_SIZE_D + 2], Word16 prm_odd[2][PRM_SIZE_D + 2], Word16 prm_even[2][PRM_SIZE_D + 2], int status){
    //i表示帧的索引号
    for (int i = 0; i < 2; i++){
        if (status == 0)
        {
            ///LSP
            //L1
            Word16 sub1 = prm_odd[i][1];
//            Word16 sub1ModeIndex = (sub1 & 0x0020) >> 5;
            sub1 = sub1 & 0x001f; //5bit
            Word16 sub2 = prm_even[i][1];
//            Word16 sub2ModexIndex = (sub2 & 0x0040) >> 6;
            sub2 = sub2 & 0x003f; //6bit
//            Word16 rebuildL1 = LSPL1GetCombineValue(sub1, sub2);
            //prm[i][1] = shl(sub2ModexIndex, NC0_B) | rebuildL1;
            //printf("\n_:%d", sub2ModexIndex);
            prm[i][1] = prm_odd[i][1];
            
            //L3
            sub1 = prm_odd[i][2] & 0x001f;
            sub2 = prm_even[i][2] & 0x001f;
            Word16 rebuildL3 = sub2;
            
            //L2
            sub1 = (prm_odd[i][2] >> 5) & 0x0007;  //3bit
            sub2 = (prm_even[i][2] >> 5) & 0x0003; //2bit
            Word16 rebuildL2 = LSPL2GetCombineValue(sub1, sub2);
            prm[i][2] = shl(rebuildL3, NC1_B) | rebuildL2;
            //printf("\n_:%d %d %d", sub1, sub2, rebuildL3);
            
            
            
            ///pitch
            int p1 = prm_odd[i][3];
            //int p0 = prm_odd[i][4];
            int p2 = prm_odd[i][8];
            prm[i][3] = p1;
            prm[i][4] = 0;
            prm[i][8] = p2;
            
            
            
            ///fixcode
            Word16 posn[2][4];
            Word16 sn[2][4];
            Word16 tmp;
            Word16 index[2];
            index[0] = prm_odd[i][5];
            index[1] = prm_even[i][5];
            Word16 sign[2];
            sign[0] = prm_odd[i][6];
            sign[1] = prm_even[i][6];
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
            // Fixed-codebook index
            prm[i][5] = index[0];
            prm[i][9] = index[1];
            // Fixed-codebook pulse sign
            prm[i][6] = sign[0];
            prm[i][10] = sign[1];
            
            
            
            ///gains
            Word16 G1 = prm_odd[i][7];
            Word16 G2 = prm_odd[i][11];
            prm[i][7] = G1;
            prm[i][11] = G2;
        }
        else if (status == 1)
        {
            ///LSP
            //L1
            Word16 sub1 = prm_odd[i][1];
//            Word16 sub1ModeIndex = (sub1 & 0x0020) >> 5;
            sub1 = sub1 & 0x001f; //5bit
            Word16 sub2 = prm_even[i][1];
//            Word16 sub2ModexIndex = (sub2 & 0x0040) >> 6;
            sub2 = sub2 & 0x003f; //6bit
//            Word16 rebuildL1 = LSPL1GetCombineValue(sub1, sub2);
            //prm[i][1] = shl(sub2ModexIndex, NC0_B) | rebuildL1;
            //printf("\n_:%d", sub2ModexIndex);
            prm[i][1] = prm_odd[i][1];
            
            //L3
            sub1 = prm_odd[i][2] & 0x001f;
            Word16 rebuildL3 = sub1;
            
            //L2
            sub1 = (prm_odd[i][2] >> 5) & 0x0007;  //3bit
            Word16 rebuildL2 = LSPL2GetCombineValue(sub1, -1);
            prm[i][2] = shl(rebuildL3, NC1_B) | rebuildL2;
            //printf("\n_:%d %d %d", sub1, sub2, rebuildL3);
            
            
            
            ///pitch
            int p1 = prm_odd[i][3];
            //int p0 = prm_odd[i][4];
            int p2 = prm_odd[i][8];
            prm[i][3] = p1;
            prm[i][4] = 0;
            prm[i][8] = p2;
            
            
            
            ///fixcode
//            Word16 posn[2][4];
//            Word16 sn[2][4];
//            Word16 tmp;
            Word16 index[2];
            index[0] = prm_odd[i][5];
            //index[1] = prm_even[i][5];
            Word16 sign[2];
            sign[0] = prm_odd[i][6];
            //sign[1] = prm_even[i][6];
            
            // Fixed-codebook index
            prm[i][5] = index[0];
            prm[i][9] = index[0];
            // Fixed-codebook pulse sign
            prm[i][6] = sign[0];
            prm[i][10] = sign[0];
            
            
            ///gains
            Word16 G1 = prm_odd[i][7];
            Word16 G2 = prm_odd[i][11];
            prm[i][7] = G1;
            prm[i][11] = G2;
        }
        else if (status == 2)
        {
            ///LSP
            //L1
            Word16 sub1 = prm_odd[i][1];
//            Word16 sub1ModeIndex = (sub1 & 0x0020) >> 5;
            sub1 = sub1 & 0x001f; //5bit
            Word16 sub2 = prm_even[i][1];
//            Word16 sub2ModexIndex = (sub2 & 0x0040) >> 6;
            sub2 = sub2 & 0x003f; //6bit
//            Word16 rebuildL1 = LSPL1GetCombineValue(sub1, sub2);
            //prm[i][1] = shl(sub2ModexIndex, NC0_B) | rebuildL1;
            //printf("\n_:%d", sub2ModexIndex);
            prm[i][1] = prm_even[i][1];
            
            //L3
            sub2 = prm_even[i][2] & 0x001f;
            Word16 rebuildL3 = sub2;
            
            //L2
            sub2 = (prm_even[i][2] >> 5) & 0x0003; //2bit
            Word16 rebuildL2 = LSPL2GetCombineValue(-1, sub2);
            prm[i][2] = shl(rebuildL3, NC1_B) | rebuildL2;
            //printf("\n_:%d %d %d", sub1, sub2, rebuildL3);
            
            
            
            ///pitch
            int p1 = prm_even[i][3];
            //int p0 = prm_even[i][4];
            int p2 = prm_even[i][8];
            prm[i][3] = p1;
            prm[i][4] = 0;
            prm[i][8] = p2;
            
            
            
            ///fixcode
//            Word16 posn[2][4];
//            Word16 sn[2][4];
//            Word16 tmp;
            Word16 index[2];
            //index[0] = prm_odd[i][5];
            index[1] = prm_even[i][5];
            Word16 sign[2];
            //sign[0] = prm_odd[i][6];
            sign[1] = prm_even[i][6];
            
            // Fixed-codebook index
            prm[i][5] = index[1];
            prm[i][9] = index[1];
            // Fixed-codebook pulse sign
            prm[i][6] = sign[1];
            prm[i][10] = sign[1];
            
            
            ///gains
            Word16 G1 = prm_even[i][7];
            Word16 G2 = prm_even[i][11];
            prm[i][7] = G1;
            prm[i][11] = G2;
        }
        else if (status == 3){
            for (int j = 1; j < 12; j++) {
                prm[i][j] = 0;
            }
        }
        
    }
    
    
}
