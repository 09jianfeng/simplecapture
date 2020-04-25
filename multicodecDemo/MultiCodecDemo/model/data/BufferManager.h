//
//  BufferManager.h
//  MultiCodecDemo
//
//  Created by JFChen on 2019/4/26.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BufferManagerDelegate <NSObject>

//status 0:两条流都有收到 1:收到奇流 2:收到偶流 3:两条流都没收到
- (void)shouldDecodeWith:(NSData *)data status:(int)status;

@end

@interface BufferManager : NSObject
@property(nonatomic , weak) id<BufferManagerDelegate> delegate;

- (BOOL)addPCMDataToPlayBuffer:(Byte *)buffer size:(NSUInteger)size;
- (BOOL)getPCMDataFromPlayBuffer:(Byte *)buffer size:(NSUInteger)size;
- (BOOL)addPCMDataToRecordBuffer:(Byte *)buffer size:(NSUInteger)size;
- (BOOL)getPCMDataFromRecordBuffer:(Byte *)buffer size:(NSUInteger)size;

- (BOOL)addEncodedData:(int)frameid data:(NSData *)data;

- (BOOL)addEncodedDataEnSide:(NSData *)data;
- (NSData *)getEncodedDataEnSide;

@end
