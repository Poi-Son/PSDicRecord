//
//  PSBoolConvertor.m
//  PSExtensions
//
//  Created by PoiSon on 16/1/1.
//  Copyright © 2016年 yerl. All rights reserved.
//

#import "PSBoolConvertor.h"
#import "PSDicRecord_private.h"
#import <sqlite3.h>
#import <objc/runtime.h>

@interface PSBoolConvertor()
@property(nonatomic, assign) BOOL signature;
@end

@implementation PSBoolConvertor
- (NSString *)type{
    static NSString *_type = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        objc_property_t property = class_getProperty(self.class, "signature");
        char *type = property_copyAttributeValue(property, "T");
        _type = @(type);
        free((void *)type);
    });
    return _type;
}

- (Class)objcType{
    return NSNumber.class;
}

- (NSString *)dataType{
    return PSSQLiteTypeINTEGER;
}

- (NSMethodSignature *)setterSignature{
    return [self methodSignatureForSelector:@selector(setSignature:)];
}

- (NSMethodSignature *)getterSignature{
    return [self methodSignatureForSelector:@selector(signature)];
}

- (void)bindObject:(id)obj toColumn:(int)idx inStatement:(sqlite3_stmt *)statement{
    sqlite3_bind_int(statement, idx, [obj boolValue]);
}

- (id)getBuffer:(void *)buffer fromObject:(id)obj{
    returnValIf(obj == nil || [obj isEqual:[NSNull null]], nil);
    if ([obj isKindOfClass:[NSString class]]) {
        BOOL value = [obj boolValue];
        memcpy(buffer, &value, sizeof(BOOL));
        return [NSNumber numberWithBool:value];
    }else if ([obj isKindOfClass:[NSNumber class]]){
        BOOL value = [obj boolValue];
        memcpy(buffer, &value, sizeof(BOOL));
        return strcmp([obj objCType], @encode(BOOL)) == 0 ? nil : [NSNumber numberWithBool:value];
    }
    PSAssert(NO, @"can not conver <%@ %p>:%@ to BOOL", [obj class], obj, obj);
    return nil;
}

- (id)objectForBuffer:(void *)buffer{
    returnValIf(buffer == NULL, nil);
    BOOL value;
    memcpy(&value, buffer, sizeof(BOOL));
    return [NSNumber numberWithBool:value];
}
@end
