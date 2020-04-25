//
//  UtilHeader.m
//  MultiCodecDemo
//
//  Created by JFChen on 2019/4/28.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import "UtilHeader.h"

int GlobalLogArrayCount = 0;
const int GlobalLogMax = 10000;
NSMutableArray *GloballogArray;

@implementation UtilHeader

- (void)test{
    GlobalLogArrayCount++;GloballogArray[GlobalLogArrayCount%GlobalLogMax] = @"";
}

@end
