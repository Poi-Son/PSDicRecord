//
//  PSPage.h
//  PSExtensions
//
//  Created by PoiSon on 15/9/29.
//  Copyright © 2015年 yerl. All rights reserved.
//

#import <Foundation/Foundation.h>
/**
 * PSPage is the result of PSModel.paginate(......) or PSDbPro.paginate(......)
 */
@interface PSPage<M> : NSObject
@property (nonatomic, strong, nonnull, readonly) NSArray<M> *list;
@property (nonatomic, assign, readonly) NSInteger pageIndex;
@property (nonatomic, assign, readonly) NSInteger pageSize;
@property (nonatomic, assign, readonly) NSInteger totalPage;
@property (nonatomic, assign, readonly) NSInteger totalRow;

+ (nonnull instancetype)pageWithArray:(nonnull NSArray<M> *)list index:(NSInteger)pageIndex size:(NSInteger)pageSize total:(NSInteger)totalRow;
@end
