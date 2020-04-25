//
//  DataPackUnPack.m
//  YYVideolibDemo
//
//  Created by JFChen on 2018/2/5.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import "DataPackUnPack.h"

@implementation DataPackUnPack

+ (NSData *)packDataWithExtraHeader:(FramDataFormat)fDFormat{
    
    uint32_t packHeaderLen = 4;
    
    uint32_t dataLength = 20+fDFormat.m_framelength;
    char *packData = malloc(dataLength + packHeaderLen);
    char *packOffset = packData;
    
    char *packDataLen = (char *)&dataLength;
    memcpy(packOffset, packDataLen, 4);
    packOffset += 4;
    
    char *type = (char *)&(fDFormat.m_ssrc);
    memcpy(packOffset, type, 4);
    packOffset += 4;
    
    char *pts = (char *)&(fDFormat.m_pts);
    memcpy(packOffset, pts, 4);
    packOffset += 4;

    
    char *dts = (char *)&(fDFormat.m_vadResultKind);
    memcpy(packOffset, dts, 4);
    packOffset += 4;
    
    char *codecType = (char *)&(fDFormat.m_codecType);
    memcpy(packOffset, codecType, 4);
    packOffset += 4;
    
    char *frameIndex = (char *)&(fDFormat.m_frameIndex);
    memcpy(packOffset, frameIndex, 4);
    packOffset += 4;

    
    memcpy(packOffset, fDFormat.m_framedata, fDFormat.m_framelength);
    NSData *data = [NSData dataWithBytes:packData length:dataLength+packHeaderLen];
    
    free(packData);
    return data;
}

+ (void)unPackBodyData:(FramDataFormat *)fDFormat data:(NSData *)data{
    uint8_t *packData = (uint8_t *)[data bytes];
    
    int ssrc = [self getIntFromLittleEndian:packData];
    packData+=4;
    int pts = [self getIntFromLittleEndian:packData];
    packData += 4;
    int vadResultKind = [self getIntFromLittleEndian:packData];
    packData += 4;
    int codecType = [self getIntFromLittleEndian:packData];
    packData += 4;
    int frameIndex = [self getIntFromLittleEndian:packData];
    packData += 4;
    
    fDFormat->m_vadResultKind = vadResultKind;
    fDFormat->m_pts =  pts;
    fDFormat->m_ssrc = ssrc;
    fDFormat->m_framedata = packData;
    fDFormat->m_codecType = codecType;
    fDFormat->m_frameIndex = frameIndex;
    fDFormat->m_framelength = (uint32_t)data.length - 20;
}

+ (void)unPackUDPBodyData:(FramDataFormat *)fDFormat data:(NSData *)data{
    uint8_t *packData = (uint8_t *)[data bytes];
    packData += 4;
    
    int ssrc = [self getIntFromLittleEndian:packData];
    packData+=4;
    int pts = [self getIntFromLittleEndian:packData];
    packData += 4;
    int vadResultKind = [self getIntFromLittleEndian:packData];
    packData += 4;
    int codecType = [self getIntFromLittleEndian:packData];
    packData += 4;
    int frameIndex = [self getIntFromLittleEndian:packData];
    packData += 4;
    
    fDFormat->m_vadResultKind = vadResultKind;
    fDFormat->m_pts =  pts;
    fDFormat->m_ssrc = ssrc;
    fDFormat->m_codecType = codecType;
    fDFormat->m_framedata = packData;
    fDFormat->m_frameIndex = frameIndex;
    fDFormat->m_framelength = (uint32_t)data.length - 24;
}

+ (int)getIntFromLittleEndian:(uint8_t *)data
{
    int data0 = data[0];
    int data1 = data[1];
    int data2 = data[2];
    int data3 = data[3];
    return (data0 << 0) | (data1 << 8) | (data2 << 16) | (data3 << 24);
}


@end
