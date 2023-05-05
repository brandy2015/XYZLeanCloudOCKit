//
//  LCIMBlockHelper.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/9/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon.h"

@interface LCIMBlockHelper : NSObject

+ (void)callBooleanResultBlock:(LCIMBooleanResultBlock)block
                         error:(NSError *)error;

+ (void)callIntegerResultBlock:(LCIMIntegerResultBlock)block
                        number:(NSInteger)number
                         error:(NSError *)error;

+ (void)callArrayResultBlock:(LCIMArrayResultBlock)block
                       array:(NSArray *)array
                       error:(NSError *)error;

+ (void)callConversationResultBlock:(LCIMConversationResultBlock)block
                       conversation:(LCIMConversation *)conversation
                              error:(NSError *)error;

@end
