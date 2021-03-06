//
//  PSDatabase.m
//  PSExtensions
//
//  Created by PoiSon on 15/9/28.
//  Copyright © 2015年 yerl. All rights reserved.
//

#import "PSDicRecord_private.h"

@interface PSModel()
@property (nonatomic, strong) id<PSSetProtocol> modifyFlag;
@property (nonatomic, strong, readonly) PSTable *table;
@property (nonatomic, strong, readonly) PSDbConfig *config;
@property (nonatomic, strong, readonly) NSString *configName;
@end

@implementation PSModel{
    PSTable *_table;
    NSString *_configName;
}
@dynamic ID;

+ (instancetype)dao{
    //cache daos
    static NSMutableDictionary<NSString *, PSModel *> *daoMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        daoMap = [NSMutableDictionary new];
    });
    @synchronized(self) {
        PSModel *dao = [daoMap objectForKey:NSStringFromClass([self class])];
        if (dao == nil) {
            dao = [[self alloc] init];
            [daoMap setObject:dao forKey:NSStringFromClass(self.class)];
        }
        return dao;
    }
}

+ (instancetype)modelWithAttributes:(NSDictionary<NSString *, id> *)attrs{
    return [[self alloc] initWithAttributes:attrs];
}

- (instancetype)use:(NSString *)configName{
    _configName = [configName copy];
    return self;
}

- (NSString *)configName{
    NSString *transaction_config = [NSThread currentThread].threadDictionary[PSDICRECORD_THREAD_TRANSACTION_CONFIG];
    if (transaction_config) {
        return transaction_config;
    }else{
        return _configName;
    }
}

- (PSDbConfig *)config{
    PSDbConfig *config;
    if (self.configName) {
        config = [PSDbKit configForName:self.configName];
        PSAssert(config, @"can not find config named: %@", self.configName);
    }else{
        config = [PSDbKit configForModel:self.class];
    }
    if (!config) {
        config = [PSDbKit brokenConfig];
    }
    return config;
}

- (PSTable *)table{
    returnValIf(_table, _table);
    _table = [PSDbKit tableForModel:self.class];
    
    returnValIf(_table, _table);
    
    static NSMutableDictionary *__table_cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __table_cache = [NSMutableDictionary new];
    });
    
    PSTable *table = [__table_cache objectForKey:NSStringFromClass(self.class)];
    returnValIf(_table, _table);
    
    table = [PSTable buildTableWithModel:self.class];
    [__table_cache setObject:table forKey:NSStringFromClass(self.class)];
    return table;
}

#pragma mark - Getter/Setter
- (id<PSSetProtocol>)modifyFlag{
    return _modifyFlag ?: ({_modifyFlag = [self.config.containerFactory createSet];});
}

- (void)setValue:(id)value forKey:(NSString *)aKey{
    if (!value) {
        [self removeValueForKey:aKey];
        return;
    }
    [self.modifyFlag addValue:aKey];
    [super setValue:value forKey:aKey];
}

- (void)setDictionary:(NSDictionary<NSString *,id> *)aDictionary{
    [super setDictionary:aDictionary];
}

- (void)putValue:(id)anObject forKey:(NSString *)aKey{
    [super setValue:anObject forKey:aKey];
}

- (void)putDictionary:(NSDictionary<NSString *, id> *)aDictionary{
    [super setDictionary:aDictionary];
}

- (void)removeValueForKey:(NSString *)aKey{
    [self.modifyFlag removeValue:aKey];
    [super removeValueForKey:aKey];
}

- (void)removeAllValues{
    [self.modifyFlag removeAllValues];
    [super removeAllValues];
}

#pragma mark - dynamic property getter/setter
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector{
    NSString *property = NSStringFromSelector(aSelector);
    BOOL isSetter = [property hasPrefix:@"set"];
    if (isSetter) {
        property = [property substringFromIndex:3];
        property = [property substringToIndex:property.length - 1];
    }
    
    PSColumn *column = [self.table columnForName:property];
    
    if (column) {
        return isSetter ? column.convertor.setterSignature : column.convertor.getterSignature;
    }else{
        return [super methodSignatureForSelector:aSelector];
    }
}

- (id)forwardingTargetForSelector:(SEL)aSelector{
    return self;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation{
    NSString *property = NSStringFromSelector(anInvocation.selector);
    BOOL isSetter = [property hasPrefix:@"set"];
    if (isSetter) {
        property = [property substringFromIndex:3];
        property = [property substringToIndex:property.length - 1];
    }
    
    PSColumn *column = [self.table columnForName:property];
    
    if (column) {
        if (isSetter) {
            void *buffer = calloc(1, anInvocation.methodSignature.frameLength);
            [anInvocation getArgument:buffer atIndex:2];
            
            id value = [column.convertor objectForBuffer:buffer];
            [self setValue:value forKey:column.name];
            free(buffer);
        }else{
            void *buffer = calloc(1, anInvocation.methodSignature.methodReturnLength);
            
            id value = [self valueForKey:column.name];
            // property value revise
            id newValue = [column.convertor getBuffer:buffer fromObject:value];
            doIf(newValue, [self putValue:newValue forKey:column.name]);
            
            [anInvocation setReturnValue:buffer];
            doIf(![anInvocation argumentsRetained], [anInvocation retainArguments]);
            free(buffer);
        }
    }else{
        [super forwardInvocation:anInvocation];
    }
}

- (id)objectForKeyedSubscript:(NSString *)key{
    return [self valueForKey:key];
}
@end

#pragma mark - implementation of Operation
@implementation PSModel(Operation)
- (BOOL)save{
    PSDbConnection *conn = [self.config getOpenedConnection];
    @try {
        PSDbStatement *statment = [conn prepareStatement:[PSSqlBuilder forSave:self.table attrs:self->_attrs]];
        BOOL result = [statment executeUpdate];
        if (!result) {
            NSLog(conn.lastErrorMessage, nil);
        }else{
            [self putValue:@([statment generatedKey]) forKey:self.table.key];
        }
        return result;
    }
    @finally {
        [self.config close:conn];
    }
}

- (BOOL)update{
    returnValIf(self.modifyFlag.count < 1, YES);
    returnValIf(self.modifyFlag.count == 1 && [self.modifyFlag contains:@"ID"], YES);
    
    id idValue = [self valueForKey:self.table.key];
    PSAssert(idValue && [idValue integerValue] > 0, @"You can't update model without Primary Key");
    
    PSSql *updateSql = [PSSqlBuilder forUpdate:self.table attrs:self->_attrs modifyFlag:[self.modifyFlag toSet]];
    return [self updateWithSql:updateSql];
}

- (BOOL)updateAll{
    [self.modifyFlag addValuesFormArray:[self allKeys]];
    return [self update];
}

- (BOOL)saveOrUpdate{
    PSSql *sql = [PSSqlBuilder forReplace:self.table attrs:self->_attrs];
    return [self updateWithSql:sql];
}

- (BOOL)delete{
    PSAssert([self valueForKey:self.table.key], @"You can't delete model without primary key value");
    return [self deleteById:self.ID];
}

- (BOOL)deleteById:(NSInteger)idValue{
    PSParameterAssert(idValue > 0);
    PSSql *deleteSql = [PSSqlBuilder forDelete:self.table byCondition:@"ID = ?" withArgs:@[@(idValue)]];
    return [self updateWithSql:deleteSql];
}

- (BOOL)deleteByCondition:(NSString *)condition, ...{
    PSParameterAssert(condition != nil && condition.length > 0);
    PSSql *deleteSql = [PSSqlBuilder forDelete:self.table byCondition:condition withArgs:va_array(condition)];
    return [self updateWithSql:deleteSql];
}

- (BOOL)deleteAll{
    return [self updateWithSql:[PSSqlBuilder forDelete:self.table byCondition:@"1 = 1" withArgs:nil]];
}

- (NSInteger)count{
    return [self countByCondition:@"1 = 1"];
}

- (NSInteger)countByCondition:(NSString *)condition, ...{
    NSNumber *num = [self queryOneWithSql:[PSSqlBuilder forRowCount:self.table byCondition:condition withArgs:va_array(condition)]];
    return [num integerValue];
}

#pragma mark - Update Models
- (BOOL)update:(NSString *)sql, ...{
    return [self updateWithSql:[PSSql buildSql:sql withArgs:va_array(sql)]];
}

- (BOOL)updateWithSql:(PSSql *)sql{
    PSDbConnection *conn = [self.config getOpenedConnection];
    @try {
        return [[conn prepareStatement:sql] executeUpdate];
    }
    @finally {
        [self.config close:conn];
    }
}

#pragma mark - Find Models
- (NSArray *)findWithSql:(PSSql *)sql{
    PSDbConnection *conn = [self.config getOpenedConnection];
    @try {
        PSQueryResultSet *resultSet = [[conn prepareStatement:sql] executeQuery];
        NSMutableArray<PSModel *> *results = [NSMutableArray new];
        for (NSDictionary<NSString *, id> *attrs in resultSet) {
            id item = [[self.class alloc] initWithAttributes:attrs];
            [results addObject:item];
        }
        return results;
    }
    @finally {
        [self.config close:conn];
    }
}

- (NSArray *)find:(NSString *)sql, ...{
    return [self findWithSql:[PSSql buildSql:sql withArgs:va_array(sql)]];
}

- (NSArray *)findByCondition:(NSString *)condition, ...{
    PSSql *sql = [PSSqlBuilder forFind:self.table columns:@"*" byCondition:condition withArgs:va_array(condition)];
    return [self findWithSql:sql];
}

- (id)findFirstByCondition:(NSString *)condition, ...{
    PSSql *sql = [PSSqlBuilder forFind:self.table columns:@"*" byCondition:condition withArgs:va_array(condition)];
    NSArray *result = [self findWithSql:sql];
    returnValIf(result.count, result[0]);
    return nil;
}

- (NSArray *)findAll{
    PSSql *sql = [PSSqlBuilder forFind:self.table columns:nil byCondition:nil withArgs:nil];
    return [self findWithSql:sql];
}

- (id)findById:(NSInteger)idValue{
    PSParameterAssert(idValue > 0);
    PSSql *sql = [PSSqlBuilder forFind:self.table columns:@"*" byCondition:@"ID = ?" withArgs:@[@(idValue)]];
    return [self findFirstWithSql:sql];
}

- (id)findById:(NSInteger)idValue loadColumns:(NSString *)columns{
    PSParameterAssert(idValue > 0);
    PSSql *sql = [PSSqlBuilder forFind:self.table columns:columns byCondition:@"ID = ?" withArgs:@[@(idValue)]];
    return [self findFirstWithSql:sql];
}

- (id)findFirst:(NSString *)sql, ...{
    NSArray *result = [self findWithSql:[PSSql buildSql:sql withArgs:va_array(sql)]];
    returnValIf([result count], result[0]);
    return nil;
}

- (id)findFirstWithSql:(PSSql *)sql{
    NSArray *result = [self findWithSql:sql];
    returnValIf(result.count, result[0]);
    return nil;
}

- (id)queryOneWithSql:(PSSql *)sql{
    PSDbConnection *conn = [self.config getOpenedConnection];
    @try {
        PSQueryResultSet *result = [[conn prepareStatement:sql] executeQuery];
        returnValIf(result.count < 1, nil);
        
        PSQueryResult *item = [result objectAtIndex:0];
        NSArray *keys = [item allKeys];
        PSAssert(keys.count > 0, @"No columns was queried.");
        PSAssert(keys.count < 2, @"Only ONE column can be queried.");
        return [item objectForKey:[keys objectAtIndex:0]];
    }
    @finally {
        [self.config close:conn];
    }
}

- (id)queryOne:(NSString *)sql, ...{
    return [self queryOneWithSql:[PSSql buildSql:sql withArgs:va_array(sql)]];
}


- (PSPage *)paginate:(NSInteger)pageIndex size:(NSInteger)pageSize withSelect:(NSString *)select where:(NSString *)where, ...{
    PSParameterAssert(pageIndex > 0 && pageSize > 0);
    NSInteger total;
    {
        total = [[self queryOneWithSql:[PSSql buildSql:[@"select count(1) " stringByAppendingString:where] withArgs:va_array(where)]] integerValue];
        returnValIf(total < 1, [PSPage pageWithArray:[NSArray new] index:0 size:0 total:0]);
    }
    
    PSSql *sql = [PSSqlBuilder forPaginateIndex:pageIndex size:pageSize withSelect:select where:where args:va_array(where)];
    NSArray<PSModel *> *result = [self findWithSql:sql];
    return [PSPage pageWithArray:result index:pageIndex size:pageSize total:total];
}
@end

@implementation PSModel (Sql)
- (PSSql *)saveSql{
    return [PSSqlBuilder forSave:self.table attrs:self->_attrs];
}

- (PSSql *)updateSql{
    PSAssert([self valueForKey:self.table.key], @"You can't update model without primary key value");
    return [PSSqlBuilder forUpdate:self.table attrs:self->_attrs modifyFlag:self.modifyFlag.toSet];
}

- (PSSql *)deleteSql{
    PSAssert([self valueForKey:self.table.key], @"You can't delete model without primary key value");
    return [PSSqlBuilder forDelete:self.table byCondition:@"ID = ?" withArgs:@[@(self.ID)]];
}

@end

#pragma mark - implementation of Configuration
@implementation PSModel(Configuration)
+ (NSString *)tableName{
    return NSStringFromClass([self class]);
}

+ (NSInteger)version{
    return 1;
}

+ (NSString *)propertyForColumn:(NSString *)column{
    return nil;
}

+ (NSArray<PSSql *> *)migrateForm:(NSInteger)oldVersion to:(NSInteger)newVersion{
    return nil;
}
@end
