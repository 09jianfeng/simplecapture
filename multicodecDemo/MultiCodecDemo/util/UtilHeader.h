//
//  UtilHeader.h
//  MultiCodecDemo
//
//  Created by JFChen on 2019/4/28.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSMutableArray *GloballogArray;
extern int GlobalLogArrayCount;
extern const int GlobalLogMax;

#define AudioLog(xx,...) GlobalLogArrayCount++;GloballogArray[GlobalLogArrayCount%GlobalLogMax] =[NSString stringWithFormat:xx@"\n",##__VA_ARGS__]; NSLog(xx,##__VA_ARGS__);

@interface UtilHeader : NSObject

@end
