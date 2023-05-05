//
//  LCIMMessageObject.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/28/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMDynamicObject.h"
#import "LCIMMessage.h"

@interface LCIMMessageObject : LCIMDynamicObject

@property (nonatomic, assign) LCIMMessageIOType  ioType;
@property (nonatomic, assign) LCIMMessageStatus  status;
@property (nonatomic,   copy) NSString          *messageId;
@property (nonatomic,   copy) NSString          *clientId;
@property (nonatomic,   copy) NSString          *conversationId;
@property (nonatomic,   copy) NSString          *content;
@property (nonatomic, assign) int64_t            sendTimestamp;
@property (nonatomic, assign) int64_t            deliveredTimestamp;
@property (nonatomic, assign) int64_t            readTimestamp;
@property (nonatomic,   copy) NSDate            *updatedAt;

@end
