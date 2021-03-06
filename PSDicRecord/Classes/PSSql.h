//
//  PSSql.h
//  PSExtensions
//
//  Created by PoiSon on 15/10/22.
//  Copyright © 2015年 yerl. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface PSSql : NSObject
+ (instancetype)buildSql:(NSString *)sql, ...;
+ (instancetype)buildSql:(NSString *)sql withArgs:(NSArray<id> *)args;

@property (nonatomic, copy) NSString *sql;
@property (nonatomic, copy, nullable) NSArray<id> *args;
@end
NS_ASSUME_NONNULL_END