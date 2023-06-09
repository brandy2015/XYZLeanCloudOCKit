//
//  LCSearchQuery.m
//  paas
//
//  Created by yang chaozhong on 5/30/14.
//  Copyright (c) 2014 LeanCloud. All rights reserved.
//

#import "LCSearchQuery.h"
#import "LCPaasClient.h"
#import "LCUtils_Internal.h"
#import "LCObject_Internal.h"
#import "LCObjectUtils.h"
#import "LCSearchSortBuilder.h"

@interface LCSearchQuery() {
    NSString *_searchPath;
}

@property (nonatomic, readwrite, strong) NSMutableDictionary *parameters;
@property (nonatomic, readwrite, strong) NSString *order;
@property (nonatomic, readwrite, strong) NSMutableSet *include;

@end

@implementation LCSearchQuery

- (NSMutableDictionary *)parameters {
    if (!_parameters) {
        _parameters = [NSMutableDictionary dictionary];
    }
    return _parameters;
}

+ (instancetype)searchWithQueryString:(NSString *)queryString {
    LCSearchQuery *searchQuery = [[[self class] alloc] initWithQueryString:queryString];
    
    return searchQuery;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _limit = 100;
        _searchPath = @"search/select";
        _include = [[NSMutableSet alloc] init];
    }

    return self;
}

- (instancetype)initWithQueryString:(NSString *)queryString {
    self = [self init];

    if (self) {
        _queryString = [queryString copy];
    }
    
    return self;
}

- (void)includeKey:(NSString *)key {
    [self.include addObject:[key copy]];
}

#pragma mark - Find methods
- (NSArray *)findObjects {
    return [self findObjects:NULL];
}


- (NSArray *)findObjects:(NSError **)error {
    return [self findObjectsWithBlock:NULL waitUntilDone:YES error:error];
}

- (NSArray *)findObjectsAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self findObjects:error];
}

- (void)findInBackground:(LCArrayResultBlock)resultBlock {
    [self findObjectsWithBlock:resultBlock waitUntilDone:NO error:NULL];
}


- (NSArray *)findObjectsWithBlock:(LCArrayResultBlock)resultBlock
                    waitUntilDone:(BOOL)wait
                            error:(NSError **)theError {

    if (wait) [self raiseSyncExceptionIfNeed];
    
    NSArray __block *theResultArray = nil;
    BOOL __block hasCalledBack = NO;
    NSError __block *blockError = nil;
    
    NSString *path = _searchPath;
    [self assembleParameters];
    
    [self queryWithBlock:path parameters:self.parameters block:^(NSArray *objects, NSError *error) {
        if (resultBlock) resultBlock(objects, error);
        
        if (wait) {
            blockError = error;
            theResultArray = objects;
            hasCalledBack = YES;
        }
    }];
    
    if (wait) {
        [LCUtils warnMainThreadIfNecessary];
        LC_WAIT_TIL_TRUE(hasCalledBack, 0.1);
    };
    
    if (theError != NULL) *theError = blockError;
    return theResultArray;
    
}

-(void)queryWithBlock:(NSString *)path
           parameters:(NSDictionary *)parameters
                block:(LCArrayResultBlock)resultBlock {
    
    [[LCPaasClient sharedInstance] getObject:path withParameters:parameters policy:self.cachePolicy maxCacheAge:self.maxCacheAge block:^(id object, NSError *error) {
        if (error == nil)
        {
            NSString *className = object[@"className"];
            NSArray *results = [object objectForKey:@"results"];
            NSMutableArray * array = [self processResults:results className:className];
            [LCUtils callArrayResultBlock:resultBlock array:array error:nil];
            
            self.sid = [object objectForKey:@"sid"];

            id hits = [object objectForKey:@"hits"];
            self->_hits = [hits respondsToSelector:@selector(integerValue)] ? [hits integerValue] : 0;
        }
        else
        {
            [LCUtils callArrayResultBlock:resultBlock array:nil error:error];
        }
    }];
}

#pragma mark - Sorting

- (void)orderByAscending:(NSString *)key
{
    self.order = [NSString stringWithFormat:@"%@", key];
}

- (void)addAscendingOrder:(NSString *)key
{
    if (self.order.length <= 0)
    {
        [self orderByAscending:key];
        return;
    }
    self.order = [NSString stringWithFormat:@"%@,%@", self.order, key];
}

- (void)orderByDescending:(NSString *)key
{
    self.order = [NSString stringWithFormat:@"-%@", key];
}

- (void)addDescendingOrder:(NSString *)key
{
    if (self.order.length <= 0)
    {
        [self orderByDescending:key];
        return;
    }
    self.order = [NSString stringWithFormat:@"%@,-%@", self.order, key];
}

- (void)orderBySortDescriptor:(NSSortDescriptor *)sortDescriptor
{
    NSString *symbol = sortDescriptor.ascending ? @"" : @"-";
    self.order = [symbol stringByAppendingString:sortDescriptor.key];
}

- (void)orderBySortDescriptors:(NSArray *)sortDescriptors
{
    if (sortDescriptors.count == 0) return;
    
    self.order = @"";
    for (NSSortDescriptor *sortDescriptor in sortDescriptors) {
        NSString *symbol = sortDescriptor.ascending ? @"" : @"-";
        if (self.order.length) {
            self.order = [NSString stringWithFormat:@"%@,%@%@", self.order, symbol, sortDescriptor.key];
        } else {
            self.order=[NSString stringWithFormat:@"%@%@", symbol, sortDescriptor.key];
        }
        
    }
}

- (NSMutableDictionary *)assembleParameters {
    [self.parameters removeAllObjects];
    
    if (self.className) {
        [self.parameters setObject:self.className forKey:@"clazz"];
    }

    if (self.skip > 0) {
        [self.parameters setObject:@(self.skip) forKey:@"skip"];
    }
    
    if (self.limit > 0) {
        [self.parameters setObject:@(self.limit) forKey:@"limit"];
    }
    
    if (self.queryString) {
        [self.parameters setObject:self.queryString forKey:@"q"];
    }
    
    if (self.sid) {
        [self.parameters setObject:self.sid forKey:@"sid"];
    }
    
    if (self.fields) {
        [self.parameters setObject:[self.fields componentsJoinedByString:@","] forKey:@"fields"];
    }
    
    if (self.order.length > 0)
    {
        [self.parameters setObject:self.order forKey:@"order"];
    }
    if (self.include.count > 0) {
        NSString *fields = [[self.include allObjects] componentsJoinedByString:@","];
        [self.parameters setObject:fields forKey:@"include"];
    }
    
    if (self.sortBuilder) {
        NSError *error;
        NSData *data = [NSJSONSerialization dataWithJSONObject:self.sortBuilder.sortFields options:0 error:&error];
        if (!error) {
            [self.parameters setObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] forKey:@"sort"];
        }
    }
    
    if (self.highlights) {
        [self.parameters setObject:self.highlights forKey:@"highlights"];
    }
    return self.parameters;
}

- (NSMutableArray *)processResults:(NSArray *)results className:(NSString *)className {
    if (className == nil) {
        className = self.className;
    }

    NSMutableArray * array = [[NSMutableArray alloc] init];

    for(NSDictionary * dict in results)
    {
        LCObject *object;
        if (className) {
            object = [LCObjectUtils lcObjectForClass:className];
        } else {
            object = [LCObject objectWithClassName:@"SearchQuery"];
        }
        [LCObjectUtils copyDictionary:dict toObject:object];
        [array addObject:object];
    }
    return array;
}

#pragma mark - Util methods
- (void)raiseSyncExceptionIfNeed {
    if (self.cachePolicy == kLCCachePolicyCacheThenNetwork) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"kLCCachePolicyCacheThenNetwork can't not use in sync methods"];
    };
}

@end
