//
//  LCIMErrorUtil.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/20/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LCIMCommon.h"
#import "MessagesProtoOrig.pbobjc.h"

FOUNDATION_EXPORT NSString *LCIMErrorMessage(LCIMErrorCode code);

FOUNDATION_EXPORT NSError *LCErrorFromErrorCommand(AVIMErrorCommand *command);
FOUNDATION_EXPORT NSError *LCErrorFromSessionCommand(AVIMSessionCommand *command);
FOUNDATION_EXPORT NSError *LCErrorFromAckCommand(AVIMAckCommand *command);
