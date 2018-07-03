//
//  YMTinyVideoObject.m
//  yymediarecordersdk
//
//  Created by 陈俊明 on 2017/10/16.
//  Copyright © 2018 yy.com. All rights reserved.
//

#import "YMTinyVideoObject.h"
#import <objc/runtime.h>

@implementation YMTinyVideoObject

- (NSDictionary *)dict {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    Class class = [self class];
    while (![NSStringFromClass(class) isEqualToString:NSStringFromClass([YMTinyVideoObject class])]) {
        [self getPropertiesForClass:class toDict:&dict];
        class = [class superclass];
    }
    if (dict.count > 0) {
        return [dict copy];
    } else {
        return nil;
    }
}

- (void)getPropertiesForClass:(Class)class toDict:(NSMutableDictionary **)dict {
    id obj = objc_getClass([NSStringFromClass(class) UTF8String]);
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(obj, &propertyCount);
    
    for (unsigned int i = 0; i < propertyCount; ++i) {
        objc_property_t property = properties[i];
        NSString *propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        NSString *propertyAttr = [[NSString alloc] initWithCString:property_getAttributes(properties[i]) encoding:NSUTF8StringEncoding];
        BOOL isReadOnly = [[propertyAttr componentsSeparatedByString:@","] containsObject:@"R"];
        
        id actualValue;
        id value = [self valueForKey:propertyName];
        if ([value isKindOfClass:[NSArray class]]) {
            NSMutableArray *tmpArray = [NSMutableArray array];
            for (id obj in value) {
                id tmpValue;
                if ([obj isKindOfClass:[YMTinyVideoObject class]]) {
                    tmpValue = [(YMTinyVideoObject *)obj dict];
                    NSMutableDictionary *tmpDict = ((NSDictionary *)tmpValue).mutableCopy;
                    tmpDict[@"Name"] = NSStringFromClass([obj class]);
                    tmpValue = [tmpDict copy];
                } else {
                    tmpValue = obj;
                }
                if (tmpValue == nil) {
                    tmpValue = [NSNull null];
                }
                [tmpArray addObject:tmpValue];
            }
            actualValue = [tmpArray copy];
        } else {
            if ([value isKindOfClass:[YMTinyVideoObject class]]) {
                actualValue = [(YMTinyVideoObject *)value dict];
            } else {
                actualValue = value;
            }
        }
        
        if (!isReadOnly && [actualValue isKindOfClass:[NSNumber class]]) {
            if ([actualValue isEqualToNumber:[NSDecimalNumber notANumber]]) {
                NSLog(@"Detect NaN propertyName:%@, object:%@", propertyName, NSStringFromClass([self class]));
                actualValue = @(0);
            }
        }
        
        if (!isReadOnly && actualValue != nil) {
            [*dict setObject:actualValue forKey:propertyName];
        }
    }
    
    if (properties != NULL) {
        free(properties);
    }
}

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [self init];
    if (self != nil) {
        Class class = [self class];
        while (![NSStringFromClass(class) isEqualToString:NSStringFromClass([YMTinyVideoObject class])]) {
            [self setPropertiesForClass:class fromDict:dict];
            class = [class superclass];
        }
    }
    return self;
}

- (void)setPropertiesForClass:(Class)class fromDict:(NSDictionary *)dict {
    id obj = objc_getClass([NSStringFromClass(class) UTF8String]);
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(obj, &propertyCount);
    
    for (unsigned int i = 0; i < propertyCount; ++i) {
        NSString *propertyAttr = [[NSString alloc] initWithCString:property_getAttributes(properties[i]) encoding:NSUTF8StringEncoding];
        BOOL isReadOnly = [[propertyAttr componentsSeparatedByString:@","] containsObject:@"R"];
        
        const char *propertyTypeValue = property_copyAttributeValue(properties[i], "T");
        NSString *propertyType = [[NSString alloc] initWithCString:propertyTypeValue encoding:NSUTF8StringEncoding];
        propertyType = [propertyType stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@\""]];
        free((void *)propertyTypeValue);
        
        NSString *propertyName = [[NSString alloc] initWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        id value;
        
        if ([NSClassFromString(propertyType) isSubclassOfClass:[NSArray class]]) {
            NSMutableArray *tmpArray = [NSMutableArray array];
            for (id obj in dict[propertyName]) {
                id tmpValue;
                if ([obj isKindOfClass:[NSDictionary class]]) {
                    if ((NSDictionary *)obj[@"Name"] != nil) {
                        tmpValue = [[NSClassFromString(((NSDictionary *)obj)[@"Name"]) alloc] initWithDict:obj];
                    } else {
                        tmpValue = obj;
                    }
                } else {
                    tmpValue = obj;
                }
                [tmpArray addObject:tmpValue];
            }
            value = [tmpArray copy];
        } else {
            if ([NSClassFromString(propertyType) isSubclassOfClass:[YMTinyVideoObject class]]) {
                if (dict[propertyName] != nil) {
                    value = [[NSClassFromString(propertyType) alloc] initWithDict:dict[propertyName]];
                }
            } else {
                value = dict[propertyName];
            }
        }
        
        if (value != nil && ![value isEqual:[NSNull null]] && !isReadOnly) {
            [self setValue:value forKey:propertyName];
        }
    }
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    if (object == self) {
        return YES;
    }
    if (![object isMemberOfClass:[self class]]) {
        return NO;
    }
    if ([self respondsToSelector:@selector(isEqualToObject:)]) {
        return [self isEqualToObject:object];
    }
    return NO;
}

@end
