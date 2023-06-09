//
//  LCSubscriber.m
//  LeanCloud
//
//  Created by Tang Tianyong on 16/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCSubscriber.h"
#import "LCLiveQuery_Internal.h"

#import "LCApplication_Internal.h"
#import "LCUtils_Internal.h"
#import "LCObjectUtils.h"
#import "LCErrorUtils.h"

#import "LCRTMConnection.h"
#import "MessagesProtoOrig.pbobjc.h"
#import "LCIMErrorUtil.h"

static NSString * const LCIdentifierPrefix = @"livequery";
NSString * const LCLiveQueryEventKey = @"LCLiveQueryEventKey";
NSNotificationName const LCLiveQueryEventNotification = @"LCLiveQueryEventNotification";

@interface LCSubscriber () <LCRTMConnectionDelegate>

@property (nonatomic) dispatch_queue_t internalSerialQueue;
@property (nonatomic) BOOL alive;
@property (nonatomic) LCRTMConnection *connection;
@property (nonatomic) LCRTMServiceConsumer *serviceConsumer;
@property (nonatomic) LCRTMConnectionDelegator *connectionDelegator;
@property (nonatomic) NSHashTable<LCLiveQuery *> *weakLiveQueryObjectTable;
@property (nonatomic) NSMutableArray<void (^)(BOOL, NSError *)> *loginCallbackArray;

@end

@implementation LCSubscriber

+ (instancetype)sharedInstance
{
    static LCSubscriber *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LCSubscriber alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSString *deviceUUID = [LCUtils deviceUUID];
        _identifier = [NSString stringWithFormat:@"%@-%@", LCIdentifierPrefix, deviceUUID];
        _internalSerialQueue = dispatch_queue_create([NSString stringWithFormat:
                                                      @"LC.Objc.%@.%@",
                                                      NSStringFromClass(self.class),
                                                      keyPath(self, internalSerialQueue)]
                                                     .UTF8String, NULL);
        _weakLiveQueryObjectTable = [NSHashTable weakObjectsHashTable];
        _loginCallbackArray = nil;
        _alive = false;
        _serviceConsumer = [[LCRTMServiceConsumer alloc] initWithApplication:[LCApplication defaultApplication]
                                                                     service:LCRTMServiceLiveQuery
                                                                    protocol:LCIMProtocol3
                                                                      peerID:_identifier];
        _connectionDelegator = [[LCRTMConnectionDelegator alloc] initWithPeerID:_identifier
                                                                       delegate:self
                                                                          queue:_internalSerialQueue];
        NSError *error;
        _connection = [[LCRTMConnectionManager sharedManager] registerWithServiceConsumer:_serviceConsumer
                                                                                    error:&error];
        if (error) {
            LCLoggerError(LCLoggerDomainStorage, @"%@", error);
        }
    }
    return self;
}

- (void)dealloc
{
    [self.connection removeDelegatorWithServiceConsumer:self.serviceConsumer];
    [[LCRTMConnectionManager sharedManager] unregisterWithServiceConsumer:self.serviceConsumer];
}

// MARK: Queue

- (void)addOperationToInternalSerialQueue:(void (^)(LCSubscriber *subscriber))block
{
    dispatch_async(self.internalSerialQueue, ^{
        block(self);
    });
}

// MARK: LCRTMConnection Delegate

- (void)LCRTMConnectionDidConnect:(LCRTMConnection *)connection
{
    [self sendLoginCommand];
}

- (void)LCRTMConnectionInConnecting:(LCRTMConnection *)connection {}

- (void)LCRTMConnection:(LCRTMConnection *)connection didReceiveCommand:(AVIMGenericCommand *)inCommand
{
    if (inCommand.hasCmd &&
        inCommand.cmd == AVIMCommandType_Data &&
        inCommand.hasDataMessage) {
        [self handleDataCommand:inCommand.dataMessage];
    }
}

- (void)LCRTMConnection:(LCRTMConnection *)connection didDisconnectWithError:(NSError *)error
{
    self.alive = false;
    [self invokeAllLoginCallbackWithSucceeded:false
                                        error:error];
    BOOL liveQueryExist = false;
    for (LCLiveQuery *item in self.weakLiveQueryObjectTable) {
        if (item) {
            liveQueryExist = true;
            break;
        }
    }
    if (!liveQueryExist) {
        [self.weakLiveQueryObjectTable removeAllObjects];
        self.connectionDelegator.delegate = nil;
        [self.connection removeDelegatorWithServiceConsumer:self.serviceConsumer];
    }
}

- (void)handleDataCommand:(AVIMDataCommand *)command
{
    for (AVIMJsonObjectMessage *message in command.msgArray) {
        [self handleDataMessage:message];
    }
}

- (void)handleDataMessage:(AVIMJsonObjectMessage *)message
{
    NSString *JSONString = (message.hasData_p ? message.data_p : nil);
    if (!JSONString) {
        return;
    }
    NSError *error;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[JSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:0
                                                                 error:&error];
    if (error || !dictionary) {
        return;
    }
    NSDictionary *event = (NSDictionary *)[LCObjectUtils objectFromDictionary:dictionary
                                                                    recursive:YES];
    if ([event isKindOfClass:[NSDictionary class]]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:LCLiveQueryEventNotification
                                                            object:self
                                                          userInfo:@{ LCLiveQueryEventKey: event }];
    }
}

// MARK: Login

- (AVIMGenericCommand *)makeLoginCommand
{
    AVIMGenericCommand *command = [AVIMGenericCommand new];
    command.cmd = AVIMCommandType_Login;
    command.appId = [self.serviceConsumer.application identifierThrowException];
    command.installationId = self.identifier;
    command.service = LCRTMServiceLiveQuery;
    return command;
}

- (void)invokeAllLoginCallbackWithSucceeded:(BOOL)succeeded
                                      error:(NSError *)error
{
    NSArray<void (^)(BOOL, NSError *)> *callbacks = self.loginCallbackArray;
    if (!callbacks) {
        return;
    }
    self.loginCallbackArray = nil;
    for (void (^callback)(BOOL, NSError *) in callbacks) {
        callback(succeeded, error);
    }
}

- (void)loginWithCallback:(void (^)(BOOL succeeded, NSError *error))callback
{
    [self addOperationToInternalSerialQueue:^(LCSubscriber *subscriber) {
        if (subscriber.loginCallbackArray) {
            [subscriber.loginCallbackArray addObject:callback];
        } else {
            subscriber.loginCallbackArray = [NSMutableArray arrayWithObject:callback];
            subscriber.connectionDelegator.delegate = subscriber;
            [subscriber.connection connectWithServiceConsumer:subscriber.serviceConsumer
                                                    delegator:subscriber.connectionDelegator];
        }
    }];
}

- (void)sendLoginCommand
{
    if (!self.loginCallbackArray &&
        self.weakLiveQueryObjectTable.count == 0) {
        return;
    }
    if (self.alive) {
        [self invokeAllLoginCallbackWithSucceeded:true
                                            error:nil];
        return;
    }
    __weak typeof(self) ws = self;
    [self.connection sendCommand:[self makeLoginCommand]
                         service:LCRTMServiceLiveQuery
                          peerID:self.identifier
                         onQueue:self.internalSerialQueue
                        callback:^(AVIMGenericCommand * _Nullable inCommand, NSError * _Nullable error) {
        LCSubscriber *ss = ws;
        if (!ss) {
            return;
        }
        ss.alive = (!error &&
                    inCommand &&
                    inCommand.hasCmd &&
                    inCommand.cmd == AVIMCommandType_Loggedin);
        if (ss.alive) {
            [ss invokeAllLoginCallbackWithSucceeded:true
                                              error:nil];
            for (LCLiveQuery *item in ss.weakLiveQueryObjectTable) {
                [item resubscribe];
            }
        } else if (error) {
            if ([error.domain isEqualToString:kLeanCloudErrorDomain] &&
                error.code == LCIMErrorCodeCommandTimeout) {
                [ws sendLoginCommand];
            }
        }
    }];
}

// MARK: Weak Retainer

- (void)addLiveQueryObjectToWeakTable:(LCLiveQuery *)liveQueryObject
{
    [self addOperationToInternalSerialQueue:^(LCSubscriber *subscriber) {
        [subscriber.weakLiveQueryObjectTable addObject:liveQueryObject];
    }];
}

- (void)removeLiveQueryObjectFromWeakTable:(LCLiveQuery *)liveQueryObject
{
    [self addOperationToInternalSerialQueue:^(LCSubscriber *subscriber) {
        [subscriber.weakLiveQueryObjectTable removeObject:liveQueryObject];
    }];
}

@end
