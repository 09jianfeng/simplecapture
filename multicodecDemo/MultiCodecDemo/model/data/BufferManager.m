//
//  BufferManager.m
//  MultiCodecDemo
//
//  Created by JFChen on 2019/4/26.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import "BufferManager.h"
#import "UtilHeader.h"

const int MaxEncodedDataFrameNum = 1000; // 总缓冲区大小
const int InitCacheNum = 100; // 一开始缓存的帧数
const int DecodedNumOneTime = InitCacheNum/4; //一次解码多少帧
const int MinCaheNum = InitCacheNum/8; //PCM缓存中剩下多少帧后触发解码。
const int BeginDecodeThreshold = 80*2 * MinCaheNum; //缓冲剩下 10帧的时候触发解码。

@implementation BufferManager{
    dispatch_queue_t _bufferPlayQueue;
    dispatch_queue_t _bufferRecordQueue;
    dispatch_queue_t _bufferDecodeQueue;
    
    NSMutableData *_bufferDataForPlay;
    NSMutableData *_bufferDataForRecord;
    
    NSMutableArray *_encodedData;
    int _encodedDataCurIndex;
    int _allReceiveFrameCount;
    BOOL _isFirst;
    
    NSData *_emptyOneFrameData;
    NSMutableArray *_encodeSideAry;
    BOOL _encodeSideTopOut;
    
    int _noDataNum;
    int _playCallBackCout;
    
    int _allLossCount;
    int _evenLossCount;
    int _oddLossCount;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _bufferPlayQueue  = dispatch_queue_create("bufferPlayqueue", NULL);
        _bufferRecordQueue = dispatch_queue_create("bufferRecordqueue", NULL);
        _bufferDecodeQueue = dispatch_queue_create("bufferDecodeQueue", NULL);
        
        _bufferDataForPlay = [NSMutableData new];
        _bufferDataForRecord = [NSMutableData new];
        _encodeSideAry = [NSMutableArray new];
        
        unsigned char emptyData[15];
        for (int i = 0; i < 15; i++) {
            emptyData[i] = 0;
        }
        _emptyOneFrameData = [NSData dataWithBytes:emptyData length:15];
        
        _encodedData = [[NSMutableArray alloc] initWithCapacity:MaxEncodedDataFrameNum];
        for (int i = 0; i < MaxEncodedDataFrameNum; i++) {
            [_encodedData addObject:[NSData data]];
        }
        
        _encodedDataCurIndex = 0;
        _allReceiveFrameCount = 0;
        _isFirst = YES;
    }
    return self;
}

#pragma mark - buffer handle
- (void)logCurrentStatus{
    AudioLog(@"playcb:%d nodata:%d PCMBuffer:%td currIndex:%d allIndex:%d aloss:%d oddLoss:%d evenLoss:%d allRec:%d",
          _playCallBackCout,
          _noDataNum,
          _bufferDataForPlay.length,
          _encodedDataCurIndex,
             _allReceiveFrameCount%MaxEncodedDataFrameNum,
             _allLossCount,
             _oddLossCount,
             _evenLossCount, _allReceiveFrameCount);
}

- (BOOL)addPCMDataToPlayBuffer:(Byte *)buffer size:(NSUInteger)size{
    dispatch_sync(_bufferPlayQueue, ^{
        [self->_bufferDataForPlay appendBytes:buffer length:size];
    });
    return true;
}

- (BOOL)getPCMDataFromPlayBuffer:(Byte *)buffer size:(NSUInteger)size{
    _playCallBackCout++;
    if (_playCallBackCout % 100 == 0) {
        [self logCurrentStatus];
    }
    
    if (self->_bufferDataForPlay.length < size) {
        _noDataNum++;
        [self needDataToPlay];
        memset(buffer, 0, size);
        return false;
    }
    
    //如果播放缓冲剩下的缓冲不够了小于BeginDecodeThreshold 80*2 * 10. 对于G729来说就是100ms。
    if (self->_bufferDataForPlay.length < BeginDecodeThreshold) {
        [self needDataToPlay];
    }
    
    dispatch_sync(_bufferPlayQueue, ^{
        @autoreleasepool {
            NSUInteger bufferDataSize = self->_bufferDataForPlay.length;
            NSData *subData1 = [self->_bufferDataForPlay subdataWithRange:NSMakeRange(0,size)];
            memcpy(buffer, [subData1 bytes], size);
            
            NSData *subData2 = [self->_bufferDataForPlay subdataWithRange:NSMakeRange(size, bufferDataSize - size)];
            self->_bufferDataForPlay = [NSMutableData dataWithData:subData2];
        }
    });
    return true;
}

- (BOOL)addPCMDataToRecordBuffer:(Byte *)buffer size:(NSUInteger)size{
    dispatch_sync(_bufferRecordQueue, ^{
        [self->_bufferDataForRecord appendBytes:buffer length:size];
    });
    return true;
}

- (BOOL)getPCMDataFromRecordBuffer:(Byte *)buffer size:(NSUInteger)size{
    
    if (self->_bufferDataForRecord.length < size) {
        memset(buffer, 0, size);
        return false;
    }
    
    dispatch_sync(_bufferRecordQueue, ^{
        NSUInteger bufferDataSize = self->_bufferDataForRecord.length;
        NSData *subData1 = [self->_bufferDataForRecord subdataWithRange:NSMakeRange(0,size)];
        memcpy(buffer, [subData1 bytes], size);
        
        NSData *subData2 = [self->_bufferDataForRecord subdataWithRange:NSMakeRange(size, bufferDataSize - size)];
        self->_bufferDataForRecord = [NSMutableData dataWithData:subData2];
    });
    return true;
}

- (void)resetEncodedDataBuffer{
    _encodedDataCurIndex = 0;
    [_encodedData removeAllObjects];
}

- (BOOL)addEncodedData:(int)frameid data:(NSData *)data{
    
    int index = frameid % MaxEncodedDataFrameNum;
    _encodedData[index] = data;
    _allReceiveFrameCount++;
    
    return YES;
}

- (void)needDataToPlay{
    if (_isFirst && _allReceiveFrameCount < InitCacheNum) {
        return;
    }
    
    _isFirst = NO;
    
    dispatch_async(_bufferDecodeQueue, ^{
        
        @autoreleasepool {
            //触发解码后，不断轮询解码。解码 解1/4的帧
            for (int i = 0; i < InitCacheNum / 4.0; i++) {
                
                NSData *dataOdd = self->_encodedData[self->_encodedDataCurIndex];
                self->_encodedData[self->_encodedDataCurIndex] = [NSData data];
                self->_encodedDataCurIndex++;
                self->_encodedDataCurIndex = self->_encodedDataCurIndex % MaxEncodedDataFrameNum;
                
                NSData *dataEven = self->_encodedData[self->_encodedDataCurIndex];
                self->_encodedData[self->_encodedDataCurIndex] = [NSData data];
                self->_encodedDataCurIndex++;
                self->_encodedDataCurIndex = self->_encodedDataCurIndex % MaxEncodedDataFrameNum;
                
                
                NSMutableData *doubleData = [NSMutableData new];
                
                int status = 0;
                if (dataOdd.length == 0 && dataEven.length == 0) {
                    [doubleData appendData:self->_emptyOneFrameData];
                    [doubleData appendData:self->_emptyOneFrameData];
//                    AudioLog(@"all lose:%d %d", self->_encodedDataCurIndex-2, self->_encodedDataCurIndex-1);
                    self->_allLossCount++;
                    status = 3;
                }
                else if(dataOdd.length == 0){
                    [doubleData appendData:self->_emptyOneFrameData];
                    [doubleData appendData:dataEven];
//                    AudioLog(@"odd lose:%d", self->_encodedDataCurIndex-1);
                    self->_oddLossCount++;
                    status = 2;
                }
                else if (dataEven.length == 0){
                    [doubleData appendData:dataOdd];
                    [doubleData appendData:self->_emptyOneFrameData];
//                    AudioLog(@"even lose:%d", self->_encodedDataCurIndex-2);
                    self->_evenLossCount++;
                    status = 1;
                }else{
                    [doubleData appendData:dataOdd];
                    [doubleData appendData:dataEven];
                    status = 0;
                }
                
                if ([self->_delegate respondsToSelector:@selector(shouldDecodeWith:status:)]) {
                    [self->_delegate shouldDecodeWith:doubleData status:status];
                }
            }
        }
    });
}


- (BOOL)addEncodedDataEnSide:(NSData *)data{
    [_encodeSideAry addObject:data];
    return YES;
}


- (NSData *)getEncodedDataEnSide{
    NSData *data = [NSData data];
    if (_encodeSideAry.count > 4) {
        if (_encodeSideTopOut) {
            _encodeSideTopOut = NO;
            data = [_encodeSideAry lastObject];
            [_encodeSideAry removeLastObject];
        }else{
            _encodeSideTopOut = YES;
            data = [_encodeSideAry firstObject];
            [_encodeSideAry removeObjectAtIndex:0];
        }
    }
    return data;
}

@end









