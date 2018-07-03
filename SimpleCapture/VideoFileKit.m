//
//  VideoFileKit.m
//  SimpleCapture
//
//  Created by JFChen on 2018/7/3.
//  Copyright © 2018年 duowan. All rights reserved.
//

#import "VideoFileKit.h"

@implementation VideoFileKit

+ (BOOL)createDirectoryAtPath:(NSString *)directoryPath {
    if (directoryPath != nil) {
        if (![VideoFileKit existDirectoryAtPath:directoryPath]) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            return [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        } else {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)deleteDirectoryAtPath:(NSString *)directoryPath {
    if (directoryPath != nil) {
        if ([VideoFileKit existDirectoryAtPath:directoryPath]) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            return [fileManager removeItemAtPath:directoryPath error:nil];
        } else {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)existDirectoryAtPath:(NSString *)directoryPath {
    if (directoryPath != nil) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isExist = NO;
        BOOL isDirectory = NO;
        isExist = [fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory];
        if (isExist && !isDirectory) {
            isExist = NO;
        }
        return isExist;
    }
    return NO;
}

+ (NSInteger)fileSizeOfDirectoryAtPath:(NSString *)directoryPath {
    NSInteger directorySize = 0;
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfDirectoryAtPath:directoryPath];
    if (fileAttributeDict != nil) {
        NSNumber *sizeNumber = fileAttributeDict[NSFileSize];
        if (sizeNumber != nil) {
            directorySize = [sizeNumber integerValue];
        }
    }
    return directorySize;
}

+ (NSDate *)creationDateOfDirectoryAtPath:(NSString *)directoryPath {
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfDirectoryAtPath:directoryPath];
    if (fileAttributeDict != nil) {
        return fileAttributeDict[NSFileCreationDate];
    }
    return nil;
}

+ (NSDate *)modificationDateOfDirectoryAtPath:(NSString *)directoryPath {
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfDirectoryAtPath:directoryPath];
    if (fileAttributeDict != nil) {
        return fileAttributeDict[NSFileModificationDate];
    }
    return nil;
}

+ (NSString *)ownerNameOfDirectoryAtPath:(NSString *)directoryPath {
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfDirectoryAtPath:directoryPath];
    if (fileAttributeDict != nil) {
        return fileAttributeDict[NSFileOwnerAccountName];
    }
    return nil;
}

+ (NSString *)groupOwnerNameOfDirectoryAtPath:(NSString *)directoryPath {
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfDirectoryAtPath:directoryPath];
    if (fileAttributeDict != nil) {
        return fileAttributeDict[NSFileGroupOwnerAccountName];
    }
    return nil;
}

+ (NSDictionary *)attributesOfDirectoryAtPath:(NSString *)directoryPath {
    if ([VideoFileKit existDirectoryAtPath:directoryPath]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        return [fileManager attributesOfItemAtPath:directoryPath error:nil];
    }
    return nil;
}

+ (NSString *)idOfDirectoryAtPath:(NSString *)directoryPath {
    return [[VideoFileKit attributesOfDirectoryAtPath:directoryPath] descriptionInStringsFileFormat];
}

+ (NSArray<NSString *> *)filesInDirectoryAtPath:(NSString *)directoryPath withPathExtension:(NSString *)pathExtension {
    if (![VideoFileKit existDirectoryAtPath:directoryPath] || pathExtension == nil) {
        return nil;
    }
    NSArray *pathExtensions = @[pathExtension];
    return [VideoFileKit filesInDirectoryAtPath:directoryPath withPathExtensions:pathExtensions];
}

+ (NSArray<NSString *> *)filesInDirectoryAtPath:(NSString *)directoryPath withPathExtensions:(NSArray<NSString *> *)pathExtensions {
    if (![VideoFileKit existDirectoryAtPath:directoryPath] || pathExtensions == nil) {
        return nil;
    }
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension IN %@", pathExtensions];
    return [dirContents filteredArrayUsingPredicate:predicate];
}

+ (BOOL)isReadableDirectoryAtPath:(NSString *)directoryPath {
    if ([VideoFileKit existDirectoryAtPath:directoryPath]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        return [fileManager isReadableFileAtPath:directoryPath];
    }
    return NO;
}

+ (BOOL)isWritableDirectoryAtPath:(NSString *)directoryPath {
    if ([VideoFileKit existDirectoryAtPath:directoryPath]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        return [fileManager isWritableFileAtPath:directoryPath];
    }
    return NO;
}

+ (NSString *)cachesDirectory {
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [pathArray objectAtIndex:0];
}

+ (NSString *)resourceDirectory {
    return [[NSBundle mainBundle] resourcePath];
}

+ (BOOL)deleteFileAtPath:(NSString *)filePath {
    if (filePath != nil) {
        if ([VideoFileKit existFileAtPath:filePath]) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            return [fileManager removeItemAtPath:filePath error:nil];
        } else {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)existFileAtPath:(NSString *)filePath {
    if (filePath != nil) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isExist = NO;
        BOOL isDirectory = NO;
        isExist = [fileManager fileExistsAtPath:filePath isDirectory:&isDirectory];
        if (isExist && isDirectory) {
            isExist = NO;
        }
        return isExist;
    }
    return NO;
}

+ (NSInteger)fileSizeOfFileAtPath:(NSString *)filePath {
    NSInteger fileSize = 0;
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfFileAtPath:filePath];
    if (fileAttributeDict != nil) {
        NSNumber *sizeNumber = fileAttributeDict[NSFileSize];
        if (sizeNumber != nil) {
            fileSize = [sizeNumber integerValue];
        }
    }
    return fileSize;
}

+ (NSDate *)creationDateOfFileAtPath:(NSString *)filePath {
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfFileAtPath:filePath];
    if (fileAttributeDict != nil) {
        return fileAttributeDict[NSFileCreationDate];
    }
    return nil;
}

+ (NSDate *)modificationDateOfFileAtPath:(NSString *)filePath {
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfFileAtPath:filePath];
    if (fileAttributeDict != nil) {
        return fileAttributeDict[NSFileModificationDate];
    }
    return nil;
}

+ (NSString *)ownerNameOfFileAtPath:(NSString *)filePath {
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfFileAtPath:filePath];
    if (fileAttributeDict != nil) {
        return fileAttributeDict[NSFileOwnerAccountName];
    }
    return nil;
}

+ (NSString *)groupOwnerNameOfFileAtPath:(NSString *)filePath {
    NSDictionary *fileAttributeDict = [VideoFileKit attributesOfFileAtPath:filePath];
    if (fileAttributeDict != nil) {
        return fileAttributeDict[NSFileGroupOwnerAccountName];
    }
    return nil;
}

+ (NSDictionary *)attributesOfFileAtPath:(NSString *)filePath {
    if ([VideoFileKit existFileAtPath:filePath]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        return [fileManager attributesOfItemAtPath:filePath error:nil];
    }
    return nil;
}

+ (NSString *)idOfFileAtPath:(NSString *)filePath {
    return [[VideoFileKit attributesOfFileAtPath:filePath] descriptionInStringsFileFormat];
}

+ (BOOL)isReadableFileAtPath:(NSString *)filePath {
    if ([VideoFileKit existFileAtPath:filePath]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        return [fileManager isReadableFileAtPath:filePath];
    }
    return NO;
}

+ (BOOL)isWritableFileAtPath:(NSString *)filePath {
    if ([VideoFileKit existFileAtPath:filePath]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        return [fileManager isWritableFileAtPath:filePath];
    }
    return NO;
}


+ (NSString *)directoryComponentOfPath:(NSString *)path {
    return [path stringByDeletingLastPathComponent];
}

+ (NSString *)fileComponentOfPath:(NSString *)path {
    return [path lastPathComponent];
}

+ (NSString *)fileExtensionOfPath:(NSString *)path {
    return [path pathExtension];
}

+ (NSString *)pathByReplacingExtensionOfPath:(NSString *)path extension:(NSString *)extension {
    return [[path stringByDeletingPathExtension] stringByAppendingPathExtension:extension];
}

+ (NSURL *)pathToFileUrl:(NSString *)path {
    if (path == nil) {
        NSLog(@"path is nil");
        return nil;
    }
    if ([path hasPrefix:@"file"] || [path hasPrefix:@"ipod-library"]) {
        NSURL * fileUrl = [NSURL URLWithString:path];
        return fileUrl;
    } else {
        NSURL * fileUrl = [NSURL fileURLWithPath:path];
        if (fileUrl.isFileURL) {
            return fileUrl;
        } else {
            fileUrl = [NSURL URLWithString:path];
            if (fileUrl.isFileURL) {
                return fileUrl;
            } else {
                NSLog(@"file url error with %@", path);
                return nil;
            }
        }
    }
}

@end
