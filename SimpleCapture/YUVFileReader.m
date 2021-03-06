//
//  YUVFileReader.m
//  SimpleCapture
//
//  Created by JFChen on 17/3/27.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import "YUVFileReader.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

static const DDLogLevel ddLogLevel = DDLogLevelInfo;
static NSString *directoryNameInOri = @"origin";
static NSString *directoryNameTransformInDoc = @"transform";

@interface YUVFileReader()
@property (nonatomic, copy) NSString *writeYUVFilePath;
@property (nonatomic, copy) NSString *writeH264FilePath;
@property (nonatomic, copy) NSString *readFilePath;
@property (nonatomic, strong) NSFileHandle *readFileHandle;
@property (nonatomic, strong) NSFileHandle *writeYUVFileHandle;
@property (nonatomic, strong) NSFileHandle *writeH264FileHandle;
@end

@implementation YUVFileReader{
    int32_t _width;
    int32_t _heigh;
    int32_t _yuvframesize;
    
    int32_t _writeFileCurrentOffset;
    int32_t _readFileCurrentOffset;
    NSInteger _readFileTotalSize;
    
    int frameidWrite;
}

- (instancetype)initWithFileFormat:(VideoFormat)format{
    self = [super init];
    if (self) {
        _width = format.width;
        _heigh = format.heigh;
        _yuvframesize = _width * _heigh * 3 / 2;
        
        _readFileCurrentOffset = 0;
        _writeFileCurrentOffset = 0;
    }
    return self;
}

- (instancetype)init{
    VideoFormat vformat;
    vformat.width = 1920;
    vformat.heigh = 1080;
    self = [self initWithFileFormat:vformat];
    return self;
}

- (void)writeYUVDataToFile:(NSString *)fileName data:(NSData *)data error:(NSError *)error{
    if (!_writeYUVFilePath) {
        self.writeYUVFilePath = [[[YUVFileReader documentPath] stringByAppendingPathComponent:directoryNameTransformInDoc] stringByAppendingPathComponent:fileName];
    }
    
    NSFileManager *defaultFile = [NSFileManager defaultManager];
    NSString *dir = [[YUVFileReader documentPath] stringByAppendingPathComponent:directoryNameTransformInDoc];
    if (![defaultFile fileExistsAtPath:dir]) {
        [defaultFile createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    if (![defaultFile fileExistsAtPath:_writeYUVFilePath isDirectory:nil]) {
        [defaultFile createFileAtPath:_writeYUVFilePath contents:nil attributes:nil];
    }
    
    NSLog(@"FrameIndexWrite:%d",frameidWrite++);
    [self appendYUVDataToFilePath:_writeYUVFilePath data:data];
}

- (void)writeH264DataToFile:(NSString *)fileName data:(NSData *)data error:(NSError *)error{
    if (!_writeH264FilePath) {
        self.writeH264FilePath = [[[YUVFileReader documentPath] stringByAppendingPathComponent:directoryNameTransformInDoc] stringByAppendingPathComponent:fileName];
    }
    
    NSFileManager *defaultFile = [NSFileManager defaultManager];
    NSString *dir = [[YUVFileReader documentPath] stringByAppendingPathComponent:directoryNameTransformInDoc];
    if (![defaultFile fileExistsAtPath:dir]) {
        [defaultFile createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    if (![defaultFile fileExistsAtPath:_writeH264FilePath isDirectory:nil]) {
        [defaultFile createFileAtPath:_writeH264FilePath contents:nil attributes:nil];
    }
    
    [self appendH264DataToFilePath:_writeH264FilePath data:data];
}

- (void)appendYUVDataToFilePath:(NSString *)filePath data:(NSData *)data{
    if (!self.writeYUVFileHandle) {
        self.writeYUVFileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    }
    
    [self.writeYUVFileHandle seekToEndOfFile];
    [self.writeYUVFileHandle writeData:data];
}

- (void)appendH264DataToFilePath:(NSString *)filePath data:(NSData *)data{
    if (!self.writeH264FileHandle) {
        self.writeH264FileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    }
    
    [self.writeH264FileHandle seekToEndOfFile];
    [self.writeH264FileHandle writeData:data];
}

#pragma mark - read file

- (NSData *)readOneFrameYUVDataWithFile:(NSString *)fileName error:(NSError *)error{
    if (!_readFilePath) {
        self.readFilePath = [[[YUVFileReader documentPath] stringByAppendingPathComponent:directoryNameInOri] stringByAppendingPathComponent:fileName];
    }
    
    NSFileManager *defaultFileMan = [NSFileManager defaultManager];
    if (![defaultFileMan fileExistsAtPath:self.readFilePath isDirectory:nil]) {
        if (error) {
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:@{@"error":@"file do not exit"}];
        }
        return nil;
    }
    
    NSRange range = NSMakeRange(_readFileCurrentOffset, _yuvframesize);
    NSData *data = [self readDataWithRange:range filePath:self.readFilePath];
    _readFileCurrentOffset += _yuvframesize;
    
    return data;
}

- (NSData *)readDataWithRange:(NSRange)range filePath:(NSString *)filePath{
    if (!self.readFileHandle) {
        self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        NSFileManager *filemanager = [NSFileManager defaultManager];
        NSDictionary *attr = [filemanager attributesOfItemAtPath:filePath error:nil];
        NSString *filesize = [attr objectForKey:NSFileSize];
        _readFileTotalSize = [filesize integerValue];
    }
    
    [self.readFileHandle seekToFileOffset:range.location];
    NSData *data = [self.readFileHandle readDataOfLength:range.length];
    return data;
}

#pragma mark - class function
//输入的格式必须为640x480_xxxx这样的格式才能解析
+ (VideoFormat)analyseVideoFormatWithFileName:(NSString *)fileName{
    VideoFormat format;
    format.width = 0;
    format.heigh = 0;
    
    NSRange xRange = [fileName rangeOfString:@"x"];
    NSString *width = [fileName substringToIndex:xRange.location];
    NSRange _Range = [fileName rangeOfString:@"_"];
    NSString *heigh = [fileName substringWithRange:NSMakeRange(xRange.location+1, _Range.location-xRange.location-1)];
    
    format.width = [width intValue];
    format.heigh = [heigh intValue];
    
    return format;
}

+ (NSString *)documentPath{
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return documentsPath;
}

+ (NSArray *)videoFilesPathInOri{
    return [YUVFileReader subFilesInDir:directoryNameInOri];
}

+ (NSArray *)videoFilesPathInTransform{
    return [YUVFileReader subFilesInDir:directoryNameTransformInDoc];
}

+ (NSArray *)subFilesInDir:(NSString *)dirName{
    NSString *oriDirPath = [[YUVFileReader documentPath] stringByAppendingPathComponent:dirName];
    NSFileManager *defaultFileManage = [NSFileManager defaultManager];
    
    BOOL isDire = NO;
    if (![defaultFileManage fileExistsAtPath:oriDirPath isDirectory:&isDire] || !isDire) {
        NSError *error = nil;
        [defaultFileManage createDirectoryAtPath:oriDirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            DDLogError(@"%s directory create error %@", __PRETTY_FUNCTION__, error);
        }
        
        return nil;
    }
    
    NSArray *subFile = [defaultFileManage subpathsAtPath:oriDirPath];
    return subFile;
}

@end
