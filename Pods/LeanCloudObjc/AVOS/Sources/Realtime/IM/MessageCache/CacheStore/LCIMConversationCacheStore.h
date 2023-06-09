//
//  LCIMConversationCacheStore.h
//  LeanCloud
//
//  Created by Tang Tianyong on 8/29/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMCacheStore.h"

@class LCIMClient;
@class LCIMConversation;

@interface LCIMConversationCacheStore : LCIMCacheStore

@property (nonatomic, weak) LCIMClient *client;

/*!
 * Cache conversations with max age.
 * @param conversations Conversations to be cached.
 * @param maxAge Max cache age, expiration interval.
 */
- (void)insertConversations:(NSArray *)conversations maxAge:(NSTimeInterval)maxAge;

/*!
 * Cache conversations with default max age, an hour (24 x 60 x 60).
 * @see `- (void)insertConversations:(NSArray *)conversations maxAge:(NSTimeInterval)maxAge;`
 */
- (void)insertConversations:(NSArray *)conversations;

/*!
 * Delete a conversation.
 * @param conversation Conversation to be deleted from cache.
 */
- (void)deleteConversation:(LCIMConversation *)conversation;

/*!
 * Delete a conversation by id.
 * @param conversationId ID of conversation to be deleted from cache.
 */
- (void)deleteConversationForId:(NSString *)conversationId;

/*!
 * Delete a conversation and it's messages.
 * @see `- (void)deleteConversation:(LCIMConversation *)conversation;`.
 * NOTE: All conversation's message will also be deleted from message table.
 */
- (void)deleteConversationAndItsMessagesForId:(NSString *)conversationId;

/*!
 * update conversation lastMessageAt.
 */
- (void)updateConversationForLastMessageAt:(NSDate *)lastMessageAt conversationId:(NSString *)conversationId;

/*!
 * Get conversation from cache by id.
 * @param conversationId Conversation id.
 * @return A conversation or nil if conversation not found or expired.
 */
- (LCIMConversation *)conversationForId:(NSString *)conversationId;

/*!
 * Get conversation list from cache by ids.
 * @param conversationIds Conversation id list.
 * @return A conversation list.
 * NOTE: If any conversation not found or expired, return an empty list.
 */
- (NSArray *)conversationsForIds:(NSArray *)conversationIds;

/*!
 * Clean all expired conversations.
 */
- (void)cleanAllExpiredConversations;

@end
