//
//  LCIMTypedMessageObject.m
//  LeanCloudIM
//
//  Created by Qihe Bian on 1/8/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMTypedMessageObject.h"
#import "LCIMTypedMessage_Internal.h"
#import "LCUtils.h"

@implementation LCIMTypedMessageObject

- (int32_t)_lctype {
    return [NSNumber _lc_decoding:self.localData key:@"_lctype"].intValue;
}

- (void)set_lctype:(int32_t)_lctype {
    [self setObject:@(_lctype) forKey:@"_lctype"];
}

- (NSString *)_lctext {
    return [NSString _lc_decoding:self.localData key:@"_lctext"];
}

- (void)set_lctext:(NSString *)_lctext {
    [self setObject:_lctext forKey:@"_lctext"];
}

- (NSDictionary *)_lcfile {
    return [NSDictionary _lc_decoding:self.localData key:@"_lcfile"];
}

- (void)set_lcfile:(NSDictionary *)_lcfile {
    [self setObject:_lcfile forKey:@"_lcfile"];
}

- (NSDictionary *)_lcattrs {
    return [NSDictionary _lc_decoding:self.localData key:@"_lcattrs"];
}

- (void)set_lcattrs:(NSDictionary *)_lcattrs {
    [self setObject:_lcattrs forKey:@"_lcattrs"];
}

- (NSDictionary *)_lcloc {
    return [NSDictionary _lc_decoding:self.localData key:@"_lcloc"];
}

- (void)set_lcloc:(NSDictionary *)_lcloc {
    [self setObject:_lcloc forKey:@"_lcloc"];
}

- (BOOL)isValidTypedMessageObject
{
    NSNumber *typeNumber = [NSNumber _lc_decoding:self.localData
                                              key:@"_lctype"];
    return ((typeNumber != nil)
            ? ([_typeDict objectForKey:typeNumber] ? true : false)
            : false);
}

@end
