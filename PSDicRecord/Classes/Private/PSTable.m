//
//  PSTable.m
//  PSExtensions
//
//  Created by PoiSon on 15/9/28.
//  Copyright © 2015年 yerl. All rights reserved.
//

#import "PSDicRecord_private.h"
#import <objc/runtime.h>

@implementation PSTable{
    NSMutableSet<NSString *> *_column_names;
    NSArray<PSColumn *> *_cols;
    NSMapTable<NSString *, PSColumn *> *_columnMappings;
}
/** 获取objc_property_t的属性值 */
NSString *property_getAttrValue(objc_property_t property, const char *attributeName){
    const char *type = property_copyAttributeValue(property, attributeName);
    if (type == NULL) {
        return nil;
    }
    @try {
        return @(type);
    }
    @finally {
        free((void *)type);
    }
}

+ (instancetype)buildTableWithModel:(Class)model{
    PSParameterAssert([model isSubclassOfClass:PSModel.class]);
    PSTable *table = [PSTable new];
    
    NSMutableArray<PSColumn *> *columns = [NSMutableArray array];
    
    //add ID column to table
    PSColumn *column = [PSColumn new];
    column.name = @"ID";
    column.type = @(@encode(NSInteger));
    [columns addObject:column];
    
    uint count;
    objc_property_t *properties = class_copyPropertyList(model, &count);
    for (uint i = 0; i < count; i ++) {
        objc_property_t property = properties[i];
        NSString *name = @(property_getName(property));
        
        BOOL isDynamic = property_getAttrValue(property, "D") != nil;
        
        //dynamic property is for mapping
        continueIf(!isDynamic);
        
        PSColumn *column = [PSColumn new];
        column.name = name;
        column.type = property_getAttrValue(property, "T");
        [columns addObject:column];
    }
    free(properties);
    
    table.cols = columns;
    [table putValue:[model tableName] forKey:@"name"];
    [table putValue:model forKey:@"type"];
    [table putValue:@"ID" forKey:@"key"];
    [table putValue:@([model version]) forKey:@"version"];
    return table;
}

- (NSArray<PSColumn *> *)cols{
    return _cols ?: (_cols = ({
        NSArray<PSColumn *> * cols;
        NSString *columnsStr = [self stringValueForKey:@"columns"];
        if (columnsStr.length) {
            NSArray<NSDictionary<NSString *, NSString *> *> *colsDic = [NSJSONSerialization JSONObjectWithData:[columnsStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
            cols = (colsDic == nil) ? nil : ({
                NSMutableArray *array = [NSMutableArray new];
                for (NSDictionary<NSString *, NSString *> *dic in colsDic) {
                    [array addObject:[[PSColumn alloc] initWithAttributes:dic]];
                }
                array;
            });
        }else{
            cols = nil;
        }
        cols;
    }));
}

- (void)setCols:(NSArray<PSColumn *> *)cols{
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *colsDic = [NSMutableArray new];
    for (PSColumn *column in cols) {
        [colsDic addObject:column.attributes];
    }
    
    NSData *colData = [NSJSONSerialization dataWithJSONObject:colsDic options:kNilOptions error:nil];
    [self setValue:[[NSString alloc] initWithData:colData encoding:NSUTF8StringEncoding] forKey:@"columns"];
    
    _cols = cols;
}

- (NSMapTable<NSString *, PSColumn *> *)columnMappings{
    return _columnMappings ?: ({
        _columnMappings = [NSMapTable strongToWeakObjectsMapTable];
        for (PSColumn *column in self.cols) {
            [_columnMappings setObject:column forKey:[column name].lowercaseString];
        }
        _columnMappings;
    });
}

- (PSColumn *)columnForName:(NSString *)name{
    return [self.columnMappings objectForKey:name.lowercaseString];
}

- (BOOL)hasColumn:(NSString *)column{
    return [self.columnNames containsObject:column.lowercaseString];
}

- (NSMutableSet<NSString *> *)columnNames{
    return _column_names ?: ({
        _column_names = [NSMutableSet new];
        for (PSColumn *column in self.cols) {
            [_column_names addObject:column.name.lowercaseString];
        }
        _column_names;
    });
}

#pragma mark - Configuration
@dynamic name;
@dynamic type;
@dynamic key;
@dynamic columns;
@dynamic version;

+ (NSString *)tableName{
    return @"PS_Dic_Record_Config";
}

- (NSString *)description{
    return [NSString stringWithFormat:@"<PSTable %p>:\n{\n   ID : %@,\n   name : %@,\n   type : %@,\n   key : %@,\n   version : %@,\n   columns : %@\n}", self, self[@"ID"], self[@"name"], self[@"type"], self[@"key"], self[@"version"], self.cols];
}

- (NSString *)debugDescription{
    return [NSString stringWithFormat:@"<PSTable %p>:\n{\n   ID : %@,\n   name : %@,\n   type : %@,\n   key : %@,\n   version : %@,\n   columns : %@\n}", self, self[@"ID"], self[@"name"], self[@"type"], self[@"key"], self[@"version"], self.cols];
}
@end
