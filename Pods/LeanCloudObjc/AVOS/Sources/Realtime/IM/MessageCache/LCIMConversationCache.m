//
//  LCIMConversationCache.m
//  LeanCloud
//
//  Created by Tang Tianyong on 8/31/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMConversationCache.h"
#import "LCIMConversationCacheStore.h"
#import "LCIMConversationQueryCacheStore.h"
#import "LCIMConversation.h"

@interface LCIMConversationCache ()

@property (nonatomic, strong) LCIMConversationCacheStore *cacheStore;
@property (nonatomic, strong) LCIMConversationQueryCacheStore *queryCacheStore;

@end

@implementation LCIMConversationCache

- (instancetype)initWithClientId:(NSString *)clientId {
    self = [super init];

    if (self) {
        _clientId = [clientId copy];
        _queryCacheStore = [[LCIMConversationQueryCacheStore alloc] initWithClientId:clientId];
    }

    return self;
}

- (LCIMConversation *)conversationForId:(NSString *)conversationId {
    return [self.cacheStore conversationForId:conversationId];
}

- (NSArray *)conversationIdsFromConversations:(NSArray *)conversations {
    NSMutableArray *conversationIds = [NSMutableArray array];

    for (LCIMConversation *conversation in conversations) {
        if (conversation.conversationId) {
            [conversationIds addObject:conversation.conversationId];
        }
    }

    return conversationIds;
}

- (void)cacheConversations:(NSArray *)conversations maxAge:(NSTimeInterval)maxAge forCommand:(LCIMConversationOutCommand *)command {
    NSArray *conversationIds = [self conversationIdsFromConversations:conversations];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.queryCacheStore cacheConversationIds:conversationIds forCommand:command];
        [self.cacheStore insertConversations:conversations maxAge:maxAge];
    });
}

- (NSArray *)conversationsForCommand:(LCIMConversationOutCommand *)command {
    NSArray *result = nil;
    NSArray *conversationIds = [self.queryCacheStore conversationIdsForCommand:command];

    if ([conversationIds count]) {
        result = [self.cacheStore conversationsForIds:conversationIds];

        if (![result count]) {
            [self.queryCacheStore removeConversationIdsForCommand:command];
        }
    } else if (conversationIds) {
        result = @[];
    } else {
        result = nil;
    }

    return result;
}

- (void)removeConversationForId:(NSString *)conversationId {
    [self.cacheStore deleteConversationForId:conversationId];
}

- (void)removeConversationAndItsMessagesForId:(NSString *)conversationId {
    [self.cacheStore deleteConversationAndItsMessagesForId:conversationId];
}

- (void)cleanAllExpiredConversations {
    [self.cacheStore cleanAllExpiredConversations];
}

- (void)updateConversationForLastMessageAt:(NSDate *)lastMessageAt conversationId:(NSString *)conversationId {
    [self.cacheStore updateConversationForLastMessageAt:lastMessageAt conversationId:conversationId];
}

#pragma mark - Lazy loading

- (LCIMConversationCacheStore *)cacheStore {
    if (_cacheStore)
        return _cacheStore;

    @synchronized (self) {
        if (_cacheStore)
            return _cacheStore;

        _cacheStore = [[LCIMConversationCacheStore alloc] initWithClientId:self.clientId];
        _cacheStore.client = self.client;

        return _cacheStore;
    }
}

@end
