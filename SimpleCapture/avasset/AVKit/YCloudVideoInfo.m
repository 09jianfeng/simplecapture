//
//  YCloudVideoInfo.m
//  YCloudRecorderDev
//
//  Created by 包红来 on 15/8/18.
//  Copyright (c) 2015年 包红来. All rights reserved.
//

#import "YCloudVideoInfo.h"
#import "ffmpeg.h"
#import "YMTinyVideoDispatcher.h"
#import "YMTinyVideoMediaKit.h"

char* ffprobe_main(int argc, char **argv);

@interface YCloudVideoInfo(){
    NSDictionary * _videoInfoDict;
    NSDictionary * _audioInfoDict;
    NSString * _filePath;
}

@end

@implementation YCloudVideoInfo
@synthesize width       = _width;
@synthesize height      = _height;
@synthesize duration    = _duration;
@synthesize nb_frames   = _nb_frames;

static YMTinyVideoDispatcher *sProberDispatcher;

- (instancetype)initWithPath:(NSString *)filePath {
    if (self = [super init]) {
        if (sProberDispatcher == nil) {
            sProberDispatcher = [[YMTinyVideoDispatcher alloc] initWithQueueName:@"com.yy.yymediarecordersdk.prober"];
        }
        _filePath = filePath;
        _videoInfoDict = [[self class] getVideoInfo:filePath];
        _audioInfoDict = [[self class] getAudioInfo:filePath];
    }
    return self;
}

- (NSString *)filePath {
    return _filePath;
}

- (NSInteger)width {
    if (_videoInfoDict) {
        _width = [(NSNumber*)[_videoInfoDict objectForKey:@"width"] intValue];
    } else {
        _width = [YMTinyVideoMediaKit resolutionOfVideoAtPath:_filePath].width;
    }
    return _width;
}

- (NSInteger)height {
    if (_videoInfoDict) {
        _height = [(NSNumber*)[_videoInfoDict objectForKey:@"height"] intValue];
    } else {
        _height = [YMTinyVideoMediaKit resolutionOfVideoAtPath:_filePath].height;
    }
    return _height;
}

- (NSInteger)rotatedWidth {
    if (self.rotate == 90 || self.rotate == 270 || self.rotate == -90 || self.rotate == -270) {
        return self.height;
    } else {
        return self.width;
    }
}

- (NSInteger)rotatedHeight {
    if (self.rotate == 90 || self.rotate == 270 || self.rotate == -90 || self.rotate == -270) {
        return self.width;
    } else {
        return self.height;
    }
}

- (CGFloat)duration {
    if (_videoInfoDict) {
        _duration = [(NSNumber*)[_videoInfoDict objectForKey:@"duration"] floatValue];
    } else {
        _duration = [YMTinyVideoMediaKit durationOfVideoAtPath:_filePath] / 1000.0f;
    }
    return _duration;
}

- (CGFloat)start_time {
    if (_videoInfoDict) {
        return [(NSNumber*)[_videoInfoDict objectForKey:@"start_time"] floatValue];
    }
    
    return 0.0f;
}

- (NSInteger)nb_frames {
    if (_videoInfoDict) {
        _nb_frames = [(NSNumber*)[_videoInfoDict objectForKey:@"nb_frames"] floatValue];
    } else {
        _nb_frames = [YMTinyVideoMediaKit frameAmountOfVideoAtPath:_filePath];
    }
    return _nb_frames;
}

- (NSArray *)side_data_list {
    if (_videoInfoDict) {
        return [_videoInfoDict objectForKey:@"side_data_list"];
    }
    return nil;
}

- (NSDictionary *)tags {
    if (_videoInfoDict) {
        return [_videoInfoDict objectForKey:@"tags"];
    }
    return nil;
}

- (NSInteger)rotate {
    if (_videoInfoDict) {
        if (self.tags) {
            return [(NSNumber *)[self.tags objectForKey:@"rotate"] integerValue];
        }
    }
    return 0;
}

- (NSInteger)video_bitrate {
    if (_videoInfoDict) {
        return [(NSNumber *)[_videoInfoDict objectForKey:@"bit_rate"] integerValue];
    } else {
        return [YMTinyVideoMediaKit bitRateOfVideoAtPath:_filePath];
    }
    return 0;
}

- (CGFloat)audio_duration {
    if (_audioInfoDict) {
        return [(NSNumber*)[_audioInfoDict objectForKey:@"duration"] floatValue];
    } else {
        return [YMTinyVideoMediaKit audioDurationOfVideoAtPath:_filePath] / 1000.0f;
    }
    return 0.0;
}

- (CGFloat)audio_start_time {
    if (_audioInfoDict) {
        return [(NSNumber*)[_audioInfoDict objectForKey:@"start_time"] floatValue];
    }
    return 0.0;
}

- (NSInteger)fps {
    if (_videoInfoDict) {
        return [YCloudVideoInfo divString2NSInteger: [_videoInfoDict objectForKey:@"avg_frame_rate"]];
    } else {
        return [YMTinyVideoMediaKit frameRateOfVideoAtPath:_filePath];
    }
    return 0;
}

- (NSInteger)audioChannels {
    if (_audioInfoDict) {
        return [(NSNumber *)[_audioInfoDict objectForKey:@"channels" ] integerValue];
    } else {
        return [YMTinyVideoMediaKit audioChannelOfVideoAtPath:_filePath];
    }
    return 0;
}

+ (NSDictionary *)getVideoInfo:(NSString *)filePath {
    if (!filePath) {
        NSLog(@"[Error] filePath is nil");
        return nil;
    }
    NSInteger numberOfArgs = 6;
    NSInteger i=0;
    char** arguments = calloc(numberOfArgs, sizeof(char*));
    arguments[i++] = "ffprobe";
    arguments[i++] = "-print_format";
    arguments[i++] = "json";
    arguments[i++] = "-show_streams";
    arguments[i++] = "-i";
    arguments[i++] = (char*)[filePath UTF8String];
    
    __block NSString *resultStr;
    dispatch_sync_task(sProberDispatcher, ^(){
        resultStr = [[self class] ffprobe_cmd:i arguments:arguments];
    });
    if (!resultStr) {
        free(arguments);
        return nil;
    }
    NSData   *resultData = [resultStr dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:resultData options:0 error:&error];
    NSDictionary *videoInfoDict;
    if (!error && resultDict) {
        NSArray *streams = [resultDict objectForKey:@"streams"];
        for (NSInteger i=0; i<[streams count]; ++i) {
            NSDictionary *streamDic = streams[i];
            if ([[streamDic objectForKey:@"codec_type"] isEqualToString:@"video"]) {
                videoInfoDict = streamDic;
                break;
            }
        }
    }
    free(arguments);
    return  videoInfoDict;
}

+ (NSDictionary *)getAudioInfo:(NSString *)filePath {
    if (!filePath) {
        NSLog(@"[Error] audio filePath is nil");
        return nil;
    }
    NSInteger numberOfArgs = 6;
    NSInteger i=0;
    char** arguments = calloc(numberOfArgs, sizeof(char*));
    arguments[i++] = "ffprobe";
    arguments[i++] = "-print_format";
    arguments[i++] = "json";
    arguments[i++] = "-show_streams";
    arguments[i++] = "-i";
    arguments[i++] = (char*)[filePath UTF8String];
    
    __block NSString *resultStr;
    dispatch_sync_task(sProberDispatcher, ^(){
        resultStr = [[self class] ffprobe_cmd:i arguments:arguments];
    });
    
    if (!resultStr) {
        free(arguments);
        return nil;
    }
    NSData *resultData = [resultStr dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:resultData options:0 error:&error];
    NSDictionary *AudioInfo=nil;
    if (!error && resultDict) {
        NSArray *streams = [resultDict objectForKey:@"streams"];
        for (NSInteger i=0; i<[streams count]; ++i) {
            NSDictionary *streamDic = streams[i];
            if ([[streamDic objectForKey:@"codec_type"] isEqualToString:@"audio"]) {
                AudioInfo = streamDic;
                break;
            }
        }
    }
    free(arguments);
    return  AudioInfo;
}

+ (NSString *)ffprobe_cmd:(NSInteger)numberOfArgs
                 arguments:(char **) arguments {
    char *result = ffprobe_main((int)numberOfArgs, arguments);
    if (result==NULL) {
        NSLog(@"[Error] result:%s",result);
        return nil;
    }
    NSString *resultStr = [NSString stringWithUTF8String:result];
    free(result);
    result = NULL;
    
    return resultStr;
}

+ (NSInteger)divString2NSInteger:(NSString *)str {
    if (str ==  nil) {
        return 0;
    }
    
    NSArray *array = [str componentsSeparatedByString: @"/"];
    if (array == nil || array.count <= 0) {
        return 0;
    }
    
    if (array.count == 1 ) {
        return [[array objectAtIndex: 0] integerValue];
    }
    
    NSUInteger num = [[array objectAtIndex: 0] integerValue];
    NSUInteger den = [[array objectAtIndex: 1] integerValue];
    
    if (den == 0) {
        return num;
    } else {
        return (NSUInteger)roundf(num * 1.0f / den);
    }
}

@end
