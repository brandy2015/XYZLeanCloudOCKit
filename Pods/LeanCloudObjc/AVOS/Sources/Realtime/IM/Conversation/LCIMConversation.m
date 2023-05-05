//
//  LCIMConversation.m
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMConversation_Internal.h"
#import "LCIMClient_Internal.h"
#import "LCIMKeyedConversation_internal.h"
#import "LCIMConversationQuery_Internal.h"
#import "LCIMConversationMemberInfo_Internal.h"
#import "LCIMTypedMessage_Internal.h"
#import "LCIMRecalledMessage.h"
#import "LCIMSignature.h"

#import "LCIMMessageCache.h"
#import "LCIMMessageCacheStore.h"
#import "LCIMConversationCache.h"

#import "LCIMBlockHelper.h"
#import "LCIMErrorUtil.h"

#import "LCFile_Internal.h"
#import "LCPaasClient.h"
#import "LCObjectUtils.h"
#import "LCUtils.h"
#import "LCErrorUtils.h"

#import "AVIMGenericCommand+AVIMMessagesAdditions.h"

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

@implementation LCIMMessageIntervalBound

- (instancetype)initWithMessageId:(NSString *)messageId
                        timestamp:(int64_t)timestamp
                           closed:(BOOL)closed
{
    self = [super init];
    if (self) {
        self->_messageId = [messageId copy];
        self->_timestamp = timestamp;
        self->_closed = closed;
    }
    return self;
}

@end

@implementation LCIMMessageInterval

- (instancetype)initWithStartIntervalBound:(LCIMMessageIntervalBound *)startIntervalBound
                          endIntervalBound:(LCIMMessageIntervalBound *)endIntervalBound
{
    self = [super init];
    if (self) {
        self->_startIntervalBound = startIntervalBound;
        self->_endIntervalBound = endIntervalBound;
    }
    return self;
}

@end

@implementation LCIMOperationFailure

@end

@implementation LCIMConversation {
    
    // public immutable
    NSString *_clientId;
    NSString *_conversationId;
    
    // public mutable
    LCIMMessage *_lastMessage;
    int64_t _lastDeliveredTimestamp;
    int64_t _lastReadTimestamp;
    NSUInteger _unreadMessagesCount;
    BOOL _unreadMessagesMentioned;
    
    // lock
    NSLock *_lock;
    
    // raw data
    NSMutableDictionary *_rawJSONData;
    NSMutableDictionary<NSString *, id> *_pendingData;
    BOOL _isUpdating;
    
    // member info
    NSMutableDictionary<NSString *, LCIMConversationMemberInfo *> *_memberInfoTable;
    
    // message cache for rcp
    NSMutableDictionary<NSString *, LCIMMessage *> *_rcpMessageTable;
    
#if DEBUG
    dispatch_queue_t _internalSerialQueue;
#endif
}

static dispatch_queue_t messageCacheOperationQueue;

+ (void)initialize
{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        messageCacheOperationQueue = dispatch_queue_create("leancloud.message-cache-operation-queue", DISPATCH_QUEUE_CONCURRENT);
    });
}

+ (NSUInteger)validLimit:(NSUInteger)limit
{
    if (limit <= 0) {
        limit = 20;
    } else if (limit > 100) {
        limit = 100;
    }
    return limit;
}

+ (NSTimeInterval)distantFutureTimestamp
{
    return ([[NSDate distantFuture] timeIntervalSince1970] * 1000);
}

+ (int64_t)validTimestamp:(int64_t)timestamp
{
    if (timestamp <= 0) {
        
        timestamp = (int64_t)[self distantFutureTimestamp];
    }
    
    return timestamp;
}

+ (instancetype)new
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

// MARK: - Init

+ (instancetype)conversationWithRawJSONData:(NSMutableDictionary *)rawJSONData
                                     client:(LCIMClient *)client
{
    NSString *conversationId = [NSString _lc_decoding:rawJSONData key:LCIMConversationKeyObjectId];
    if (!conversationId || !client) {
        return nil;
    }
    
    LCIMConversation *conv = ({
        LCIMConvType convType = [NSNumber _lc_decoding:rawJSONData key:LCIMConversationKeyConvType].unsignedIntegerValue;
        if (!convType) {
            BOOL transient = [NSNumber _lc_decoding:rawJSONData key:LCIMConversationKeyTransient].boolValue;
            BOOL system = [NSNumber _lc_decoding:rawJSONData key:LCIMConversationKeySystem].boolValue;
            BOOL temporary = [NSNumber _lc_decoding:rawJSONData key:LCIMConversationKeyTemporary].boolValue;
            if (transient && !system && !temporary) {
                convType = LCIMConvTypeTransient;
            } else if (system && !transient && !temporary) {
                convType = LCIMConvTypeSystem;
            } else if (temporary && !transient && !system) {
                convType = LCIMConvTypeTemporary;
            } else {
                convType = LCIMConvTypeNormal;
            }
        }
        LCIMConversation *conv = nil;
        switch (convType)
        {
            case LCIMConvTypeTransient:
            {
                conv = [[LCIMChatRoom alloc] initWithRawJSONData:rawJSONData conversationId:conversationId client:client];
            }break;
            case LCIMConvTypeSystem:
            {
                conv = [[LCIMServiceConversation alloc] initWithRawJSONData:rawJSONData conversationId:conversationId client:client];
            }break;
            case LCIMConvTypeTemporary:
            {
                conv = [[LCIMTemporaryConversation alloc] initWithRawJSONData:rawJSONData conversationId:conversationId client:client];
            }break;
            default:
            {
                conv = [[LCIMConversation alloc] initWithRawJSONData:rawJSONData conversationId:conversationId client:client];
            }break;
        }
        conv->_convType = convType;
        conv;
    });
    return conv;
}

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData
                     conversationId:(NSString *)conversationId
                             client:(LCIMClient *)client
{
    self = [super init];
    
    if (self) {
        
        self->_lock = [[NSLock alloc] init];
        
        _imClient = client;
#if DEBUG
        self->_internalSerialQueue = client.internalSerialQueue;
#endif
        self->_conversationId = conversationId;
        self->_clientId = client.clientId;
        
        self->_rawJSONData = rawJSONData;
        self->_pendingData = [NSMutableDictionary dictionary];
        self->_isUpdating = false;
        self->_memberInfoTable = nil;
        self->_rcpMessageTable = [NSMutableDictionary dictionary];
        
        self->_lastDeliveredTimestamp = 0;
        self->_lastReadTimestamp = 0;
        self->_unreadMessagesCount = 0;
        self->_unreadMessagesMentioned = false;
        self->_lastMessage = [self decodingLastMessageFromRawJSONData:rawJSONData];
    }
    
    return self;
}

// MARK: - Public Property

- (NSString *)clientId
{
    return self->_clientId;
}

- (NSString *)conversationId
{
    return self->_conversationId;
}

- (NSString *)creator
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString _lc_decoding:self->_rawJSONData key:LCIMConversationKeyCreator];
    }];
    return value;
}

- (NSDate *)createAt {
    return [self createdAt];
}

- (NSDate *)createdAt {
    __block id value;
    [self internalSyncLock:^{
        value = self->_rawJSONData[LCIMConversationKeyCreatedAt];
    }];
    if ([NSDate _lc_isTypeOf:value]) {
        return value;
    } else {
        return [LCDate dateFromValue:value];
    }
}

- (NSDate *)updateAt {
    return [self updatedAt];
}

- (NSDate *)updatedAt {
    __block id value;
    [self internalSyncLock:^{
        value = self->_rawJSONData[LCIMConversationKeyUpdatedAt];
    }];
    if ([NSDate _lc_isTypeOf:value]) {
        return value;
    } else {
        return [LCDate dateFromValue:value];
    }
}

- (NSString *)name
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString _lc_decoding:self->_rawJSONData key:LCIMConversationKeyName];
    }];
    return value;
}

- (NSArray<NSString *> *)members
{
    __block NSArray *value = nil;
    [self internalSyncLock:^{
        value = [NSArray _lc_decoding:self->_rawJSONData key:LCIMConversationKeyMembers].copy;
    }];
    return value;
}

- (void)addMembers:(NSArray<NSString *> *)members
{
    if (!members || members.count == 0) {
        return;
    }
    [self internalSyncLock:^{
        NSArray *originMembers = [NSArray _lc_decoding:self->_rawJSONData key:LCIMConversationKeyMembers] ?: @[];
        self->_rawJSONData[LCIMConversationKeyMembers] = ({
            NSMutableSet *set = [NSMutableSet setWithArray:originMembers];
            [set addObjectsFromArray:members];
            set.allObjects;
        });
    }];
    [self removeCachedConversation];
}

- (void)removeMembers:(NSArray<NSString *> *)members
{
    if (!members || members.count == 0) {
        return;
    }
    [self internalSyncLock:^{
        NSArray *originMembers = [NSArray _lc_decoding:self->_rawJSONData key:LCIMConversationKeyMembers] ?: @[];
        self->_rawJSONData[LCIMConversationKeyMembers] = ({
            NSMutableSet *set = [NSMutableSet setWithArray:originMembers];
            for (NSString *memberId in members) {
                [set removeObject:memberId];
            }
            set.allObjects;
        });
    }];
    [self removeCachedConversation];
    if ([members containsObject:self->_clientId]) {
        [self removeCachedMessages];
    }
}

- (BOOL)muted
{
    __block id value = nil;
    [self internalSyncLock:^{
        value = [NSArray _lc_decoding:self->_rawJSONData key:LCIMConversationKeyMutedMembers].copy;
        if (!value) {
            value = [NSNumber _lc_decoding:self->_rawJSONData key:LCIMConversationKeyMutedMembers];
        }
    }];
    if ([NSArray _lc_isTypeOf:value]) {
        return [value containsObject:self->_clientId];
    } else if ([NSNumber _lc_isTypeOf:value]) {
        return [(NSNumber *)value boolValue];
    } else {
        return false;
    }
}

- (NSDictionary *)attributes
{
    __block NSDictionary *value = nil;
    [self internalSyncLock:^{
        value = [NSDictionary _lc_decoding:self->_rawJSONData key:LCIMConversationKeyAttributes].copy;
    }];
    return value;
}

- (NSString *)uniqueId
{
    __block NSString *value = nil;
    [self internalSyncLock:^{
        value = [NSString _lc_decoding:self->_rawJSONData key:LCIMConversationKeyUniqueId];
    }];
    return value;
}

- (BOOL)unique
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber _lc_decoding:self->_rawJSONData key:LCIMConversationKeyUnique];
    }];
    return value.boolValue;
}

- (BOOL)transient
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber _lc_decoding:self->_rawJSONData key:LCIMConversationKeyTransient];
    }];
    return value.boolValue;
}

- (BOOL)system
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber _lc_decoding:self->_rawJSONData key:LCIMConversationKeySystem];
    }];
    return value.boolValue;
}

- (BOOL)temporary
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber _lc_decoding:self->_rawJSONData key:LCIMConversationKeyTemporary];
    }];
    return value.boolValue;
}

- (NSUInteger)temporaryTTL
{
    __block NSNumber *value = nil;
    [self internalSyncLock:^{
        value = [NSNumber _lc_decoding:self->_rawJSONData key:LCIMConversationKeyTemporaryTTL];
    }];
    return value.unsignedIntegerValue;
}

- (LCIMMessage *)lastMessage
{
    __block LCIMMessage *lastMessage = nil;
    [self internalSyncLock:^{
        lastMessage = self->_lastMessage;
    }];
    return lastMessage;
}

- (NSDate *)lastMessageAt
{
    __block int64_t timestamp = 0;
    [self internalSyncLock:^{
        if (self->_lastMessage) {
            timestamp = self->_lastMessage.sendTimestamp;
        }
    }];
    return timestamp ? [NSDate dateWithTimeIntervalSince1970:(timestamp / 1000.0)] : nil;
}

- (BOOL)updateLastMessage:(LCIMMessage *)message client:(LCIMClient *)client
{
    AssertRunInQueue(self->_internalSerialQueue);
    __block BOOL updated = false;
    __block BOOL newMessageArrived = false;
    [self internalSyncLock:^{
        LCIMMessage *lastMessage = self->_lastMessage;
        if (!lastMessage) {
            // 1. no lastMessage
            updated = true;
            newMessageArrived = true;
        } else {
            if (lastMessage.sendTimestamp < message.sendTimestamp) {
                // 2. lastMessage date earlier than message
                updated = true;
                newMessageArrived = true;
            } else if (lastMessage.sendTimestamp == message.sendTimestamp) {
                if (![lastMessage.messageId isEqualToString:message.messageId]) {
                    // 3. lastMessage date equal to message but id not equal
                    updated = true;
                    newMessageArrived = true;
                } else {
                    if (!lastMessage.updatedAt && message.updatedAt) {
                        // 4. lastMessage date and id equal to message but message modified.
                        updated = true;
                    } else if (lastMessage.updatedAt && message.updatedAt) {
                        if ([lastMessage.updatedAt compare:message.updatedAt] == NSOrderedAscending) {
                            // 5. lastMessage date and id equal to message but lastMessage modified date earlier than message.
                            updated = true;
                        }
                    } else if (!lastMessage.updatedAt && !message.updatedAt) {
                        // 6. lastMessage date and id equal to message and both no modified.
                        updated = true;
                    }
                }
            }
        }
        if (updated) {
            self->_lastMessage = message;
        }
    }];
    if (updated) {
        [client conversation:self didUpdateForKeys:@[LCIMConversationUpdatedKeyLastMessage, LCIMConversationUpdatedKeyLastMessageAt]];
    }
    return newMessageArrived;
}

- (LCIMMessage *)decodingLastMessageFromRawJSONData:(NSMutableDictionary *)rawJSONData
{
    LCIMMessage *lastMessage = nil;
    NSString *msgContent = [NSString _lc_decoding:rawJSONData key:LCIMConversationKeyLastMessageContent];
    NSString *msgId = [NSString _lc_decoding:rawJSONData key:LCIMConversationKeyLastMessageId];
    NSString *msgFrom = [NSString _lc_decoding:rawJSONData key:LCIMConversationKeyLastMessageFrom];
    int64_t msgTimestamp = [NSNumber _lc_decoding:rawJSONData key:LCIMConversationKeyLastMessageTimestamp].longLongValue;
    if (msgContent && msgId && msgFrom && msgTimestamp) {
        LCIMTypedMessageObject *typedMessageObject = [[LCIMTypedMessageObject alloc] initWithJSON:msgContent];
        if ([typedMessageObject isValidTypedMessageObject]) {
            lastMessage = [LCIMTypedMessage messageWithMessageObject:typedMessageObject];
        } else {
            lastMessage = [[LCIMMessage alloc] init];
        }
        lastMessage.status = LCIMMessageStatusDelivered;
        lastMessage.conversationId = self->_conversationId;
        lastMessage.content = msgContent;
        lastMessage.messageId = msgId;
        lastMessage.clientId = msgFrom;
        lastMessage.localClientId = self->_clientId;
        lastMessage.sendTimestamp = msgTimestamp;
        lastMessage.updatedAt = ({
            NSNumber *patchTimestamp = [NSNumber _lc_decoding:rawJSONData key:LCIMConversationKeyLastMessagePatchTimestamp];
            NSDate *date = nil;
            if (patchTimestamp != nil) {
                date = [NSDate dateWithTimeIntervalSince1970:(patchTimestamp.doubleValue / 1000.0)];
            }
            date;
        });
        lastMessage.mentionAll = [NSNumber _lc_decoding:rawJSONData key:LCIMConversationKeyLastMessageMentionAll].boolValue;
        lastMessage.mentionList = [NSArray _lc_decoding:rawJSONData key:LCIMConversationKeyLastMessageMentionPids];
    }
    return lastMessage;
}

- (NSDate *)lastDeliveredAt
{
    __block int64_t timestamp = 0;
    [self internalSyncLock:^{
        if (self->_lastDeliveredTimestamp) {
            timestamp = self->_lastDeliveredTimestamp;
        }
    }];
    return timestamp ? [NSDate dateWithTimeIntervalSince1970:(timestamp / 1000.0)] : nil;
}

- (NSDate *)lastReadAt
{
    __block int64_t timestamp = 0;
    [self internalSyncLock:^{
        if (self->_lastReadTimestamp) {
            timestamp = self->_lastReadTimestamp;
        }
    }];
    return timestamp ? [NSDate dateWithTimeIntervalSince1970:(timestamp / 1000.0)] : nil;
}

- (NSUInteger)unreadMessagesCount
{
    __block NSUInteger count = 0;
    [self internalSyncLock:^{
        count = self->_unreadMessagesCount;
    }];
    return count;
}

- (BOOL)unreadMessagesMentioned
{
    return self->_unreadMessagesMentioned;
}

- (void)setUnreadMessagesMentioned:(BOOL)unreadMessagesMentioned
{
    self->_unreadMessagesMentioned = unreadMessagesMentioned;
}

// MARK: - Raw JSON Data

- (NSDictionary *)rawJSONDataCopy
{
    __block NSDictionary *value = nil;
    [self internalSyncLock:^{
        value = self->_rawJSONData.copy;
    }];
    return value;
}

- (NSMutableDictionary *)rawJSONDataMutableCopy
{
    __block NSMutableDictionary *value = nil;
    [self internalSyncLock:^{
        value = self->_rawJSONData.mutableCopy;
    }];
    return value;
}

- (void)setRawJSONData:(NSMutableDictionary *)rawJSONData
{
    __block LCIMMessage *lastMessage = nil;
    [self internalSyncLock:^{
        self->_rawJSONData = rawJSONData;
        lastMessage = [self decodingLastMessageFromRawJSONData:rawJSONData];
    }];
    LCIMClient *client = self.imClient;
    if (client && lastMessage) {
        [client addOperationToInternalSerialQueue:^(LCIMClient *client) {
            [self updateLastMessage:lastMessage client:client];
        }];
    }
}

- (void)updateRawJSONDataWith:(NSDictionary *)dictionary
{
    [self internalSyncLock:^{
        [self->_rawJSONData addEntriesFromDictionary:dictionary];
    }];
}

// MARK: - Misc

- (void)internalSyncLock:(void (^)(void))block
{
    [self->_lock lock];
    block();
    [self->_lock unlock];
}

- (void)setObject:(id)object forKey:(NSString *)key
{
    [self internalSyncLock:^{
        if (object) {
            self->_pendingData[key] = object;
        } else {
            [self->_pendingData removeObjectForKey:key];
        }
    }];
}

- (id)objectForKey:(NSString *)key
{
    __block id object = nil;
    [self internalSyncLock:^{
        object = self->_rawJSONData[key];
    }];
    return object;
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key
{
    [self setObject:object forKey:key];
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    return [self objectForKey:key];
}

// MARK: - RCP Timestamps

- (void)fetchReceiptTimestampsInBackground
{
    LCIMClient *client = self.imClient;
    if (!client ||
        (self.convType == LCIMConvTypeTransient) ||
        (self.convType == LCIMConvTypeSystem)) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_MaxRead;
        outCommand.convMessage = convCommand;
        convCommand.cid = self->_conversationId;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        int64_t lastDeliveredTimestamp = (convCommand.hasMaxAckTimestamp ? convCommand.maxAckTimestamp : 0);
        int64_t lastReadTimestamp = (convCommand.hasMaxReadTimestamp ? convCommand.maxReadTimestamp : 0);
        
        NSMutableArray<LCIMConversationUpdatedKey> *keys = [NSMutableArray array];
        [self internalSyncLock:^{
            if (lastDeliveredTimestamp > self->_lastDeliveredTimestamp) {
                [keys addObject:LCIMConversationUpdatedKeyLastDeliveredAt];
                self->_lastDeliveredTimestamp = lastDeliveredTimestamp;
            }
            if (lastReadTimestamp > self->_lastReadTimestamp) {
                [keys addObject:LCIMConversationUpdatedKeyLastReadAt];
                self->_lastReadTimestamp = lastReadTimestamp;
            }
        }];
        [client conversation:self didUpdateForKeys:keys];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Members

- (void)joinWithCallback:(void (^)(BOOL, NSError *))callback
{
    [self addMembersWithClientIds:@[self->_clientId] callback:callback];
}

- (void)addMembersWithClientIds:(NSArray<NSString *> *)clientIds
                       callback:(void (^)(BOOL, NSError *))callback;
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    clientIds = ({
        for (NSString *item in clientIds) {
            if (item.length > kClientIdLengthLimit || item.length == 0) {
                [client invokeInUserInteractQueue:^{
                    callback(false, LCErrorInternalServer([NSString stringWithFormat:@"client id's length should in range [1 %lu].", (unsigned long)kClientIdLengthLimit]));
                }];
                return;
            }
        }
        [NSSet setWithArray:clientIds].allObjects;
    });
    
    [client getSignatureWithConversation:self action:LCIMSignatureActionAdd actionOnClientIds:clientIds callback:^(LCIMSignature *signature) {
        
        AssertRunInQueue(self->_internalSerialQueue);
        
        if (signature && signature.error) {
            [client invokeInUserInteractQueue:^{
                callback(false, signature.error);
            }];
            return;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMConvCommand *convCommand = [AVIMConvCommand new];
            
            outCommand.cmd = AVIMCommandType_Conv;
            outCommand.op = AVIMOpType_Add;
            outCommand.convMessage = convCommand;
            
            convCommand.cid = self->_conversationId;
            convCommand.mArray = clientIds.mutableCopy;
            if (signature.signature && signature.timestamp && signature.nonce) {
                convCommand.s = signature.signature;
                convCommand.t = signature.timestamp;
                convCommand.n = signature.nonce;
            }
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                [client invokeInUserInteractQueue:^{
                    callback(false, commandWrapper.error);
                }];
                return;
            }
            
            AVIMGenericCommand *inCommand = commandWrapper.inCommand;
            AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
            NSArray<NSString *> *allowedPidsArray = convCommand.allowedPidsArray;
            
            [self addMembers:allowedPidsArray];
            
            [client invokeInUserInteractQueue:^{
                callback(true, nil);
            }];
        }];
        
        [client sendCommandWrapper:commandWrapper];
    }];
}

- (void)quitWithCallback:(void (^)(BOOL, NSError *))callback
{
    [self removeMembersWithClientIds:@[self->_clientId] callback:callback];
}

- (void)removeMembersWithClientIds:(NSArray<NSString *> *)clientIds
                          callback:(void (^)(BOOL, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    clientIds = ({
        for (NSString *item in clientIds) {
            if (item.length > kClientIdLengthLimit || item.length == 0) {
                [client invokeInUserInteractQueue:^{
                    callback(false, LCErrorInternalServer([NSString stringWithFormat:@"client id's length should in range [1 %lu].", (unsigned long)kClientIdLengthLimit]));
                }];
                return;
            }
        }
        [NSSet setWithArray:clientIds].allObjects;
    });
    
    [client getSignatureWithConversation:self action:LCIMSignatureActionAdd actionOnClientIds:clientIds callback:^(LCIMSignature *signature) {
        
        AssertRunInQueue(self->_internalSerialQueue);
        
        if (signature && signature.error) {
            [client invokeInUserInteractQueue:^{
                callback(false, signature.error);
            }];
            return;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMConvCommand *convCommand = [AVIMConvCommand new];
            
            outCommand.cmd = AVIMCommandType_Conv;
            outCommand.op = AVIMOpType_Remove;
            outCommand.convMessage = convCommand;
            
            convCommand.cid = self->_conversationId;
            convCommand.mArray = clientIds.mutableCopy;
            if (signature.signature && signature.timestamp && signature.nonce) {
                convCommand.s = signature.signature;
                convCommand.t = signature.timestamp;
                convCommand.n = signature.nonce;
            }
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                [client invokeInUserInteractQueue:^{
                    callback(false, commandWrapper.error);
                }];
                return;
            }
            
            AVIMGenericCommand *inCommand = commandWrapper.inCommand;
            AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
            NSArray<NSString *> *allowedPidsArray = convCommand.allowedPidsArray;
            
            [self removeMembers:allowedPidsArray];
            
            [client invokeInUserInteractQueue:^{
                callback(true, nil);
            }];
        }];
        
        [client sendCommandWrapper:commandWrapper];
    }];
}

- (void)countMembersWithCallback:(void (^)(NSInteger, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Count;
        outCommand.convMessage = convCommand;
        convCommand.cid = self->_conversationId;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(0, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        NSInteger count = (convCommand.hasCount ? convCommand.count : 0);
        
        [client invokeInUserInteractQueue:^{
            callback(count, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Attribute

- (void)fetchWithCallback:(void (^)(BOOL, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMConversationQuery *query = [client conversationQuery];
    query.cachePolicy = kLCIMCachePolicyNetworkOnly;
    [query getConversationById:self->_conversationId callback:^(LCIMConversation *conversation, NSError *error) {
#if DEBUG
        if (conversation) {
            assert(conversation == self);
        }
#endif
        callback(error ? false : true, error);
    }];
}

- (void)updateWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    NSDictionary<NSString *, id> *pendingData = ({
        __block NSDictionary<NSString *, id> *pendingData = nil;
        [self internalSyncLock:^{
            pendingData = (self->_isUpdating ? nil : self->_pendingData.copy);
        }];
        if (!pendingData) {
            [client invokeInUserInteractQueue:^{
                callback(false, LCErrorInternalServer(@"can't update before last update done."));
            }];
            return;
        }
        if (pendingData.count == 0) {
            [client invokeInUserInteractQueue:^{
                callback(true, nil);
            }];
            return;
        }
        pendingData;
    });
    
    [self internalSyncLock:^{
        self->_isUpdating = true;
    }];
    
    [self updateWithDictionary:pendingData callback:^(BOOL succeeded, NSError *error) {
        
        [self internalSyncLock:^{
            self->_isUpdating = false;
        }];
        
        [self.imClient invokeInUserInteractQueue:^{
            callback(succeeded, error);
        }];
    }];
}

- (void)updateWithDictionary:(NSDictionary<NSString *, id> *)dictionary
                    callback:(void (^)(BOOL succeeded, NSError *error))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *command = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        AVIMJsonObjectMessage *jsonObjectMessage = [AVIMJsonObjectMessage new];
        
        command.cmd = AVIMCommandType_Conv;
        command.op = AVIMOpType_Update;
        command.convMessage = convCommand;
        
        convCommand.cid = self->_conversationId;
        convCommand.attr = jsonObjectMessage;
        
        jsonObjectMessage.data_p = ({
            NSError *error = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
            if (error) {
                callback(false, error);
                return;
            }
            [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        });
        
        LCIMProtobufCommandWrapper *commandWrapper = [[LCIMProtobufCommandWrapper alloc] init];
        commandWrapper.outCommand = command;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        if (commandWrapper.error) {
            callback(false, commandWrapper.error);
            return;
        }
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        NSDictionary *modifiedAttr = ({
            AVIMJsonObjectMessage *jsonObjectCommand = (convCommand.hasAttrModified ? convCommand.attrModified : nil);
            NSString *jsonString = (jsonObjectCommand.hasData_p ? jsonObjectCommand.data_p : nil);
            NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            if (!data) {
                callback(false, ({
                    LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                    LCError(code, LCIMErrorMessage(code), nil);
                }));
                return;
            }
            NSError *error = nil;
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error || ![NSDictionary _lc_isTypeOf:dic]) {
                callback(false, error ?: ({
                    LCIMErrorCode code = LCIMErrorCodeInvalidCommand;
                    LCError(code, LCIMErrorMessage(code), nil);
                }));
                return;
            }
            dic;
        });
        [self internalSyncLock:^{
            processAttrAndAttrModified(dictionary, modifiedAttr, self->_rawJSONData);
            [self->_pendingData removeObjectsForKeys:dictionary.allKeys];
        }];
        [self removeCachedConversation];
        callback(true, nil);
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

static void processAttrAndAttrModified(NSDictionary *attr, NSDictionary *attrModified, NSMutableDictionary *rawJSONData)
{
    if (!attr || !attrModified || !rawJSONData) {
        return;
    }
    for (NSString *originKey in attr.allKeys) {
        // get sub-key array
        NSArray<NSString *> *subKeys = [originKey componentsSeparatedByString:@"."];
        // get modified value
        id modifiedValue = ({
            id modifiedValue = nil;
            NSDictionary *subModifiedAttr = attrModified;
            for (NSInteger i = 0; i < subKeys.count; i++) {
                NSString *subKey = subKeys[i];
                if (i == subKeys.count - 1) {
                    modifiedValue = subModifiedAttr[subKey];
                } else {
                    NSDictionary *dic = subModifiedAttr[subKey];
                    if ([NSDictionary _lc_isTypeOf:dic]) {
                        subModifiedAttr = dic;
                    } else {
                        break;
                    }
                }
            }
            modifiedValue;
        });
        // if modified value exist, update it; if not exist, remove it.
        NSMutableDictionary *subOriginAttr = rawJSONData;
        for (NSInteger i = 0; i < subKeys.count; i++) {
            NSString *subKey = subKeys[i];
            if (i == subKeys.count - 1) {
                if (modifiedValue) {
                    subOriginAttr[subKey] = modifiedValue;
                } else {
                    [subOriginAttr removeObjectForKey:subKey];
                }
            } else {
                // for safe, use deep copy.
                NSMutableDictionary *mutableDic = subOriginAttr[subKey];
                if ([NSDictionary _lc_isTypeOf:mutableDic]) {
                    mutableDic = mutableDic.mutableCopy;
                } else {
                    if (modifiedValue) {
                        mutableDic = [NSMutableDictionary dictionary];
                    } else {
                        break;
                    }
                }
                subOriginAttr[subKey] = mutableDic;
                subOriginAttr = mutableDic;
            }
        }
    }
}

// MARK: - Mute

- (void)muteWithCallback:(void (^)(BOOL, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Mute;
        outCommand.convMessage = convCommand;
        convCommand.cid = self->_conversationId;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        [self internalSyncLock:^{
            NSArray *mutedMembers = [NSArray _lc_decoding:self->_rawJSONData key:LCIMConversationKeyMutedMembers] ?: @[];
            NSMutableSet *mutableSet = [NSMutableSet setWithArray:mutedMembers];
            [mutableSet addObject:self->_clientId];
            self->_rawJSONData[LCIMConversationKeyMutedMembers] = mutableSet.allObjects;
        }];
        [self removeCachedConversation];
        
        [client invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)unmuteWithCallback:(void (^)(BOOL, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Unmute;
        outCommand.convMessage = convCommand;
        convCommand.cid = self->_conversationId;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        [self internalSyncLock:^{
            NSArray *mutedMembers = [NSArray _lc_decoding:self->_rawJSONData key:LCIMConversationKeyMutedMembers] ?: @[];
            NSMutableSet *mutableSet = [NSMutableSet setWithArray:mutedMembers];
            [mutableSet removeObject:self->_clientId];
            self->_rawJSONData[LCIMConversationKeyMutedMembers] = mutableSet.allObjects;
        }];
        [self removeCachedConversation];
        
        [client invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Message Read

- (void)readInBackground
{
    LCIMClient *client = self.imClient;
    if (!client ||
        (self.convType == LCIMConvTypeTransient)) {
        return;
    }
    
    NSString *messageId = nil;
    int64_t timestamp = 0;
    
    __block LCIMMessage *lastMessage = nil;
    [self internalSyncLock:^{
        lastMessage = self->_lastMessage;
    }];
    
    if (lastMessage) {
        messageId = lastMessage.messageId;
        timestamp = lastMessage.sendTimestamp;
    } else {
        return;
    }
    
    [self internalSyncLock:^{
        self->_unreadMessagesCount = 0;
    }];
    [client addOperationToInternalSerialQueue:^(LCIMClient *client) {
        [client conversation:self didUpdateForKeys:@[LCIMConversationUpdatedKeyUnreadMessagesCount]];
    }];
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMReadCommand *readCommand = [AVIMReadCommand new];
        AVIMReadTuple *readTuple = [AVIMReadTuple new];
        
        outCommand.cmd = AVIMCommandType_Read;
        outCommand.readMessage = readCommand;
        
        readCommand.convsArray = [NSMutableArray arrayWithObject:readTuple];
        readTuple.cid = self->_conversationId;
        if (messageId) {
            readTuple.mid = messageId;
        }
        readTuple.timestamp = timestamp;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Message Send

- (void)sendMessage:(LCIMMessage *)message
           callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self sendMessage:message option:nil progressBlock:nil callback:callback];
}

- (void)sendMessage:(LCIMMessage *)message
             option:(LCIMMessageOption *)option
           callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self sendMessage:message option:option progressBlock:nil callback:callback];
}

- (void)sendMessage:(LCIMMessage *)message
      progressBlock:(void (^)(NSInteger))progressBlock
           callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self sendMessage:message option:nil progressBlock:progressBlock callback:callback];
}

- (void)sendMessage:(LCIMMessage *)message
             option:(LCIMMessageOption *)option
      progressBlock:(void (^)(NSInteger))progressBlock
           callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    if (client.status != LCIMClientStatusOpened) {
        message.status = LCIMMessageStatusFailed;
        [client invokeInUserInteractQueue:^{
            callback(false, ({
                LCIMErrorCode code = LCIMErrorCodeClientNotOpen;
                LCError(code, LCIMErrorMessage(code), nil);
            }));
        }];
        return;
    }
    
    message.clientId = self->_clientId;
    message.localClientId = self->_clientId;
    message.conversationId = self->_conversationId;
    message.status = LCIMMessageStatusSending;
    
    if ([message isKindOfClass:[LCIMTypedMessage class]]) {
        LCIMTypedMessage *typedMessage = (LCIMTypedMessage *)message;
        LCFile *file = typedMessage.file;
        if (file) {
            [file uploadWithProgress:progressBlock completionHandler:^(BOOL succeeded, NSError * _Nullable error) {
                LCIMClient *client = self.imClient;
                if (!client) {
                    return;
                }
                if (error) {
                    message.status = LCIMMessageStatusFailed;
                    [client invokeInUserInteractQueue:^{
                        callback(false, error);
                    }];
                    return;
                }
                dispatch_async(client.internalSerialQueue, ^{
                    [self fillTypedMessage:typedMessage withFile:file];
                    [self sendRealMessage:message option:option callback:callback];
                });
            }];
        } else {
            [self sendRealMessage:message option:option callback:callback];
        }
    } else {
        [self sendRealMessage:message option:option callback:callback];
    }
}

- (void)fillTypedMessage:(LCIMTypedMessage *)typedMessage withFile:(LCFile *)file
{
    NSMutableDictionary *metaData = (file.metaData.mutableCopy
                                     ?: [NSMutableDictionary dictionary]);
    if (typedMessage.mediaType == LCIMMessageMediaTypeImage) {
        double width = [metaData[@"width"] doubleValue];
        double height = [metaData[@"height"] doubleValue];
        if (!(width > 0 && height > 0)) {
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
            UIImage *image = ({
                UIImage *image;
                NSString *cachedPath = file.persistentCachePath;
                if ([[NSFileManager defaultManager] fileExistsAtPath:cachedPath]) {
                    NSData *data = [NSData dataWithContentsOfFile:cachedPath];
                    image = [UIImage imageWithData:data];
                }
                image;
            });
            width = image.size.width * image.scale;
            height = image.size.height * image.scale;
#elif TARGET_OS_OSX
            NSImage *image = ({
                NSImage *image;
                NSString *cachedPath = file.persistentCachePath;
                if ([[NSFileManager defaultManager] fileExistsAtPath:cachedPath]) {
                    NSData *data = [NSData dataWithContentsOfFile:cachedPath];
                    image = [[NSImage alloc] initWithData:data];
                }
                image;
            });
            width = image.size.width;
            height = image.size.height;
#endif
            if (width > 0) {
                metaData[@"width"] = @(width);
            }
            if (height > 0) {
                metaData[@"height"] = @(height);
            }
        }
    } else if (typedMessage.mediaType == LCIMMessageMediaTypeAudio ||
               typedMessage.mediaType == LCIMMessageMediaTypeVideo) {
        double seconds = [metaData[@"duration"] doubleValue];
        if (!(seconds > 0)) {
            NSString *path = file.persistentCachePath;
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                NSURL *fileURL = [NSURL fileURLWithPath:path];
                if (fileURL) {
                    AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:fileURL
                                                                 options:nil];
                    seconds = CMTimeGetSeconds(audioAsset.duration);
                    if (seconds > 0) {
                        metaData[@"duration"] = @(seconds);
                    }
                }
            }
        }
    }
    NSString *fileName = file.name;
    if (fileName) {
        metaData[@"name"] = fileName;
    }
    NSString *format = (fileName.pathExtension
                        ?: file.url.pathExtension);
    if (format) {
        metaData[@"format"] = format;
    }
    if (metaData.count > 0) {
        file.metaData = metaData;
    }
    typedMessage.file = file;
}

- (void)sendRealMessage:(LCIMMessage *)message
                 option:(LCIMMessageOption *)option
               callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    BOOL transientConv = (self.convType == LCIMConvTypeTransient);
    BOOL transientMsg = option.transient;
    BOOL receipt = option.receipt;
    BOOL will = option.will;
    LCIMMessagePriority priority = option.priority;
    NSDictionary *pushData = option.pushData;
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMDirectCommand *directCommand = [AVIMDirectCommand new];
        
        outCommand.cmd = AVIMCommandType_Direct;
        outCommand.directMessage = directCommand;
        if (transientConv && priority) {
            outCommand.priority = (int32_t)priority;
        }
        
        directCommand.cid = self->_conversationId;
        directCommand.msg = message.payload;
        if (message.mentionAll) {
            directCommand.mentionAll = message.mentionAll;
        }
        if (message.mentionList.count > 0) {
            directCommand.mentionPidsArray = message.mentionList.mutableCopy;
        }
        if (transientMsg) {
            directCommand.transient = transientMsg;
        }
        if (will) {
            directCommand.will = will;
        }
        if (receipt) {
            directCommand.r = receipt;
        }
        if (pushData && !transientConv && !transientMsg) {
            NSError *error = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:pushData options:0 error:&error];
            if (error) {
                [client invokeInUserInteractQueue:^{
                    callback(false, error);
                }];
                return;
            }
            directCommand.pushData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            message.status = LCIMMessageStatusFailed;
            [client invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMAckCommand *ackCommand = (inCommand.hasAckMessage ? inCommand.ackMessage : nil);
        message.sendTimestamp = (ackCommand.hasT ? ackCommand.t : 0);
        message.messageId = (ackCommand.hasUid ? ackCommand.uid : nil);
        message.transient = (transientConv || transientMsg);
        message.status = LCIMMessageStatusSent;
        if (receipt && message.messageId) {
            [self internalSyncLock:^{
                self->_rcpMessageTable[message.messageId] = message;
            }];
        }
        
        if (!transientConv && !transientMsg && !will) {
            [self updateLastMessage:message client:client];
            if (client.messageQueryCacheEnabled) {
                LCIMMessageCacheStore *messageCacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
                [messageCacheStore insertOrUpdateMessage:message withBreakpoint:NO];
            }
        }
        
        [client invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Message Patch

- (void)updateMessage:(LCIMMessage *)oldMessage
         toNewMessage:(LCIMMessage *)newMessage
             callback:(void (^)(BOOL, NSError * _Nullable))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    if (!oldMessage.messageId ||
        !oldMessage.sendTimestamp ||
        ![oldMessage.conversationId isEqualToString:self->_conversationId] ||
        ![oldMessage.clientId isEqualToString:self->_clientId]) {
        [client invokeInUserInteractQueue:^{
            callback(false, LCErrorInternalServer(@"oldMessage invalid."));
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMPatchCommand *patchCommand = [AVIMPatchCommand new];
        AVIMPatchItem *patchItem = [AVIMPatchItem new];
        
        outCommand.cmd = AVIMCommandType_Patch;
        outCommand.op = AVIMOpType_Modify;
        outCommand.patchMessage = patchCommand;
        
        patchCommand.patchesArray = [NSMutableArray arrayWithObject:patchItem];
        patchItem.cid = oldMessage.conversationId;
        patchItem.mid = oldMessage.messageId;
        patchItem.timestamp = oldMessage.sendTimestamp;
        
        patchItem.data_p = newMessage.payload;
        patchItem.mentionAll = newMessage.mentionAll;
        patchItem.mentionPidsArray = newMessage.mentionList.mutableCopy;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMPatchCommand *patchCommand = (inCommand.hasPatchMessage ? inCommand.patchMessage : nil);
        
        newMessage.messageId = oldMessage.messageId;
        newMessage.clientId = oldMessage.clientId;
        newMessage.localClientId = oldMessage.localClientId;
        newMessage.conversationId = oldMessage.conversationId;
        newMessage.sendTimestamp = oldMessage.sendTimestamp;
        newMessage.readTimestamp = oldMessage.readTimestamp;
        newMessage.deliveredTimestamp = oldMessage.deliveredTimestamp;
        newMessage.offline = oldMessage.offline;
        newMessage.hasMore = oldMessage.hasMore;
        newMessage.status = oldMessage.status;
        if (patchCommand.hasLastPatchTime) {
            newMessage.updatedAt = [NSDate dateWithTimeIntervalSince1970:patchCommand.lastPatchTime / 1000.0];
        }
        
        [self updateLastMessage:newMessage client:client];
        if (client.messageQueryCacheEnabled) {
            LCIMMessageCacheStore *messageCacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
            [messageCacheStore insertOrUpdateMessage:newMessage withBreakpoint:NO];
        }
        
        [client invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)recallMessage:(LCIMMessage *)oldMessage
             callback:(void (^)(BOOL, NSError * _Nullable, LCIMRecalledMessage * _Nullable))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    if (!oldMessage.messageId ||
        !oldMessage.sendTimestamp ||
        ![oldMessage.conversationId isEqualToString:self->_conversationId] ||
        ![oldMessage.clientId isEqualToString:self->_clientId]) {
        [client invokeInUserInteractQueue:^{
            callback(false, LCErrorInternalServer(@"oldMessage invalid."), nil);
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMPatchCommand *patchCommand = [AVIMPatchCommand new];
        AVIMPatchItem *patchItem = [AVIMPatchItem new];
        
        outCommand.cmd = AVIMCommandType_Patch;
        outCommand.op = AVIMOpType_Modify;
        outCommand.patchMessage = patchCommand;
        
        patchCommand.patchesArray = [NSMutableArray arrayWithObject:patchItem];
        patchItem.cid = oldMessage.conversationId;
        patchItem.mid = oldMessage.messageId;
        patchItem.timestamp = oldMessage.sendTimestamp;
        patchItem.recall = true;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error, nil);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMPatchCommand *patchCommand = (inCommand.hasPatchMessage ? inCommand.patchMessage : nil);
        
        LCIMRecalledMessage *recalledMessage = [[LCIMRecalledMessage alloc] init];
        recalledMessage.isRecall = true;
        recalledMessage.messageId = oldMessage.messageId;
        recalledMessage.clientId = oldMessage.clientId;
        recalledMessage.localClientId = oldMessage.localClientId;
        recalledMessage.conversationId = oldMessage.conversationId;
        recalledMessage.sendTimestamp = oldMessage.sendTimestamp;
        recalledMessage.readTimestamp = oldMessage.readTimestamp;
        recalledMessage.deliveredTimestamp = oldMessage.deliveredTimestamp;
        recalledMessage.offline = oldMessage.offline;
        recalledMessage.hasMore = oldMessage.hasMore;
        recalledMessage.status = oldMessage.status;
        if (patchCommand.hasLastPatchTime) {
            recalledMessage.updatedAt = [NSDate dateWithTimeIntervalSince1970:patchCommand.lastPatchTime / 1000.0];
        }
        
        [self updateLastMessage:recalledMessage client:client];
        if (client.messageQueryCacheEnabled) {
            LCIMMessageCacheStore *messageCacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
            [messageCacheStore insertOrUpdateMessage:recalledMessage withBreakpoint:NO];
        }
        
        [client invokeInUserInteractQueue:^{
            callback(true, nil, recalledMessage);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

#pragma mark -

- (NSArray *)takeContinuousMessages:(NSArray *)messages
{
    NSMutableArray *continuousMessages = [NSMutableArray array];
    
    for (LCIMMessage *message in messages.reverseObjectEnumerator) {
        
        if (message.breakpoint) {
            
            break;
        }
        
        [continuousMessages insertObject:message atIndex:0];
    }
    
    return continuousMessages;
}

- (LCIMMessageCache *)messageCache {
    NSString *clientId = self.clientId;
    
    return clientId ? [LCIMMessageCache cacheWithClientId:clientId] : nil;
}

- (LCIMMessageCacheStore *)messageCacheStore {
    NSString *clientId = self.clientId;
    NSString *conversationId = self.conversationId;
    
    return clientId && conversationId ? [[LCIMMessageCacheStore alloc] initWithClientId:clientId conversationId:conversationId] : nil;
}

- (LCIMConversationCache *)conversationCache {
    return self.imClient.conversationCache;
}

- (void)cacheContinuousMessages:(NSArray *)messages
                    plusMessage:(LCIMMessage *)message
{
    NSMutableArray *cachedMessages = [NSMutableArray array];
    
    if (messages) { [cachedMessages addObjectsFromArray:messages]; }
    
    if (message) { [cachedMessages addObject:message]; }
    
    [self cacheContinuousMessages:cachedMessages withBreakpoint:YES];
}

- (void)cacheContinuousMessages:(NSArray *)messages withBreakpoint:(BOOL)breakpoint {
    if (breakpoint) {
        [[self messageCache] addContinuousMessages:messages forConversationId:self.conversationId];
    } else {
        [[self messageCacheStore] insertOrUpdateMessages:messages];
    }
}

- (void)removeCachedConversation
{
    [[self conversationCache] removeConversationForId:self.conversationId];
}

- (void)removeCachedMessages
{
    [[self messageCacheStore] cleanCache];
}

- (void)addMessageToCache:(LCIMMessage *)message {
    message.clientId = self.imClient.clientId;
    message.conversationId = _conversationId;
    
    [[self messageCacheStore] insertOrUpdateMessage:message];
}

- (void)removeMessageFromCache:(LCIMMessage *)message {
    [[self messageCacheStore] deleteMessage:message];
}

#pragma mark - Message Query

- (void)queryMessagesFromServerWithCommand:(AVIMGenericCommand *)genericCommand
                                  callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
    commandWrapper.outCommand = genericCommand;
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(nil, commandWrapper.error);
            }];
            return;
        }
        AVIMLogsCommand *logsInCommand = commandWrapper.inCommand.logsMessage;
        AVIMLogsCommand *logsOutCommand = commandWrapper.outCommand.logsMessage;
        NSArray *logs = [logsInCommand.logsArray copy];
        NSMutableArray *messages = [[NSMutableArray alloc] init];
        for (AVIMLogItem *logsItem in logs) {
            LCIMMessage *message = nil;
            id data = [logsItem data_p];
            if (![data isKindOfClass:[NSString class]]) {
                LCLoggerError(LCLoggerDomainIM, @"Received an invalid message.");
                continue;
            }
            LCIMTypedMessageObject *messageObject = [[LCIMTypedMessageObject alloc] initWithJSON:data];
            if ([messageObject isValidTypedMessageObject]) {
                LCIMTypedMessage *m = [LCIMTypedMessage messageWithMessageObject:messageObject];
                message = m;
            } else {
                LCIMMessage *m = [[LCIMMessage alloc] init];
                m.content = data;
                message = m;
            }
            message.conversationId = logsOutCommand.cid;
            message.sendTimestamp = [logsItem timestamp];
            message.clientId = [logsItem from];
            message.messageId = [logsItem msgId];
            message.mentionAll = logsItem.mentionAll;
            message.mentionList = [logsItem.mentionPidsArray copy];
            if (logsItem.hasPatchTimestamp) {
                message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(logsItem.patchTimestamp / 1000.0)];
            }
            [messages addObject:message];
        }
        if (messages.firstObject) {
            [self updateLastMessage:messages.firstObject client:client];
        }
        [self postprocessMessages:messages];
        [client invokeInUserInteractQueue:^{
            callback(messages, nil);
        }];
    }];
    [client sendCommandWrapper:commandWrapper];
}

- (void)queryMessagesFromServerBeforeId:(NSString *)messageId
                              timestamp:(int64_t)timestamp
                                  limit:(NSUInteger)limit
                               callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback
{
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    AVIMLogsCommand *logsCommand = [[AVIMLogsCommand alloc] init];
    genericCommand.cmd = AVIMCommandType_Logs;
    genericCommand.logsMessage = logsCommand;
    logsCommand.cid    = _conversationId;
    logsCommand.mid    = messageId;
    logsCommand.t      = [self.class validTimestamp:timestamp];
    logsCommand.l      = (int32_t)[self.class validLimit:limit];
    [self queryMessagesFromServerWithCommand:genericCommand callback:callback];
}

- (void)queryMessagesFromServerBeforeId:(NSString *)messageId
                              timestamp:(int64_t)timestamp
                            toMessageId:(NSString *)toMessageId
                            toTimestamp:(int64_t)toTimestamp
                                  limit:(NSUInteger)limit
                               callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback
{
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    AVIMLogsCommand *logsCommand = [[AVIMLogsCommand alloc] init];
    genericCommand.cmd = AVIMCommandType_Logs;
    genericCommand.logsMessage = logsCommand;
    logsCommand.cid    = _conversationId;
    logsCommand.mid    = messageId;
    logsCommand.tmid   = toMessageId;
    logsCommand.tt     = MAX(toTimestamp, 0);
    logsCommand.t      = MAX(timestamp, 0);
    logsCommand.l      = (int32_t)[self.class validLimit:limit];
    [self queryMessagesFromServerWithCommand:genericCommand callback:callback];
}

- (void)queryMessagesFromServerWithLimit:(NSUInteger)limit
                                callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback
{
    limit = [self.class validLimit:limit];
    
    int64_t timestamp = (int64_t)[self.class distantFutureTimestamp];
    
    [self queryMessagesFromServerBeforeId:nil
                                timestamp:timestamp
                                    limit:limit
                                 callback:^(NSArray *messages, NSError *error)
     {
        if (error) {
            
            [LCIMBlockHelper callArrayResultBlock:callback
                                            array:nil
                                            error:error];
            
            return;
        }
        
        if (!self.imClient.messageQueryCacheEnabled) {
            
            [LCIMBlockHelper callArrayResultBlock:callback
                                            array:messages
                                            error:nil];
            
            return;
        }
        
        dispatch_async(messageCacheOperationQueue, ^{
            
            [self cacheContinuousMessages:messages
                           withBreakpoint:YES];
            
            [LCIMBlockHelper callArrayResultBlock:callback
                                            array:messages
                                            error:nil];
        });
    }];
}

- (NSArray *)queryMessagesFromCacheWithLimit:(NSUInteger)limit
{
    limit = [self.class validLimit:limit];
    NSArray *cachedMessages = [[self messageCacheStore] latestMessagesWithLimit:limit];
    [self postprocessMessages:cachedMessages];
    
    return cachedMessages;
}

- (void)queryMessagesWithLimit:(NSUInteger)limit
                      callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback
{
    limit = [self.class validLimit:limit];
    
    BOOL socketOpened = (self.imClient.status == LCIMClientStatusOpened);
    
    /* if disable query from cache, then only query from server. */
    if (!self.imClient.messageQueryCacheEnabled) {
        
        /* connection is not open, callback error. */
        if (!socketOpened) {
            
            NSError *error = ({
                LCIMErrorCode code = LCIMErrorCodeClientNotOpen;
                LCError(code, LCIMErrorMessage(code), nil);
            });
            
            [LCIMBlockHelper callArrayResultBlock:callback
                                            array:nil
                                            error:error];
            
            return;
        }
        
        [self queryMessagesFromServerWithLimit:limit
                                      callback:callback];
        
        return;
    }
    
    /* connection is not open, query messages from cache */
    if (!socketOpened) {
        
        NSArray *messages = [self queryMessagesFromCacheWithLimit:limit];
        
        [LCIMBlockHelper callArrayResultBlock:callback
                                        array:messages
                                        error:nil];
        
        return;
    }
    
    int64_t timestamp = (int64_t)[self.class distantFutureTimestamp];
    
    /* query recent message from server. */
    [self queryMessagesFromServerBeforeId:nil
                                timestamp:timestamp
                              toMessageId:nil
                              toTimestamp:0
                                    limit:limit
                                 callback:^(NSArray *messages, NSError *error)
     {
        if (error) {
            
            /* If network has an error, fallback to query from cache */
            if ([error.domain isEqualToString:NSURLErrorDomain]) {
                
                NSArray *messages = [self queryMessagesFromCacheWithLimit:limit];
                
                [LCIMBlockHelper callArrayResultBlock:callback
                                                array:messages
                                                error:nil];
                
                return;
            }
            
            /* If error is not network relevant, return it */
            [LCIMBlockHelper callArrayResultBlock:callback
                                            array:nil
                                            error:error];
            
            return;
        }
        
        dispatch_async(messageCacheOperationQueue, ^{
            
            [self cacheContinuousMessages:messages
                           withBreakpoint:YES];
            
            NSArray *messages = [self queryMessagesFromCacheWithLimit:limit];
            
            [LCIMBlockHelper callArrayResultBlock:callback
                                            array:messages
                                            error:nil];
        });
    }];
}

- (void)queryMessagesBeforeId:(NSString *)messageId
                    timestamp:(int64_t)timestamp
                        limit:(NSUInteger)limit
                     callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback
{
    if (messageId == nil) {
        
        NSString *reason = @"`messageId` can't be nil";
        
        [LCIMBlockHelper callArrayResultBlock:callback
                                        array:nil
                                        error:LCErrorInternalServer(reason)];
        
        return;
    }
    
    limit     = [self.class validLimit:limit];
    timestamp = [self.class validTimestamp:timestamp];
    
    /*
     * Firstly, if message query cache is not enabled, just forward query request.
     */
    if (!self.imClient.messageQueryCacheEnabled) {
        
        [self queryMessagesFromServerBeforeId:messageId
                                    timestamp:timestamp
                                        limit:limit
                                     callback:^(NSArray *messages, NSError *error)
         {
            [LCIMBlockHelper callArrayResultBlock:callback
                                            array:messages
                                            error:error];
        }];
        
        return;
    }
    
    /*
     * Secondly, if message query cache is enabled, fetch message from cache.
     */
    dispatch_async(messageCacheOperationQueue, ^{
        
        LCIMMessageCacheStore *cacheStore = self.messageCacheStore;
        
        LCIMMessage *fromMessage = [cacheStore getMessageById:messageId
                                                    timestamp:timestamp];
        
        void (^queryMessageFromServerBefore_block)(void) = ^ {
            
            [self queryMessagesFromServerBeforeId:messageId
                                        timestamp:timestamp
                                            limit:limit
                                         callback:^(NSArray *messages, NSError *error)
             {
                dispatch_async(messageCacheOperationQueue, ^{
                    
                    [self cacheContinuousMessages:messages
                                      plusMessage:fromMessage];
                    
                    [LCIMBlockHelper callArrayResultBlock:callback
                                                    array:messages
                                                    error:error];
                });
            }];
        };
        
        if (fromMessage) {
            
            [self postprocessMessages:@[fromMessage]];
            
            if (fromMessage.breakpoint) {
                
                queryMessageFromServerBefore_block();
                
                return;
            }
        }
        
        BOOL continuous = YES;
        
        LCIMMessageCache *cache = [self messageCache];
        
        /* `cachedMessages` is timestamp or messageId ascending order */
        NSArray *cachedMessages = [cache messagesBeforeTimestamp:timestamp
                                                       messageId:messageId
                                                  conversationId:self.conversationId
                                                           limit:limit
                                                      continuous:&continuous];
        
        [self postprocessMessages:cachedMessages];
        
        /*
         * If message is continuous or socket connect is not opened, return fetched messages directly.
         */
        BOOL socketOpened = (self.imClient.status == LCIMClientStatusOpened);
        
        if ((continuous && cachedMessages.count == limit) ||
            !socketOpened) {
            
            [LCIMBlockHelper callArrayResultBlock:callback
                                            array:cachedMessages
                                            error:nil];
            
            return;
        }
        
        /*
         * If cached messages exist, only fetch the rest uncontinuous messages.
         */
        if (cachedMessages.count > 0) {
            
            /* `continuousMessages` is timestamp or messageId ascending order */
            NSArray *continuousMessages = [self takeContinuousMessages:cachedMessages];
            
            BOOL hasContinuous = continuousMessages.count > 0;
            
            /*
             * Then, fetch rest of messages from remote server.
             */
            NSUInteger restCount = 0;
            LCIMMessage *startMessage = nil;
            
            if (hasContinuous) {
                
                restCount = limit - continuousMessages.count;
                startMessage = continuousMessages.firstObject;
                
            } else {
                
                restCount = limit;
                LCIMMessage *last = cachedMessages.lastObject;
                startMessage = [cache nextMessageForMessage:last
                                             conversationId:self.conversationId];
            }
            
            /*
             * If start message not nil, query messages before it.
             */
            if (startMessage) {
                
                [self queryMessagesFromServerBeforeId:startMessage.messageId
                                            timestamp:startMessage.sendTimestamp
                                                limit:restCount
                                             callback:^(NSArray *messages, NSError *error)
                 {
                    if (error) {
                        LCLoggerError(LCLoggerDomainIM, @"Error: %@", error);
                    }
                    
                    NSMutableArray *fetchedMessages;
                    
                    if (messages) {
                        
                        fetchedMessages = [NSMutableArray arrayWithArray:messages];
                        
                    } else {
                        
                        fetchedMessages = @[].mutableCopy;
                    }
                    
                    
                    if (hasContinuous) {
                        [fetchedMessages addObjectsFromArray:continuousMessages];
                    }
                    
                    dispatch_async(messageCacheOperationQueue, ^{
                        
                        [self cacheContinuousMessages:fetchedMessages
                                          plusMessage:fromMessage];
                        
                        NSArray *messages = [cacheStore messagesBeforeTimestamp:timestamp
                                                                      messageId:messageId
                                                                          limit:limit];
                        
                        [LCIMBlockHelper callArrayResultBlock:callback
                                                        array:messages
                                                        error:nil];
                    });
                }];
                
                return;
            }
        }
        
        /*
         * Otherwise, just forward query request.
         */
        queryMessageFromServerBefore_block();
    });
}

- (void)queryMessagesInInterval:(LCIMMessageInterval *)interval
                      direction:(LCIMMessageQueryDirection)direction
                          limit:(NSUInteger)limit
                       callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback
{
    AVIMLogsCommand *logsCommand = [[AVIMLogsCommand alloc] init];
    
    logsCommand.cid  = _conversationId;
    logsCommand.l    = (int32_t)[self.class validLimit:limit];
    
    logsCommand.direction = (direction == LCIMMessageQueryDirectionFromOldToNew)
    ? AVIMLogsCommand_QueryDirection_New
    : AVIMLogsCommand_QueryDirection_Old;
    
    LCIMMessageIntervalBound *startIntervalBound = interval.startIntervalBound;
    LCIMMessageIntervalBound *endIntervalBound = interval.endIntervalBound;
    
    logsCommand.mid  = startIntervalBound.messageId;
    logsCommand.tmid = endIntervalBound.messageId;
    
    logsCommand.tIncluded = startIntervalBound.closed;
    logsCommand.ttIncluded = endIntervalBound.closed;
    
    int64_t t = startIntervalBound.timestamp;
    int64_t tt = endIntervalBound.timestamp;
    
    if (t > 0)
        logsCommand.t = t;
    if (tt > 0)
        logsCommand.tt = tt;
    
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    genericCommand.cmd = AVIMCommandType_Logs;
    genericCommand.logsMessage = logsCommand;
    
    [self queryMessagesFromServerWithCommand:genericCommand callback:callback];
}

- (void)postprocessMessages:(NSArray *)messages {
    for (LCIMMessage *message in messages) {
        if (message.status != LCIMMessageStatusFailed) {
            message.status = LCIMMessageStatusSent;
        }
        message.localClientId = self.imClient.clientId;
    }
}

- (void)queryMediaMessagesFromServerWithType:(LCIMMessageMediaType)type
                                       limit:(NSUInteger)limit
                               fromMessageId:(NSString *)messageId
                               fromTimestamp:(int64_t)timestamp
                                    callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    AVIMLogsCommand *logsCommand = [[AVIMLogsCommand alloc] init];
    logsCommand.cid = self.conversationId;
    logsCommand.lctype = type;
    logsCommand.l = (int32_t)[self.class validLimit:limit];
    if (messageId) { logsCommand.mid = messageId; }
    logsCommand.t = [self.class validTimestamp:timestamp];
    AVIMGenericCommand *genericCommand = [[AVIMGenericCommand alloc] init];
    genericCommand.cmd = AVIMCommandType_Logs;
    genericCommand.logsMessage = logsCommand;
    
    LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
    commandWrapper.outCommand = genericCommand;
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(nil, commandWrapper.error);
            }];
            return;
        }
        AVIMLogsCommand *logsInCommand = commandWrapper.inCommand.logsMessage;
        AVIMLogsCommand *logsOutCommand = commandWrapper.outCommand.logsMessage;
        NSMutableArray *messageArray = [[NSMutableArray alloc] init];
        NSEnumerator *reverseLogsArray = logsInCommand.logsArray.reverseObjectEnumerator;
        for (AVIMLogItem *logsItem in reverseLogsArray) {
            LCIMMessage *message = nil;
            id data = [logsItem data_p];
            if (![data isKindOfClass:[NSString class]]) {
                LCLoggerError(LCLoggerDomainIM, @"Received an invalid message.");
                continue;
            }
            LCIMTypedMessageObject *messageObject = [[LCIMTypedMessageObject alloc] initWithJSON:data];
            if ([messageObject isValidTypedMessageObject]) {
                LCIMTypedMessage *m = [LCIMTypedMessage messageWithMessageObject:messageObject];
                message = m;
            } else {
                LCIMMessage *m = [[LCIMMessage alloc] init];
                m.content = data;
                message = m;
            }
            message.clientId = logsItem.from;
            message.conversationId = logsOutCommand.cid;
            message.messageId = logsItem.msgId;
            message.sendTimestamp = logsItem.timestamp;
            message.mentionAll = logsItem.mentionAll;
            message.mentionList = logsItem.mentionPidsArray;
            if (logsItem.hasPatchTimestamp) {
                message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(logsItem.patchTimestamp / 1000.0)];
            }
            message.status = LCIMMessageStatusSent;
            message.localClientId = client.clientId;
            [messageArray addObject:message];
        }
        [client invokeInUserInteractQueue:^{
            callback(messageArray, nil);
        }];
    }];
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Member Info

- (void)getAllMemberInfoWithCallback:(void (^)(NSArray<LCIMConversationMemberInfo *> *, NSError *))callback
{
    [self getAllMemberInfoWithIgnoringCache:false
               forcingRefreshIMSessionToken:false
                             recursionCount:0
                                   callback:callback];
}

- (void)getAllMemberInfoWithIgnoringCache:(BOOL)ignoringCache
                                 callback:(void (^)(NSArray<LCIMConversationMemberInfo *> *, NSError *))callback
{
    [self getAllMemberInfoWithIgnoringCache:ignoringCache
               forcingRefreshIMSessionToken:false
                             recursionCount:0
                                   callback:callback];
}

- (void)getAllMemberInfoWithIgnoringCache:(BOOL)ignoringCache
             forcingRefreshIMSessionToken:(BOOL)forcingRefreshIMSessionToken
                           recursionCount:(NSUInteger)recursionCount
                                 callback:(void (^)(NSArray<LCIMConversationMemberInfo *> *, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    if (!ignoringCache) {
        __block NSArray<LCIMConversationMemberInfo *> *memberInfos = nil;
        [self internalSyncLock:^{
            if (self->_memberInfoTable) {
                memberInfos = self->_memberInfoTable.allValues;
            }
        }];
        if (memberInfos) {
            [client invokeInUserInteractQueue:^{
                callback(memberInfos, nil);
            }];
            return;
        }
    }
    
    [client getSessionTokenWithForcingRefresh:forcingRefreshIMSessionToken callback:^(NSString *sessionToken, NSError *error) {
        
        AssertRunInQueue(self->_internalSerialQueue);
        
        if (error) {
            [self.imClient invokeInUserInteractQueue:^{
                callback(nil, error);
            }];
            return;
        }
        
        LCPaasClient *paasClient = LCPaasClient.sharedInstance;
        NSURLRequest *request = ({
            NSString *whereString = ({
                NSError *error = nil;
                NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"cid" : self->_conversationId } options:0 error:&error];
                if (error) {
                    [self.imClient invokeInUserInteractQueue:^{
                        callback(nil, error);
                    }];
                    return;
                }
                [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            });
            [paasClient requestWithPath:@"classes/_ConversationMemberInfo"
                                 method:@"GET"
                                headers:@{ @"X-LC-IM-Session-Token" : sessionToken }
                             parameters:@{ @"client_id": self->_clientId, @"where": whereString }];
        });
        [paasClient performRequest:request success:^(NSHTTPURLResponse *response, id responseObject) {
            if (![NSDictionary _lc_isTypeOf:responseObject]) {
                [self.imClient invokeInUserInteractQueue:^{
                    callback(nil, LCErrorInternalServer(@"response invalid."));
                }];
                return;
            }
            NSMutableDictionary<NSString *, LCIMConversationMemberInfo *> *memberInfoTable = ({
                NSMutableDictionary<NSString *, LCIMConversationMemberInfo *> *memberInfoTable = [NSMutableDictionary dictionary];
                NSArray *memberInfoDatas = [NSArray _lc_decoding:responseObject key:@"results"];
                for (NSDictionary *dic in memberInfoDatas) {
                    if ([NSDictionary _lc_isTypeOf:dic]) {
                        LCIMConversationMemberInfo *memberInfo = [[LCIMConversationMemberInfo alloc] initWithRawJSONData:dic.mutableCopy conversation:self];
                        NSString *memberId = memberInfo.memberId;
                        if (memberId) {
                            memberInfoTable[memberId] = memberInfo;
                        }
                    }
                }
                NSString *creator = [self creator];
                if (!memberInfoTable[creator]) {
                    NSMutableDictionary<NSString *, NSString *> *mutableDic = [NSMutableDictionary dictionary];
                    mutableDic[LCIMConversationMemberInfoKeyConversationId] = self->_conversationId;
                    mutableDic[LCIMConversationMemberInfoKeyMemberId] = creator;
                    mutableDic[LCIMConversationMemberInfoKeyRole] = LCIMConversationMemberRoleKeyOwner;
                    memberInfoTable[creator] = [[LCIMConversationMemberInfo alloc] initWithRawJSONData:mutableDic conversation:self];
                }
                memberInfoTable;
            });
            /// get memberInfos before set memberInfoTable for thread-safe.
            /// step 1.
            NSArray<LCIMConversationMemberInfo *> *memberInfos = memberInfoTable.allValues;
            /// step 2.
            [self internalSyncLock:^{
                self->_memberInfoTable = memberInfoTable;
            }];
            [self.imClient invokeInUserInteractQueue:^{
                callback(memberInfos, nil);
            }];
        } failure:^(NSHTTPURLResponse *response, id responseObject, NSError *error) {
            if ([NSDictionary _lc_isTypeOf:responseObject] &&
                [responseObject[@"code"] integerValue] == LCIMErrorCodeSessionTokenExpired &&
                recursionCount < 2) {
                [self getAllMemberInfoWithIgnoringCache:ignoringCache
                           forcingRefreshIMSessionToken:true
                                         recursionCount:(recursionCount + 1)
                                               callback:callback];
            } else {
                [self.imClient invokeInUserInteractQueue:^{
                    callback(nil, error);
                }];
            }
        }];
    }];
}

- (void)getMemberInfoWithMemberId:(NSString *)memberId
                         callback:(void (^)(LCIMConversationMemberInfo *, NSError *))callback
{
    [self getMemberInfoWithIgnoringCache:false
                                memberId:memberId
                                callback:callback];
}

- (void)getMemberInfoWithIgnoringCache:(BOOL)ignoringCache
                              memberId:(NSString *)memberId
                              callback:(void (^)(LCIMConversationMemberInfo *, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    if (!ignoringCache) {
        __block BOOL hasCache = false;
        __block LCIMConversationMemberInfo *memberInfo = nil;
        [self internalSyncLock:^{
            if (self->_memberInfoTable) {
                hasCache = true;
                memberInfo = self->_memberInfoTable[memberId];
            }
        }];
        if (hasCache) {
            [client invokeInUserInteractQueue:^{
                callback(memberInfo, nil);
            }];
            return;
        }
    }
    
    [self getAllMemberInfoWithIgnoringCache:ignoringCache forcingRefreshIMSessionToken:false recursionCount:0 callback:^(NSArray<LCIMConversationMemberInfo *> *memberInfos, NSError *error) {
        
        if (error) {
            callback(nil, error);
            return;
        }
        
        __block LCIMConversationMemberInfo *memberInfo = nil;
        [self internalSyncLock:^{
            if (self->_memberInfoTable) {
                memberInfo = self->_memberInfoTable[memberId];
            }
        }];
        
        callback(memberInfo, nil);
    }];
}

- (void)updateMemberRoleWithMemberId:(NSString *)memberId
                                role:(LCIMConversationMemberRole)role
                            callback:(void (^)(BOOL, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    if ([memberId isEqualToString:self.creator]) {
        [client invokeInUserInteractQueue:^{
            NSError *error = ({
                LCIMErrorCode code = LCIMErrorCodeOwnerPromotionNotAllowed;
                LCError(code, LCIMErrorMessage(code), nil);
            });
            callback(false, error);
        }];
        return;
    }
    
    NSString *roleString = LCIMConversationMemberInfo_role_to_key(role);
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        AVIMConvMemberInfo *convMemberInfo = [AVIMConvMemberInfo new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_MemberInfoUpdate;
        outCommand.convMessage = convCommand;
        
        convCommand.cid = self->_conversationId;
        convCommand.targetClientId = memberId;
        convCommand.info = convMemberInfo;
        
        convMemberInfo.pid = memberId;
        if (roleString) {
            convMemberInfo.role = roleString;
        } else {
            [client invokeInUserInteractQueue:^{
                callback(false, LCErrorInternalServer(@"role invalid."));
            }];
            return;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(false, commandWrapper.error);
            }];
            return;
        }
        
        [self internalSyncLock:^{
            if (self->_memberInfoTable) {
                LCIMConversationMemberInfo *memberInfo = self->_memberInfoTable[memberId];
                if (memberInfo) {
                    [memberInfo updateRawJSONDataWithKey:LCIMConversationMemberInfoKeyRole object:roleString];
                } else {
                    NSMutableDictionary<NSString *, NSString *> *mutableDic = [NSMutableDictionary dictionary];
                    mutableDic[LCIMConversationMemberInfoKeyConversationId] = self->_conversationId;
                    mutableDic[LCIMConversationMemberInfoKeyMemberId] = memberId;
                    mutableDic[LCIMConversationMemberInfoKeyRole] = roleString;
                    self->_memberInfoTable[memberId] = [[LCIMConversationMemberInfo alloc] initWithRawJSONData:mutableDic conversation:self];
                }
            }
        }];
        
        [client invokeInUserInteractQueue:^{
            callback(true, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Member Block

- (void)blockMembers:(NSArray<NSString *> *)memberIds
            callback:(void (^)(NSArray<NSString *> *, NSArray<LCIMOperationFailure *> *, NSError *))callback
{
    [self blockOrUnblockMembers:memberIds isBlockAction:true callback:callback];
}

- (void)unblockMembers:(NSArray<NSString *> *)memberIds
              callback:(void (^)(NSArray<NSString *> *, NSArray<LCIMOperationFailure *> *, NSError *))callback
{
    [self blockOrUnblockMembers:memberIds isBlockAction:false callback:callback];
}

- (void)blockOrUnblockMembers:(NSArray<NSString *> *)memberIds
                isBlockAction:(BOOL)isBlockAction
                     callback:(void (^)(NSArray<NSString *> *, NSArray<LCIMOperationFailure *> *, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMSignatureAction action = (isBlockAction ? LCIMSignatureActionBlock : LCIMSignatureActionUnblock);
    
    [client getSignatureWithConversation:self action:action actionOnClientIds:memberIds callback:^(LCIMSignature *signature) {
        
        AssertRunInQueue(self->_internalSerialQueue);
        
        if (signature && signature.error) {
            [self.imClient invokeInUserInteractQueue:^{
                callback(nil, nil, signature.error);
            }];
            return;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = ({
            
            AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
            AVIMBlacklistCommand *blacklistCommand = [AVIMBlacklistCommand new];
            
            outCommand.cmd = AVIMCommandType_Blacklist;
            outCommand.op = (isBlockAction ? AVIMOpType_Block : AVIMOpType_Unblock);
            outCommand.blacklistMessage = blacklistCommand;
            
            blacklistCommand.srcCid = self->_conversationId;
            blacklistCommand.toPidsArray = memberIds.mutableCopy;
            if (signature && signature.signature && signature.timestamp && signature.nonce) {
                blacklistCommand.s = signature.signature;
                blacklistCommand.t = signature.timestamp;
                blacklistCommand.n = signature.nonce;
            }
            
            LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
            commandWrapper.outCommand = outCommand;
            commandWrapper;
        });
        
        [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
            
            if (commandWrapper.error) {
                [client invokeInUserInteractQueue:^{
                    callback(nil, nil, commandWrapper.error);
                }];
                return;
            }
            
            AVIMGenericCommand *inCommand = commandWrapper.inCommand;
            AVIMBlacklistCommand *blacklistCommand = (inCommand.hasBlacklistMessage ? inCommand.blacklistMessage : nil);
            NSMutableArray<LCIMOperationFailure *> *failedPids = [NSMutableArray array];
            for (AVIMErrorCommand *errorCommand in blacklistCommand.failedPidsArray) {
                LCIMOperationFailure *failedResult = [LCIMOperationFailure new];
                failedResult.code = (errorCommand.hasCode ? errorCommand.code : 0);
                failedResult.reason = (errorCommand.hasReason ? errorCommand.reason : nil);
                failedResult.clientIds = errorCommand.pidsArray;
                [failedPids addObject:failedResult];
            }
            
            [client invokeInUserInteractQueue:^{
                callback(blacklistCommand.allowedPidsArray, failedPids, nil);
            }];
        }];
        
        [client sendCommandWrapper:commandWrapper];
    }];
}

- (void)queryBlockedMembersWithLimit:(NSInteger)limit
                                next:(NSString * _Nullable)next
                            callback:(void (^)(NSArray<NSString *> *, NSString *, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMBlacklistCommand *blacklistCommand = [AVIMBlacklistCommand new];
        
        outCommand.cmd = AVIMCommandType_Blacklist;
        outCommand.op = AVIMOpType_Query;
        outCommand.blacklistMessage = blacklistCommand;
        
        blacklistCommand.srcCid = self->_conversationId;
        blacklistCommand.limit = (limit <= 0 ? 50 : (limit > 100 ? 100 : (int32_t)limit));
        if (next) {
            blacklistCommand.next = next;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(nil, nil, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMBlacklistCommand *blacklistCommand = (inCommand.hasBlacklistMessage ? inCommand.blacklistMessage : nil);
        NSString *next = (blacklistCommand.hasNext ? blacklistCommand.next : nil);
        
        [client invokeInUserInteractQueue:^{
            callback(blacklistCommand.blockedPidsArray, next, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Member Mute

- (void)muteMembers:(NSArray<NSString *> *)memberIds
           callback:(void (^)(NSArray<NSString *> *, NSArray<LCIMOperationFailure *> *, NSError *))callback
{
    [self muteOrUnmuteMembers:memberIds isMuteAction:true callback:callback];
}

- (void)unmuteMembers:(NSArray<NSString *> *)memberIds
             callback:(void (^)(NSArray<NSString *> *, NSArray<LCIMOperationFailure *> *, NSError *))callback
{
    [self muteOrUnmuteMembers:memberIds isMuteAction:false callback:callback];
}

- (void)muteOrUnmuteMembers:(NSArray<NSString *> *)memberIds
               isMuteAction:(BOOL)isMuteAction
                   callback:(void (^)(NSArray<NSString *> *, NSArray<LCIMOperationFailure *> *, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = (isMuteAction ? AVIMOpType_AddShutup : AVIMOpType_RemoveShutup);
        outCommand.convMessage = convCommand;
        
        convCommand.cid = self->_conversationId;
        convCommand.mArray = memberIds.mutableCopy;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(nil, nil, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        NSMutableArray<LCIMOperationFailure *> *failedPids = [NSMutableArray array];
        for (AVIMErrorCommand *errorCommand in convCommand.failedPidsArray) {
            LCIMOperationFailure *failedResult = [LCIMOperationFailure new];
            failedResult.code = (errorCommand.hasCode ? errorCommand.code : 0);
            failedResult.reason = (errorCommand.hasReason ? errorCommand.reason : nil);
            failedResult.clientIds = errorCommand.pidsArray;
            [failedPids addObject:failedResult];
        }
        
        [client invokeInUserInteractQueue:^{
            callback(convCommand.allowedPidsArray, failedPids, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)queryMutedMembersWithLimit:(NSInteger)limit
                              next:(NSString * _Nullable)next
                          callback:(void (^)(NSArray<NSString *> *, NSString *, NSError *))callback
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_QueryShutup;
        outCommand.convMessage = convCommand;
        
        convCommand.cid = self->_conversationId;
        convCommand.limit = (limit <= 0 ? 50 : (limit > 100 ? 100 : (int32_t)limit));
        if (next) {
            convCommand.next = next;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMClient *client, LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [client invokeInUserInteractQueue:^{
                callback(nil, nil, commandWrapper.error);
            }];
            return;
        }
        
        AVIMGenericCommand *inCommand = commandWrapper.inCommand;
        AVIMConvCommand *convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil);
        NSString *next = (convCommand.hasNext ? convCommand.next : nil);
        
        [client invokeInUserInteractQueue:^{
            callback(convCommand.mArray, next, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

// MARK: - Event Handler

- (LCIMMessage *)processDirect:(AVIMDirectCommand *)directCommand messageId:(NSString *)messageId isTransientMsg:(BOOL)isTransientMsg
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return nil;
    }
    AssertRunInQueue(self->_internalSerialQueue);
    
    NSString *content = (directCommand.hasMsg ? directCommand.msg : nil);
    int64_t timestamp = (directCommand.hasTimestamp ? directCommand.timestamp : 0);
    if (!content || !timestamp) {
        /// @note
        /// 1. message must with `msg` and `timestamp`, otherwise it's invalid.
        /// 2. directCommand's other properties is nullable or optional.
        return nil;
    }
    
    LCIMMessage *message = ({
        LCIMMessage *message = nil;
        LCIMTypedMessageObject *messageObject = [[LCIMTypedMessageObject alloc] initWithJSON:content];
        if ([messageObject isValidTypedMessageObject]) {
            message = [LCIMTypedMessage messageWithMessageObject:messageObject];
        } else {
            message = [[LCIMMessage alloc] init];
        }
        message.conversationId = self->_conversationId;
        message.messageId = messageId;
        message.clientId = (directCommand.hasFromPeerId ? directCommand.fromPeerId : nil);
        message.localClientId = self->_clientId;
        message.content = content;
        message.transient = isTransientMsg;
        message.sendTimestamp = timestamp;
        message.offline = (directCommand.hasOffline ? directCommand.offline : false);
        message.hasMore = (directCommand.hasHasMore ? directCommand.hasMore : false);
        message.mentionAll = (directCommand.hasMentionAll ? directCommand.mentionAll : false);
        message.mentionList = directCommand.mentionPidsArray;
        message.updatedAt = (directCommand.hasPatchTimestamp ? [NSDate dateWithTimeIntervalSince1970:(directCommand.patchTimestamp / 1000.0)] : nil);
        if (message.ioType == LCIMMessageIOTypeOut) {
            message.status = LCIMMessageStatusSent;
        } else {
            message.status = LCIMMessageStatusDelivered;
        }
        message;
    });
    
    if (!isTransientMsg) {
        BOOL shouldIncreaseUnreadCount = [self updateLastMessage:message client:client];
        if (shouldIncreaseUnreadCount) {
            [self internalSyncLock:^{
                self->_unreadMessagesCount += 1;
            }];
            [client conversation:self didUpdateForKeys:@[LCIMConversationUpdatedKeyUnreadMessagesCount]];
        }
        if (client.messageQueryCacheEnabled) {
            LCIMMessageCacheStore *cacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
            [cacheStore insertOrUpdateMessage:message withBreakpoint:YES];
        }
    }
    
    return message;
}

- (NSInteger)processUnread:(AVIMUnreadTuple *)unreadTuple
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return -1;
    }
    AssertRunInQueue(self->_internalSerialQueue);
    
    if (!unreadTuple || !unreadTuple.hasUnread) {
        return -1;
    }
    
    NSInteger unreadCount = unreadTuple.unread;
    BOOL mentioned = (unreadTuple.hasMentioned ? unreadTuple.mentioned : false);
    
    if (unreadCount > 0) {
        LCIMMessage *lastMessage = ({
            LCIMMessage *lastMessage = nil;
            NSString *content = (unreadTuple.hasData_p ? unreadTuple.data_p : nil);
            NSString *messageId = (unreadTuple.hasMid ? unreadTuple.mid : nil);
            int64_t timestamp = (unreadTuple.hasTimestamp ? unreadTuple.timestamp : 0);
            NSString *fromId = (unreadTuple.hasFrom ? unreadTuple.from : nil);
            if (content && messageId && timestamp && fromId) {
                LCIMTypedMessageObject *typedMessageObject = [[LCIMTypedMessageObject alloc] initWithJSON:content];
                if ([typedMessageObject isValidTypedMessageObject]) {
                    lastMessage = [LCIMTypedMessage messageWithMessageObject:typedMessageObject];
                } else {
                    lastMessage = [[LCIMMessage alloc] init];
                }
                int64_t patchTimestamp = (unreadTuple.hasPatchTimestamp ? unreadTuple.patchTimestamp : 0);
                lastMessage.status = LCIMMessageStatusDelivered;
                lastMessage.conversationId = self->_conversationId;
                lastMessage.content = content;
                lastMessage.messageId = messageId;
                lastMessage.sendTimestamp = timestamp;
                lastMessage.clientId = fromId;
                lastMessage.localClientId = self->_clientId;
                lastMessage.updatedAt = [NSDate dateWithTimeIntervalSince1970:(patchTimestamp / 1000.0)];
            }
            lastMessage;
        });
        if (lastMessage) {
            BOOL shouldUpdateUnreadCount = [self updateLastMessage:lastMessage client:client];
            if (shouldUpdateUnreadCount) {
                [self internalSyncLock:^{
                    self->_unreadMessagesCount = unreadCount;
                }];
                [client conversation:self didUpdateForKeys:@[LCIMConversationUpdatedKeyUnreadMessagesCount]];
            }
        }
    } else if (unreadCount == 0) {
        [self internalSyncLock:^{
            self->_unreadMessagesCount = 0;
        }];
        [client conversation:self didUpdateForKeys:@[LCIMConversationUpdatedKeyUnreadMessagesCount]];
    }
    
    self->_unreadMessagesMentioned = mentioned;
    [client conversation:self didUpdateForKeys:@[LCIMConversationUpdatedKeyUnreadMessagesMentioned]];
    
    return unreadCount;
}

- (LCIMMessage *)processPatchModified:(AVIMPatchItem *)patchItem
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return nil;
    }
    AssertRunInQueue(self->_internalSerialQueue);
    
    NSString *content = (patchItem.hasData_p ? patchItem.data_p : nil);
    NSString *messageId = (patchItem.hasMid ? patchItem.mid : nil);
    int64_t timestamp = (patchItem.hasTimestamp ? patchItem.timestamp : 0);
    NSString *fromId = (patchItem.hasFrom ? patchItem.from : nil);
    int64_t patchTimestamp = (patchItem.hasPatchTimestamp ? patchItem.patchTimestamp : 0);
    if (!content || !messageId || !timestamp || !fromId || !patchTimestamp) {
        return nil;
    }
    
    LCIMMessage *patchMessage = ({
        LCIMMessage *message = nil;
        LCIMTypedMessageObject *messageObject = [[LCIMTypedMessageObject alloc] initWithJSON:content];
        if ([messageObject isValidTypedMessageObject]) {
            message = [LCIMTypedMessage messageWithMessageObject:messageObject];
        } else {
            message = [[LCIMMessage alloc] init];
        }
        message.messageId = messageId;
        message.content = content;
        message.sendTimestamp = timestamp;
        message.clientId = fromId;
        message.conversationId = self->_conversationId;
        message.localClientId = self->_clientId;
        message.status = LCIMMessageStatusDelivered;
        message.mentionAll = (patchItem.hasMentionAll ? patchItem.mentionAll : false);
        message.mentionList = patchItem.mentionPidsArray;
        message.updatedAt = [NSDate dateWithTimeIntervalSince1970:(patchTimestamp / 1000.0)];
        if (patchItem.hasRecall && patchItem.recall &&
            [message isKindOfClass:[LCIMRecalledMessage class]]) {
            ((LCIMRecalledMessage *)message).isRecall = true;
        }
        message;
    });
    
    [self updateLastMessage:patchMessage client:client];
    
    if (client.messageQueryCacheEnabled) {
        LCIMMessageCacheStore *messageCacheStore = [[LCIMMessageCacheStore alloc] initWithClientId:self->_clientId conversationId:self->_conversationId];
        [messageCacheStore insertOrUpdateMessage:patchMessage withBreakpoint:YES];
    }
    
    return patchMessage;
}

- (LCIMMessage *)processRCP:(AVIMRcpCommand *)rcpCommand isRead:(BOOL)isRead
{
    LCIMClient *client = self.imClient;
    if (!client) {
        return nil;
    }
    AssertRunInQueue(self->_internalSerialQueue);
    
    NSString *messageId = (rcpCommand.hasId_p ? rcpCommand.id_p : nil);
    int64_t timestamp = (rcpCommand.hasT ? rcpCommand.t : 0);
    
    __block LCIMMessage *message = nil;
    if (messageId && !isRead) {
        [self internalSyncLock:^{
            message = self->_rcpMessageTable[messageId];
            [self->_rcpMessageTable removeObjectForKey:messageId];
        }];
        if (message) {
            message.status = LCIMMessageStatusDelivered;
            message.deliveredTimestamp = timestamp;
        }
    }
    
    [self internalSyncLock:^{
        if (isRead) {
            self->_lastReadTimestamp = timestamp;
        } else {
            self->_lastDeliveredTimestamp = timestamp;
        }
    }];
    
    [client conversation:self didUpdateForKeys:@[(isRead ? LCIMConversationUpdatedKeyLastReadAt : LCIMConversationUpdatedKeyLastDeliveredAt)]];
    
    return message;
}

- (void)processConvUpdatedAttr:(NSDictionary *)attr attrModified:(NSDictionary *)attrModified
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    [self internalSyncLock:^{
        processAttrAndAttrModified(attr, attrModified, self->_rawJSONData);
    }];
    
    [self removeCachedConversation];
}

- (void)processMemberInfoChanged:(NSString *)memberId role:(NSString *)role
{
    AssertRunInQueue(self->_internalSerialQueue);
    
    if (!memberId || !role) {
        return;
    }
    
    [self internalSyncLock:^{
        if (self->_memberInfoTable) {
            LCIMConversationMemberInfo *memberInfo = self->_memberInfoTable[memberId];
            if (memberInfo) {
                [memberInfo updateRawJSONDataWithKey:LCIMConversationMemberInfoKeyRole object:role];
            } else {
                NSMutableDictionary<NSString *, NSString *> *mutableDic = [NSMutableDictionary dictionary];
                mutableDic[LCIMConversationMemberInfoKeyConversationId] = self->_conversationId;
                mutableDic[LCIMConversationMemberInfoKeyMemberId] = memberId;
                mutableDic[LCIMConversationMemberInfoKeyRole] = role;
                self->_memberInfoTable[memberId] = [[LCIMConversationMemberInfo alloc] initWithRawJSONData:mutableDic conversation:self];
            }
        }
    }];
}

#pragma mark - Keyed Conversation

- (LCIMKeyedConversation *)keyedConversation
{
    LCIMKeyedConversation *keyedConversation = [LCIMKeyedConversation new];
    keyedConversation.conversationId = self.conversationId;
    keyedConversation.clientId = self.clientId;
    keyedConversation.creator = self.creator;
    keyedConversation.createAt = self.createdAt;
    keyedConversation.updateAt = self.updatedAt;
    keyedConversation.lastMessageAt = self.lastMessageAt;
    keyedConversation.lastDeliveredAt = self.lastDeliveredAt;
    keyedConversation.lastReadAt = self.lastReadAt;
    keyedConversation.lastMessage = self.lastMessage;
    keyedConversation.name = self.name;
    keyedConversation.members = self.members;
    keyedConversation.attributes = self.attributes;
    keyedConversation.uniqueId = self.uniqueId;
    keyedConversation.unique = self.unique;
    keyedConversation.transient = self.transient;
    keyedConversation.system = self.system;
    keyedConversation.temporary = self.temporary;
    keyedConversation.temporaryTTL = self.temporaryTTL;
    keyedConversation.muted = self.muted;
    keyedConversation.rawDataDic = self.rawJSONDataCopy;
    return keyedConversation;
}

@end

@implementation LCIMChatRoom

@end

@implementation LCIMServiceConversation

- (void)subscribeWithCallback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self joinWithCallback:callback];
}

- (void)unsubscribeWithCallback:(void (^)(BOOL, NSError * _Nullable))callback
{
    [self quitWithCallback:callback];
}

@end

@implementation LCIMTemporaryConversation

@end
