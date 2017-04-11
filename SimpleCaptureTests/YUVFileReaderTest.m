//
//  YUVFileReaderTest.m
//  SimpleCapture
//
//  Created by JFChen on 17/3/27.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "YUVFileReader.h"

#define SLog(xx,args...) NSLog(@"%s"#xx,__PRETTY_FUNCTION__,##args)

@interface YUVFileReaderTest : XCTestCase

@end

@implementation YUVFileReaderTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDirGet {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    
    SLog(@"%@",[YUVFileReader documentPath]);
    SLog(@"%@",[YUVFileReader videoFilesPathInOri]);
    SLog(@"%@",[YUVFileReader videoFilesPathInTransform]);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
