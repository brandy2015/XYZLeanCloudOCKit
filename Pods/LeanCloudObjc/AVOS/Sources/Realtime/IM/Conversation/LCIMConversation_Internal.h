//
//  LCIMConversation_Internal.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/12/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMConversation.h"
#import "LCIMCommon_Internal.h"
#import "MessagesProtoOrig.pbobjc.h"

@interface LCIMConversation ()

@property (nonatomic, readonly) LCIMConvType convType;
#if DEBUG
@property (nonatomic, readonly) NSMutableDictionary<NSString *, LCIMConversationMemberInfo *> *memberInfoTable;
#endif

+ (instancetype)conversationWithRawJSONData:(NSMutableDictionary *)rawJSONData
                                     client:(LCIMClient *)client;

- (void)setRawJSONData:(NSMutableDictionary *)rawJSONData;
- (void)updateRawJSONDataWith:(NSDictionary *)dictionary;
- (NSDictionary *)rawJSONDataCopy;

- (void)addMembers:(NSArray<NSString *> *)members;
- (void)removeMembers:(NSArray<NSString *> *)members;

- (LCIMMessage *)processDirect:(AVIMDirectCommand *)directCommand messageId:(NSString *)messageId isTransientMsg:(BOOL)isTransientMsg;
- (LCIMMessage *)processRCP:(AVIMRcpCommand *)rcpCommand isRead:(BOOL)isRead;
- (NSInteger)processUnread:(AVIMUnreadTuple *)unreadTuple;
- (LCIMMessage *)processPatchModified:(AVIMPatchItem *)patchItem;
- (void)processConvUpdatedAttr:(NSDictionary *)attr attrModified:(NSDictionary *)attrModified;
- (void)processMemberInfoChanged:(NSString *)memberId role:(NSString *)role;

- (void)queryMessagesFromServerBeforeId:(NSString *)messageId
                              timestamp:(int64_t)timestamp
                                  limit:(NSUInteger)limit
                               callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback;

- (void)queryMessagesFromServerBeforeId:(NSString *)messageId
                              timestamp:(int64_t)timestamp
                            toMessageId:(NSString *)toMessageId
                            toTimestamp:(int64_t)toTimestamp
                                  limit:(NSUInteger)limit
                               callback:(void (^)(NSArray<LCIMMessage *> * messages, NSError * error))callback;



@end

@interface LCIMChatRoom ()

@end

@interface LCIMServiceConversation ()

@end

@interface LCIMTemporaryConversation ()

@end
