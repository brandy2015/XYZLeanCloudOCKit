//
//  LCIMConversationCache.h
//  LeanCloud
//
//  Created by Tang Tianyong on 8/31/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCIMClient;
@class LCIMConversation;
@class LCIMConversationOutCommand;

@interface LCIMConversationCache : NSObject

@property (nonatomic, weak) LCIMClient *client;
@property (nonatomic, copy, readonly) NSString *clientId;

- (instancetype)initWithClientId:(NSString *)clientId;

/*!
 * Get cached conversation by id.
 * @param conversationId Conversation ID.
 * @return A conversation or nil if conversation not found or expired.
 */
- (LCIMConversation *)conversationForId:(NSString *)conversationId;

/*!
 * Cache conversations for query command with max age.
 * @param conversations Conversations to be cached.
 * @param maxAge Max cache age, expiration interval.
 * @param command Conversation query command.
 */
- (void)cacheConversations:(NSArray *)conversations maxAge:(NSTimeInterval)maxAge forCommand:(LCIMConversationOutCommand *)command;

/*!
 * Get alive cached conversations for command.
 * @param command Conversation query command.
 * @return All alive (not expired) cached conversations or nil if cache not found.
 */
- (NSArray *)conversationsForCommand:(LCIMConversationOutCommand *)command;

/*!
 * Remove conversations from cache.
 * @param conversationId ID of conversation to be removed.
 */
- (void)removeConversationForId:(NSString *)conversationId;

/*!
 * Remove conversations and it's messages from cache.
 * @param conversationId ID of conversation to be removed.
 */
- (void)removeConversationAndItsMessagesForId:(NSString *)conversationId;

/*!
 * Clean all expired conversations.
 */
- (void)cleanAllExpiredConversations;

/*!
 * update conversation lastMessageAt.
 */
- (void)updateConversationForLastMessageAt:(NSDate *)lastMessageAt conversationId:(NSString *)conversationId;

@end
