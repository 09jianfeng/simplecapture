//
//  DataPackUnPack.h
//  YYVideolibDemo
//
//  Created by JFChen on 2018/2/5.
//  Copyright © 2018年 JFChen. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct FramDataFormat {
    uint32_t m_pts;
    uint32_t m_vadResultKind;
    uint32_t m_framelength;
    uint32_t m_codecType;
    uint32_t m_frameIndex;
    int m_ssrc;
    void *m_framedata;
}FramDataFormat;

@interface DataPackUnPack : NSObject

+ (NSData *)packDataWithExtraHeader:(FramDataFormat)fDFormat;
+ (void)unPackBodyData:(FramDataFormat *)fDFormat data:(NSData *)data;
+ (void)unPackUDPBodyData:(FramDataFormat *)fDFormat data:(NSData *)data;
+ (int)getIntFromLittleEndian:(uint8_t *)data;
@end
