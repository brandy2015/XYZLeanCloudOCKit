//
//  LCIMConversationQuery.m
//  LeanCloudIM
//
//  Created by Qihe Bian on 2/3/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMConversationQuery_Internal.h"
#import "LCIMClient_Internal.h"
#import "LCIMClientInternalConversationManager.h"
#import "LCIMConversation_Internal.h"

#import "LCIMConversationCache.h"
#import "LCIMErrorUtil.h"

#import "LCUtils.h"
#import "LCObjectUtils.h"
#import "LCErrorUtils.h"

#import "AVIMGenericCommand+AVIMMessagesAdditions.h"

@implementation LCIMConversationQuery

+(NSDictionary *)dictionaryFromGeoPoint:(LCGeoPoint *)point {
    return @{ @"__type": @"GeoPoint", @"latitude": @(point.latitude), @"longitude": @(point.longitude) };
}

+(LCGeoPoint *)geoPointFromDictionary:(NSDictionary *)dict {
    LCGeoPoint * point = [[LCGeoPoint alloc]init];
    point.latitude = [[dict objectForKey:@"latitude"] doubleValue];
    point.longitude = [[dict objectForKey:@"longitude"] doubleValue];
    return point;
}

+ (instancetype)orQueryWithSubqueries:(NSArray<LCIMConversationQuery *> *)queries {
    LCIMConversationQuery *result = nil;
    
    if (queries.count > 0) {
        LCIMClient *client = [[queries firstObject] client];
        NSMutableArray *wheres = [[NSMutableArray alloc] initWithCapacity:queries.count];
        
        for (LCIMConversationQuery *query in queries) {
            NSString *eachClientId = query.client.clientId;
            
            if (!eachClientId || ![eachClientId isEqualToString:client.clientId]) {
                LCLoggerError(LCLoggerDomainIM, @"Invalid conversation query client id: %@.", eachClientId);
                return nil;
            }
            
            [wheres addObject:[query where]];
        }
        
        result = [client conversationQuery];
        result.where[@"$or"] = wheres;
    }
    
    return result;
}

+ (instancetype)andQueryWithSubqueries:(NSArray<LCIMConversationQuery *> *)queries {
    LCIMConversationQuery *result = nil;
    
    if (queries.count > 0) {
        LCIMClient *client = [[queries firstObject] client];
        NSMutableArray *wheres = [[NSMutableArray alloc] initWithCapacity:queries.count];
        
        for (LCIMConversationQuery *query in queries) {
            NSString *eachClientId = query.client.clientId;
            
            if (!eachClientId || ![eachClientId isEqualToString:client.clientId]) {
                LCLoggerError(LCLoggerDomainIM, @"Invalid conversation query client id: %@.", eachClientId);
                return nil;
            }
            
            [wheres addObject:[query where]];
        }
        
        result = [client conversationQuery];
        
        if (wheres.count > 1) {
            result.where[@"$and"] = wheres;
        } else {
            [result.where addEntriesFromDictionary:[wheres firstObject]];
        }
    }
    
    return result;
}

- (instancetype)init {
    if ((self = [super init])) {
        _where = [[NSMutableDictionary alloc] init];
        _cachePolicy = kLCIMCachePolicyCacheElseNetwork;
        _cacheMaxAge = 1 * 60 * 60; // an hour
    }
    return self;
}

- (NSString *)whereString {
    NSDictionary *dic = [LCObjectUtils dictionaryFromDictionary:self.where];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:NULL];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (void)addWhereItem:(NSDictionary *)dict forKey:(NSString *)key {
    if ([dict objectForKey:@"$eq"]) {
        if ([self.where objectForKey:@"$and"]) {
            NSMutableArray *eqArray = [self.where objectForKey:@"$and"];
            int removeIndex = -1;
            for (NSDictionary *eqDict in eqArray) {
                if ([eqDict objectForKey:key]) {
                    removeIndex = (int)[eqArray indexOfObject:eqDict];
                }
            }
            
            if (removeIndex >= 0) {
                [eqArray removeObjectAtIndex:removeIndex];
            }
            
            [eqArray addObject:@{key:[dict objectForKey:@"$eq"]}];
        } else {
            NSMutableArray *eqArray = [[NSMutableArray alloc] init];
            [eqArray addObject:@{key:[dict objectForKey:@"$eq"]}];
            [self.where setObject:eqArray forKey:@"$and"];
        }
    } else {
        if ([self.where objectForKey:key]) {
            [[self.where objectForKey:key] addEntriesFromDictionary:dict];
        } else {
            NSMutableDictionary *mutableDict = [[NSMutableDictionary alloc] initWithDictionary:dict];
            [self.where setObject:mutableDict forKey:key];
        }
    }
}

- (void)whereKeyExists:(NSString *)key
{
    NSDictionary * dict = @{@"$exists": [NSNumber numberWithBool:YES]};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKeyDoesNotExist:(NSString *)key
{
    NSDictionary * dict = @{@"$exists": [NSNumber numberWithBool:NO]};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key equalTo:(id)object
{
    [self addWhereItem:@{@"$eq":object} forKey:key];
}

- (void)whereKey:(NSString *)key sizeEqualTo:(NSUInteger)count
{
    [self addWhereItem:@{@"$size": [NSNumber numberWithUnsignedInteger:count]} forKey:key];
}


- (void)whereKey:(NSString *)key lessThan:(id)object
{
    NSDictionary * dict = @{@"$lt":object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key lessThanOrEqualTo:(id)object
{
    NSDictionary * dict = @{@"$lte":object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key greaterThan:(id)object
{
    NSDictionary * dict = @{@"$gt": object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key greaterThanOrEqualTo:(id)object
{
    NSDictionary * dict = @{@"$gte": object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key notEqualTo:(id)object
{
    NSDictionary * dict = @{@"$ne": object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key containedIn:(NSArray *)array
{
    NSDictionary * dict = @{@"$in": array };
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key notContainedIn:(NSArray *)array
{
    NSDictionary * dict = @{@"$nin": array };
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key containsAllObjectsInArray:(NSArray *)array
{
    NSDictionary * dict = @{@"$all": array };
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geopoint
{
    NSDictionary * dict = @{@"$nearSphere" : [[self class] dictionaryFromGeoPoint:geopoint]};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geopoint withinMiles:(double)maxDistance
{
    NSDictionary * dict = @{@"$nearSphere" : [[self class] dictionaryFromGeoPoint:geopoint], @"$maxDistanceInMiles":@(maxDistance)};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geopoint withinKilometers:(double)maxDistance
{
    NSDictionary * dict = @{@"$nearSphere" : [[self class] dictionaryFromGeoPoint:geopoint], @"$maxDistanceInKilometers":@(maxDistance)};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key nearGeoPoint:(LCGeoPoint *)geopoint withinRadians:(double)maxDistance
{
    NSDictionary * dict = @{@"$nearSphere" : [[self class] dictionaryFromGeoPoint:geopoint], @"$maxDistanceInRadians":@(maxDistance)};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key withinGeoBoxFromSouthwest:(LCGeoPoint *)southwest toNortheast:(LCGeoPoint *)northeast
{
    NSDictionary * dict = @{@"$within": @{@"$box" : @[[[self class] dictionaryFromGeoPoint:southwest], [[self class] dictionaryFromGeoPoint:northeast]]}};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex
{
    NSDictionary * dict = @{@"$regex": regex};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex modifiers:(NSString *)modifiers
{
    NSDictionary * dict = @{@"$regex":regex, @"$options":modifiers};
    [self addWhereItem:dict forKey:key];
}

/**
 * Converts a string into a regex that matches it.
 * Surrounding with \Q .. \E does this, we just need to escape \E's in
 * the text separately.
 */
static NSString * quote(NSString *string)
{
    NSString *replacedString = [string stringByReplacingOccurrencesOfString:@"\\E" withString:@"\\E\\\\E\\Q"];
    if (replacedString) {
        replacedString = [[@"\\Q" stringByAppendingString:replacedString] stringByAppendingString:@"\\E"];
    }
    return replacedString;
}

- (void)whereKey:(NSString *)key containsString:(NSString *)substring
{
    [self whereKey:key matchesRegex:[NSString stringWithFormat:@".*%@.*", quote(substring)]];
}

- (void)whereKey:(NSString *)key hasPrefix:(NSString *)prefix
{
    [self whereKey:key matchesRegex:[NSString stringWithFormat:@"^%@.*", quote(prefix)]];
}

- (void)whereKey:(NSString *)key hasSuffix:(NSString *)suffix
{
    [self whereKey:key matchesRegex:[NSString stringWithFormat:@".*%@$", quote(suffix)]];
}

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

- (void)getConversationById:(NSString *)conversationId
                   callback:(void (^)(LCIMConversation * _Nullable, NSError * _Nullable))callback
{
    [self whereKey:LCIMConversationKeyObjectId equalTo:conversationId];
    [self findConversationsWithCallback:^(NSArray<LCIMConversation *> * _Nullable conversations, NSError * _Nullable error) {
        if (error) {
            callback(nil, error);
            return;
        }
        if (!conversations.firstObject && self.cachePolicy != kLCIMCachePolicyCacheOnly) {
            callback(nil, ({
                LCIMErrorCode code = LCIMErrorCodeConversationNotFound;
                LCError(code, LCIMErrorMessage(code), nil);
            }));
            return;
        }
        callback(conversations.firstObject, nil);
    }];
}

- (void)findConversationsWithCallback:(void (^)(NSArray<LCIMConversation *> * _Nullable, NSError * _Nullable))callback
{
    LCIMClient *client = self.client;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Query;
        outCommand.convMessage = convCommand;
        
        if (self.order) {
            convCommand.sort = self.order;
        }
        if (self.option) {
            convCommand.flag = (int32_t)self.option;
        }
        if (self.skip) {
            convCommand.skip = (int32_t)self.skip;
        }
        if (self.limit > 0) {
            convCommand.limit = (int32_t)self.limit;
        } else {
            convCommand.limit = 10;
        }
        NSString *whereString = self.whereString;
        if (whereString) {
            AVIMJsonObjectMessage *jsonObjectMessage = [AVIMJsonObjectMessage new];
            convCommand.where = jsonObjectMessage;
            jsonObjectMessage.data_p = whereString;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            if (self.cachePolicy == kLCIMCachePolicyNetworkElseCache) {
                [self fetchCachedResultsForOutCommand:commandWrapper.outCommand client:client callback:^(NSArray *conversations) {
                    [client invokeInUserInteractQueue:^{
                        callback(conversations, nil);
                    }];
                }];
            } else {
                [client invokeInUserInteractQueue:^{
                    callback(nil, commandWrapper.error);
                }];
            }
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        AVIMJsonObjectMessage *jsonObjectMessage = (convCommand.hasResults ? convCommand.results : nil);
        NSString *jsonString = (jsonObjectMessage.hasData_p ? jsonObjectMessage.data_p : nil);
        
        NSMutableArray<NSMutableDictionary *> *results = ({
            NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            if (!data) {
                [client invokeInUserInteractQueue:^{
                    callback(nil, ({
                        LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                        LCError(code, LCIMErrorMessage(code), nil);
                    }));
                }];
                return;
            }
            NSError *error = nil;
            NSMutableArray<NSMutableDictionary *> *results = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
            if (error || ![NSMutableArray _lc_isTypeOf:results]) {
                [client invokeInUserInteractQueue:^{
                    callback(nil, error ?: ({
                        LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                        LCError(code, LCIMErrorMessage(code), nil);
                    }));
                }];
                return;
            }
            results;
        });
        
        NSMutableArray<LCIMConversation *> *conversations = ({
            NSMutableArray<LCIMConversation *> *conversations = [NSMutableArray array];
            for (NSMutableDictionary *jsonDic in results) {
                if (![NSMutableDictionary _lc_isTypeOf:jsonDic]) {
                    continue;
                }
                NSString *conversationId = [NSString _lc_decoding:jsonDic key:LCIMConversationKeyObjectId];
                if (!conversationId) {
                    continue;
                }
                LCIMConversation *conv = [client.conversationManager conversationForId:conversationId];
                if (conv) {
                    [conv setRawJSONData:jsonDic];
                    [conversations addObject:conv];
                } else {
                    conv = [LCIMConversation conversationWithRawJSONData:jsonDic client:client];
                    if (conv) {
                        [client.conversationManager insertConversation:conv];
                        [conversations addObject:conv];
                    }
                }
            }
            conversations;
        });
        
        if (self.cachePolicy != kLCIMCachePolicyIgnoreCache) {
            [client.conversationCache cacheConversations:conversations maxAge:self.cacheMaxAge forCommand:commandWrapper.outCommand.avim_conversationForCache];
        }
        
        [client invokeInUserInteractQueue:^{
            callback(conversations, nil);
        }];
    }];
    
    switch (self.cachePolicy)
    {
        case kLCIMCachePolicyIgnoreCache:
        case kLCIMCachePolicyNetworkOnly:
        case kLCIMCachePolicyNetworkElseCache:
        {
            [client sendCommandWrapper:commandWrapper];
        }break;
        case kLCIMCachePolicyCacheOnly:
        {
            [self fetchCachedResultsForOutCommand:commandWrapper.outCommand client:client callback:^(NSArray *conversations) {
                [client invokeInUserInteractQueue:^{
                    callback(conversations, nil);
                }];
            }];
        }break;
        case kLCIMCachePolicyCacheElseNetwork:
        {
            [self fetchCachedResultsForOutCommand:commandWrapper.outCommand client:client callback:^(NSArray *conversations) {
                if (conversations.count > 0) {
                    [client invokeInUserInteractQueue:^{
                        callback(conversations, nil);
                    }];
                } else {
                    [client sendCommandWrapper:commandWrapper];
                }
            }];
        }break;
        case kLCIMCachePolicyCacheThenNetwork:
        {   // issue
            [self fetchCachedResultsForOutCommand:commandWrapper.outCommand client:client callback:^(NSArray *conversations) {
                [client invokeInUserInteractQueue:^{
                    callback(conversations, nil);
                }];
                [client sendCommandWrapper:commandWrapper];
            }];
        }break;
        default: break;
    }
}

- (void)findTemporaryConversationsWith:(NSArray<NSString *> *)tempConvIds
                              callback:(void (^)(NSArray<LCIMTemporaryConversation *> * _Nullable, NSError * _Nullable))callback
{
    LCIMClient *client = self.client;
    if (!client) {
        return;
    }
    
    if (tempConvIds.count == 0) {
        [client invokeInUserInteractQueue:^{
            callback(@[], nil);
        }];
        return;
    }
    
    tempConvIds = ({
        NSMutableSet *set = [NSMutableSet setWithArray:tempConvIds];
        set.allObjects;
    });
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Query;
        outCommand.convMessage = convCommand;
        
        if (self.option) {
            convCommand.flag = (int32_t)self.option;
        }
        convCommand.limit = (int32_t)tempConvIds.count;
        convCommand.tempConvIdsArray = tempConvIds.mutableCopy;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(nil, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        AVIMJsonObjectMessage *jsonObjectMessage = (convCommand.hasResults ? convCommand.results : nil);
        NSString *jsonString = (jsonObjectMessage.hasData_p ? jsonObjectMessage.data_p : nil);
        
        NSMutableArray<NSMutableDictionary *> *results = ({
            NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            if (!data) {
                [client invokeInUserInteractQueue:^{
                    callback(nil, ({
                        LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                        LCError(code, LCIMErrorMessage(code), nil);
                    }));
                }];
                return;
            }
            NSError *error = nil;
            NSMutableArray<NSMutableDictionary *> *results = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
            if (error || ![NSMutableArray _lc_isTypeOf:results]) {
                [client invokeInUserInteractQueue:^{
                    callback(nil, error ?: ({
                        LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                        LCError(code, LCIMErrorMessage(code), nil);
                    }));
                }];
                return;
            }
            results;
        });
        
        NSArray<LCIMTemporaryConversation *> *conversations = ({
            NSMutableArray<LCIMTemporaryConversation *> *conversations = [NSMutableArray array];
            for (NSMutableDictionary *jsonDic in results) {
                if (![NSMutableDictionary _lc_isTypeOf:jsonDic]) {
                    continue;
                }
                NSString *conversationId = [NSString _lc_decoding:jsonDic key:LCIMConversationKeyObjectId];
                if (!conversationId) {
                    continue;
                }
                LCIMTemporaryConversation *tempConv = (LCIMTemporaryConversation *)[client.conversationManager conversationForId:conversationId];
                if (tempConv) {
                    [tempConv setRawJSONData:jsonDic];
                    [conversations addObject:tempConv];
                } else {
                    tempConv = [LCIMTemporaryConversation conversationWithRawJSONData:jsonDic client:client];
                    if (tempConv) {
                        [client.conversationManager insertConversation:tempConv];
                        [conversations addObject:tempConv];
                    }
                }
            }
            conversations;
        });
        
        [client invokeInUserInteractQueue:^{
            callback(conversations, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)fetchCachedResultsForOutCommand:(AVIMGenericCommand *)outCommand
                                 client:(LCIMClient *)client
                               callback:(void(^)(NSArray *conversations))callback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *conversations = [client.conversationCache conversationsForCommand:outCommand.avim_conversationForCache];
        [client addOperationToInternalSerialQueue:^(LCIMClient *client) {
            NSMutableArray *results = [NSMutableArray array];
            for (LCIMConversation *conv in conversations) {
                LCIMConversation *convInMemory = [client.conversationManager conversationForId:conv.conversationId];
                if (convInMemory) {
                    [results addObject:convInMemory];
                } else {
                    [results addObject:conv];
                    [client.conversationManager insertConversation:conv];
                }
            }
            callback(results);
        }];
    });
}

@end
