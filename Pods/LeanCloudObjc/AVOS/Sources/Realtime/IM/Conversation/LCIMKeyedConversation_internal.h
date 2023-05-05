//
//  LCIMKeyedConversation_internal.h
//  LeanCloud
//
//  Created by Tang Tianyong on 6/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMKeyedConversation.h"

@class LCIMMessage;

@interface LCIMKeyedConversation ()

@property (nonatomic, copy)   NSString     *conversationId;
@property (nonatomic, copy)   NSString     *clientId;
@property (nonatomic, copy)   NSString     *creator;
@property (nonatomic, strong) NSDate       *createAt;
@property (nonatomic, strong) NSDate       *updateAt;
@property (nonatomic, strong) NSDate       *lastMessageAt;
@property (nonatomic, strong) NSDate       *lastDeliveredAt;
@property (nonatomic, strong) NSDate       *lastReadAt;
@property (nonatomic, strong) LCIMMessage  *lastMessage;
@property (nonatomic, copy)   NSString     *name;
@property (nonatomic, strong) NSArray      *members;
@property (nonatomic, strong) NSDictionary *attributes;

@property (nonatomic, strong) NSString *uniqueId;

@property (nonatomic, assign) BOOL    unique;
@property (nonatomic, assign) BOOL    transient;
@property (nonatomic, assign) BOOL    system;
@property (nonatomic, assign) BOOL    temporary;
@property (nonatomic, assign) NSUInteger temporaryTTL;
@property (nonatomic, assign) BOOL    muted;

@property (nonatomic, strong) NSMutableDictionary *properties;
@property (nonatomic, strong) NSDictionary *rawDataDic;

@end
