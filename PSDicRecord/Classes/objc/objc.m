//
//  objc.m
//  PSDicRecord
//
//  Created by yan on 16/2/7.
//  Copyright © 2016年 PoiSon. All rights reserved.
//

#import "objc.h"
#import <libkern/OSAtomic.h>

void sql_printf(NSString *format, ...){
    static OSSpinLock aspect_lock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&aspect_lock);
    
    __block va_list params;
    va_start(params, format);
    printf([[NSString alloc] initWithFormat:[format stringByAppendingString:@"\n"] arguments:params].UTF8String, NULL);
    va_end(params);
    
    OSSpinLockUnlock(&aspect_lock);
}
