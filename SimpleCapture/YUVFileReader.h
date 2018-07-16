//
//  YUVFileReader.h
//  SimpleCapture
//
//  Created by JFChen on 17/3/27.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct VideoFormat{
    int32_t width;
    int32_t heigh;
}VideoFormat;

@interface YUVFileReader : NSObject

+ (NSString *)documentPath;

+ (NSArray *)videoFilesPathInOri;
+ (NSArray *)videoFilesPathInTransform;
+ (void)copyFileToTransformDir:(NSString *)inputFile;

//输入的格式必须为640x480_xxxx这样的宽高在开头的格式才能解析
+ (VideoFormat)analyseVideoFormatWithFileName:(NSString *)fileName;

- (instancetype)initWithFileFormat:(VideoFormat)format NS_DESIGNATED_INITIALIZER;

- (void)writeYUVDataToFile:(NSString *)fileName data:(NSData *)data error:(NSError *)error;
- (void)writeH264DataToFile:(NSString *)fileName data:(NSData *)data error:(NSError *)error;

- (NSData *)readOneFrameYUVDataWithFile:(NSString *)fileName error:(NSError *)error;
@end
