//
//  LCIMClientInternalConversationManager.m
//  LeanCloud
//
//  Created by zapcannon87 on 2018/7/18.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "LCIMClientInternalConversationManager.h"
#import "LCIMClient_Internal.h"
#import "LCIMConversation_Internal.h"
#import "LCIMErrorUtil.h"
#import "LCErrorUtils.h"
#import "LCUtils.h"
#import "LCIMConversationCache.h"
#import "AVIMGenericCommand+AVIMMessagesAdditions.h"

static NSUInteger batchQueryLimit = 100;

@implementation LCIMClientInternalConversationManager

- (instancetype)initWithClient:(LCIMClient *)client
{
    self = [super init];
    if (self) {
        self->_client = client;
        self->_conversationMap = [NSMutableDictionary dictionary];
        self->_callbacksMap = [NSMutableDictionary dictionary];
#if DEBUG
        self->_internalSerialQueue = client.internalSerialQueue;
#endif
    }
    return self;
}

- (void)insertConversation:(LCIMConversation *)conversation
{
    AssertRunInQueue(self.internalSerialQueue);
    NSParameterAssert(conversation);
    NSParameterAssert(conversation.conversationId);
    self.conversationMap[conversation.conversationId] = conversation;
}

- (LCIMConversation *)conversationForId:(NSString *)conversationId
{
    AssertRunInQueue(self.internalSerialQueue);
    NSParameterAssert(conversationId);
    return self.conversationMap[conversationId];
}

- (void)removeConversationsWithIds:(NSArray<NSString *> *)conversationIds
{
    AssertRunInQueue(self.internalSerialQueue);
    NSParameterAssert(conversationIds);
    [self.conversationMap removeObjectsForKeys:conversationIds];
}

- (void)removeAllConversations
{
    AssertRunInQueue(self.internalSerialQueue);
    [self.conversationMap removeAllObjects];
}

- (void)queryConversationWithId:(NSString *)conversationId
                       callback:(void (^)(LCIMConversation *conversation, NSError *error))callback
{
    AssertRunInQueue(self.internalSerialQueue);
    NSParameterAssert(conversationId);
    [self queryConversationsWithIds:@[conversationId] callback:callback];
}

- (void)queryConversationsWithIds:(NSArray<NSString *> *)conversationIds
                         callback:(void (^)(LCIMConversation *conversation, NSError *error))callback
{
    AssertRunInQueue(self.internalSerialQueue);
    NSParameterAssert(conversationIds);
    
    LCIMClient *client = self.client;
    
    NSMutableArray<NSArray *> *tupleArray = [self slicingConversationIds:conversationIds callback:callback];
    
    for (NSArray *tuple in tupleArray) {
        
        /// @note
        /// tuple[0] is bool flag, means whether conversationIds are Temporary Conversation's ID.
        /// tuple[1] is array value, it is conversation's IDs.
        BOOL isTemporary = ((NSNumber *)(tuple[0])).boolValue;
        NSArray<NSString *> *batchIds = ((NSArray<NSString *> *)(tuple[1]));
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            NSError *error = nil;
            LCIMProtobufCommandWrapper *commandWrapper = [self newQueryCommandWrapperWithIds:batchIds isTemporary:isTemporary error:&error];
            if (error) {
                LCLoggerError(LCLoggerDomainIM, @"Error: %@ for querying ids: %@", error, batchIds);
                callback(nil, error);
                return;
            }
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                LCLoggerError(LCLoggerDomainIM, @"Error: %@ for querying ids: %@", commandWrapper.error, batchIds);
                for (NSString *convId in batchIds) {
                    [self invokeCallbacksWithId:convId conversation:nil error:commandWrapper.error];
                }
                return;
            }
            
            NSMutableArray<NSMutableDictionary *> *queryResults = ({
                NSError *error = nil;
                NSMutableArray<NSMutableDictionary *> *queryResults = [self queryResultsFrom:commandWrapper.inCommand error:&error];
                if (error) {
                    LCLoggerError(LCLoggerDomainIM, @"%@", error);
                    for (NSString *convId in batchIds) {
                        [self invokeCallbacksWithId:convId conversation:nil error:error];
                    }
                    return;
                }
                queryResults;
            });
            
            NSMutableArray<NSString *> *remainingIds = batchIds.mutableCopy;
            
            for (NSMutableDictionary *rawJSONData in queryResults) {
                if (![NSMutableDictionary _lc_isTypeOf:rawJSONData]) {
                    continue;
                }
                NSString *conversationId = [NSString _lc_decoding:rawJSONData key:LCIMConversationKeyObjectId];
                if (!conversationId) {
                    continue;
                }
                LCIMConversation *conversation = [self conversationForId:conversationId];
                if (conversation) {
                    [conversation setRawJSONData:rawJSONData];
                } else {
                    conversation = [LCIMConversation conversationWithRawJSONData:rawJSONData client:client];
                    if (conversation) {
                        [self insertConversation:conversation];
                    } else {
                        NSError *error = ({
                            LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                            LCError(code, LCIMErrorMessage(code), nil);
                        });
                        LCLoggerError(LCLoggerDomainIM, @"%@", error);
                        [self invokeCallbacksWithId:conversationId conversation:nil error:error];
                        continue;
                    }
                }
                if (!isTemporary) {
                    [client.conversationCache cacheConversations:@[conversation] maxAge:3600 forCommand:commandWrapper.outCommand.avim_conversationForCache];
                }
                [remainingIds removeObject:conversationId];
                [self invokeCallbacksWithId:conversationId conversation:conversation error:nil];
            }
            
            for (NSString *convId in remainingIds) {
                NSError *error = ({
                    LCIMErrorCode code = LCIMErrorCodeConversationNotFound;
                    LCError(code, LCIMErrorMessage(code), nil);
                });
                [self invokeCallbacksWithId:convId conversation:nil error:error];
            }
        }];
        
        for (NSString *convId in batchIds) {
            self.callbacksMap[convId] = [NSMutableArray arrayWithObject:callback];
        }
        [client sendCommandWrapper:commandWrapper];
    }
}

- (NSMutableArray<NSArray *> *)slicingConversationIds:(NSArray<NSString *> *)conversationIds
                                             callback:(void (^)(LCIMConversation *conversation, NSError *error))callback
{
    NSMutableArray<NSString *> *normalIds = [NSMutableArray array];
    NSMutableArray<NSString *> *temporaryIds = [NSMutableArray array];
    for (NSString *conversationId in conversationIds) {
        LCIMConversation *conversation = [self conversationForId:conversationId];
        if (conversation) {
            callback(conversation, nil);
        } else {
            NSMutableArray<void (^)(LCIMConversation *, NSError *)> *callbacks = self.callbacksMap[conversationId];
            if (callbacks) {
                [callbacks addObject:callback];
            } else {
                if ([conversationId hasPrefix:kTemporaryConversationIdPrefix]) {
                    [temporaryIds addObject:conversationId];
                } else {
                    [normalIds addObject:conversationId];
                }
            }
        }
    }
    NSMutableArray<NSArray *> *tupleArray = [NSMutableArray array];
    while (normalIds.count > batchQueryLimit) {
        NSRange range = NSMakeRange(0, batchQueryLimit);
        NSArray<NSString *> *ids = [normalIds subarrayWithRange:range];
        [normalIds removeObjectsInRange:range];
        [tupleArray addObject:@[@(false), ids]];
    }
    if (normalIds.count > 0) {
        [tupleArray addObject:@[@(false), normalIds.copy]];
    }
    while (temporaryIds.count > batchQueryLimit) {
        NSRange range = NSMakeRange(0, batchQueryLimit);
        NSArray<NSString *> *ids = [temporaryIds subarrayWithRange:range];
        [temporaryIds removeObjectsInRange:range];
        [tupleArray addObject:@[@(true), ids]];
    }
    if (temporaryIds.count > 0) {
        [tupleArray addObject:@[@(true), temporaryIds.copy]];
    }
    return tupleArray;
}

- (LCIMProtobufCommandWrapper *)newQueryCommandWrapperWithIds:(NSArray<NSString *> *)conversationIds
                                                  isTemporary:(BOOL)isTemporary
                                                        error:(NSError * __autoreleasing *)error
{
    AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
    AVIMConvCommand *convCommand = [AVIMConvCommand new];
    outCommand.cmd = AVIMCommandType_Conv;
    outCommand.op = AVIMOpType_Query;
    outCommand.convMessage = convCommand;
    convCommand.limit = (int32_t)conversationIds.count;
    if (isTemporary) {
        convCommand.tempConvIdsArray = conversationIds.mutableCopy;
    } else {
        convCommand.where = ({
            id JSONObject = nil;
            if (conversationIds.count == 1) {
                JSONObject = @{ LCIMConversationKeyObjectId: conversationIds.firstObject };
            } else {
                JSONObject = @{ LCIMConversationKeyObjectId: @{ @"$in": conversationIds } };
            }
            NSError *error0 = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:&error0];
            if (error0) {
                if (error) { *error = error0; }
                return nil;
            }
            AVIMJsonObjectMessage *jsonObjectMessage = [AVIMJsonObjectMessage new];
            jsonObjectMessage.data_p = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            jsonObjectMessage;
        });
    }
    LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
    commandWrapper.outCommand = outCommand;
    return commandWrapper;
}

- (NSMutableArray<NSMutableDictionary *> *)queryResultsFrom:(AVIMGenericCommand *)inCommand
                                                      error:(NSError * __autoreleasing *)error
{
    AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
    AVIMJsonObjectMessage *jsonObjectMessage = (convCommand.hasResults ? convCommand.results : nil);
    NSString *jsonString = (jsonObjectMessage.hasData_p ? jsonObjectMessage.data_p : nil);
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        if (error) {
            *error = ({
                LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                LCError(code, LCIMErrorMessage(code), nil);
            });
        }
        return nil;
    }
    NSError *error0 = nil;
    NSMutableArray<NSMutableDictionary *> *results = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error0];
    if (error0) {
        if (error) {
            *error = error0;
        }
        return nil;
    }
    if (![NSMutableArray _lc_isTypeOf:results]) {
        if (error) {
            *error = ({
                LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                LCError(code, LCIMErrorMessage(code), nil);
            });
        }
        return nil;
    }
    return results;
}

- (void)invokeCallbacksWithId:(NSString *)conversationId conversation:(LCIMConversation *)conversation error:(NSError *)error
{
    NSMutableArray<void (^)(LCIMConversation *, NSError *)> *callbacks = self.callbacksMap[conversationId];
    [self.callbacksMap removeObjectForKey:conversationId];
    if (callbacks) {
        for (void (^callback)(LCIMConversation *, NSError *) in callbacks) {
            callback(conversation, error);
        }
    }
}

@end
