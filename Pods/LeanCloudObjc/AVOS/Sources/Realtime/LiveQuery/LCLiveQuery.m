//
//  LCLiveQuery.m
//  LeanCloud
//
//  Created by Tang Tianyong on 15/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCLiveQuery_Internal.h"
#import "LCSubscriber.h"

#import "LCUser.h"
#import "LCQuery.h"
#import "LCQuery_Internal.h"
#import "LCPaasClient.h"
#import "LCUtils.h"

static NSString *const LCQueryIdKey = @"query_id";

static NSString *const LCSubscriptionEndpoint = @"LiveQuery/subscribe";
static NSString *const LCUnsubscriptionEndpoint = @"LiveQuery/unsubscribe";

@interface LCLiveQuery ()

@property (nonatomic, copy) NSString *queryId;
@property (nonatomic, weak) LCSubscriber *subscriber;

@end

@implementation LCLiveQuery

- (instancetype)initWithQuery:(LCQuery *)query {
    self = [super init];

    if (self) {
        _query = query;
        _subscriber = [LCSubscriber sharedInstance];
    }

    return self;
}

- (void)observeSubscriber {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(eventDidReceive:)
                                                 name:LCLiveQueryEventNotification
                                               object:self.subscriber];
}

- (void)stopToObserveSubscriber {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:LCLiveQueryEventNotification
                                                  object:self.subscriber];
}

- (void)eventDidReceive:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSDictionary *event = userInfo[LCLiveQueryEventKey];

    /* Filter out other live query events. */
    if (![event[LCQueryIdKey] isEqualToString:self.queryId])
        return;

    NSString *operation = event[@"op"];
    NSString *signature = [NSString stringWithFormat:@"handleEvent%@:", [operation capitalizedString]];

    SEL selector = NSSelectorFromString(signature);
    IMP function = [self methodForSelector:selector];

    if (function) {
        ((void (*)(id, SEL, id))function)(self, selector, event);
    }
}

- (void)callDelegateMethod:(SEL)selector object:(id)object withArguments:(NSArray *)arguments {
    if (!object)
        return;

    if (![self.delegate respondsToSelector:selector])
        return;

    NSMethodSignature *signature = [[self.delegate class] instanceMethodSignatureForSelector:selector];

    if (!signature)
        return;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

    invocation.target = self.delegate;
    invocation.selector = selector;

    [invocation setArgument:(void *)&self atIndex:2];
    [invocation setArgument:(void *)&object atIndex:3];

    for (NSInteger i = 0, argc = arguments.count; i < argc; ++i) {
        id argument = arguments[i];
        [invocation setArgument:&argument atIndex:4 + i];
    }

    [invocation retainArguments];

    dispatch_async(dispatch_get_main_queue(), ^{
        [invocation invoke];
    });
}

- (void)handleEventCreate:(NSDictionary *)event {
    LCObject *object = event[@"object"];

    [self callDelegateMethod:@selector(liveQuery:objectDidCreate:)
                      object:object
               withArguments:nil];
}

- (void)handleEventUpdate:(NSDictionary *)event {
    LCObject *object = event[@"object"];
    NSArray *updatedKeys = event[@"updatedKeys"] ?: @[];

    [self callDelegateMethod:@selector(liveQuery:objectDidUpdate:updatedKeys:)
                      object:object
               withArguments:@[updatedKeys]];
}

- (void)handleEventDelete:(NSDictionary *)event {
    LCObject *object = event[@"object"];

    [self callDelegateMethod:@selector(liveQuery:objectDidDelete:)
                      object:object
               withArguments:nil];
}

- (void)handleEventEnter:(NSDictionary *)event {
    LCObject *object = event[@"object"];
    NSArray *updatedKeys = event[@"updatedKeys"] ?: @[];

    [self callDelegateMethod:@selector(liveQuery:objectDidEnter:updatedKeys:)
                      object:object
               withArguments:@[updatedKeys]];
}

- (void)handleEventLeave:(NSDictionary *)event {
    LCObject *object = event[@"object"];
    NSArray *updatedKeys = event[@"updatedKeys"] ?: @[];

    [self callDelegateMethod:@selector(liveQuery:objectDidLeave:updatedKeys:)
                      object:object
               withArguments:@[updatedKeys]];
}

- (void)handleEventLogin:(NSDictionary *)event {
    LCUser *user = event[@"object"];

    [self callDelegateMethod:@selector(liveQuery:userDidLogin:)
                      object:user
               withArguments:nil];
}

- (NSDictionary *)subscriptionParameters {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    query[@"className"] = self.query.className;
    query[@"where"]     = [self.query whereJSONDictionary];
    query[@"keys"]      = self.query.selectedKeys;

    if (self.query.includeACL)
        query[@"returnACL"] = @(YES);

    parameters[@"query"] = query;
    parameters[@"sessionToken"] = [LCUser currentUser].sessionToken;
    parameters[@"id"] = self.subscriber.identifier;

    return parameters;
}

- (void)subscribeWithCallback:(void (^)(BOOL, NSError *))callback
{
    [self observeSubscriber];
    
    __weak typeof(self) weakSelf = self;
    
    [self.subscriber loginWithCallback:^(BOOL succeeded, NSError *error) {
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if (!strongSelf) {
            
            return;
        }
        
        if (error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(false, error);
            });
            
            return;
        }
        
        NSDictionary *parameters = [strongSelf subscriptionParameters];
        
        void (^block)(id object, NSError *error) = ^(id object, NSError *error) {
            
            if (error) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    callback(false, error);
                });
                
                return;
            }
            
            strongSelf.queryId = object[LCQueryIdKey];
            
            [strongSelf.subscriber addLiveQueryObjectToWeakTable:strongSelf];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                callback(true, nil);
            });
        };
        
        [[LCPaasClient sharedInstance] postObject:LCSubscriptionEndpoint
                                   withParameters:parameters
                                            block:block];
    }];
}

- (NSDictionary *)unsubscriptionParameters {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    parameters[@"id"] = self.subscriber.identifier;
    parameters[LCQueryIdKey] = self.queryId;

    return parameters;
}

- (void)unsubscribeWithCallback:(LCBooleanResultBlock)callback {
    [self stopToObserveSubscriber];

    NSDictionary *parameters = [self unsubscriptionParameters];

    LCIdResultBlock block = ^(id object, NSError *error) {
        if (error) {
            [LCUtils callBooleanResultBlock:callback error:error];
            return;
        }
        
        [self.subscriber removeLiveQueryObjectFromWeakTable:self];

        [LCUtils callBooleanResultBlock:callback error:nil];
    };

    [[LCPaasClient sharedInstance] postObject:LCUnsubscriptionEndpoint
                               withParameters:parameters
                                        block:block];
}

- (void)resubscribe
{
    if (self.query) {
        
        NSDictionary *parameters = [self subscriptionParameters];
        
        [[LCPaasClient sharedInstance] postObject:LCSubscriptionEndpoint withParameters:parameters block:^(id  _Nullable object, NSError * _Nullable error) {
            // do nothing.
        }];
    }
}

@end
