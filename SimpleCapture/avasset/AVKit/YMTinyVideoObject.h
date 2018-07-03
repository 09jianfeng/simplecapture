//
//  YMTinyVideoObject.h
//  yymediarecordersdk
//
//  Created by 陈俊明 on 2017/10/16.
//  Copyright © 2018 yy.com. All rights reserved.
//

#ifndef YMTinyVideoObject_h
#define YMTinyVideoObject_h

#import <Foundation/Foundation.h>

/**
 通用hook方法
 
 若要实现对象判等功能，请实现isEqualToObject:方法并在其中对所有属性值进行判等
 */
@protocol YMTinyVideoObjectDelegate

@optional
- (BOOL)isEqualToObject:(id)object;

@end

/**
 sdk内增加序列化功能的object基类
 
 如果需要支持序列化，则子类的属性必须是基础数据类型、NSString、NSDictionary、NSArray以及YMTinyVideoObject的子类
 通过dict方法可获得该对象用于序列化的字典，通过initWithDict:方法可使用相应字典创建实例并还原属性值
 */
@interface YMTinyVideoObject : NSObject <YMTinyVideoObjectDelegate>

/**
 获取该类实例的所有readwrite的属性构成的字典，可用于NSJSONSerialization序列化

 @return 用于序列化的字典
 */
- (NSDictionary *)dict;

/**
 使用指定类实例的字典来创建指定类实例，并根据dict恢复其所有属性值

 @param dict 指定类实例的属性构成的字典
 @return 指定类的实例
 */
- (instancetype)initWithDict:(NSDictionary *)dict;

@end

#endif /* YMTinyVideoObject_h */
