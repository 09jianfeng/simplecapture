//
//  FileChooseVC.h
//  SimpleCapture
//
//  Created by JFChen on 17/3/28.
//  Copyright © 2017年 duowan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FileChooseVC : UITableViewController

@property (nonatomic, strong) NSArray *dataSource;
@property (nonatomic, strong) NSString *chooseFileName;

@end
