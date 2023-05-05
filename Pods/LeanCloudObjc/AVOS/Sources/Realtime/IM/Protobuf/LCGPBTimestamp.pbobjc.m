// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: google/protobuf/timestamp.proto

// This CPP symbol can be defined to use imports that match up to the framework
// imports needed when using CocoaPods.
#if !defined(LCGPB_USE_PROTOBUF_FRAMEWORK_IMPORTS)
 #define LCGPB_USE_PROTOBUF_FRAMEWORK_IMPORTS 0
#endif

#if LCGPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
 #import <Protobuf/LCGPBProtocolBuffers_RuntimeSupport.h>
#else
 #import "LCGPBProtocolBuffers_RuntimeSupport.h"
#endif

#if LCGPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
 #import <Protobuf/LCGPBTimestamp.pbobjc.h>
#else
 #import "LCGPBTimestamp.pbobjc.h"
#endif
// @@protoc_insertion_point(imports)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark - LCGPBTimestampRoot

@implementation LCGPBTimestampRoot

// No extensions in the file and no imports, so no need to generate
// +extensionRegistry.

@end

#pragma mark - LCGPBTimestampRoot_FileDescriptor

static LCGPBFileDescriptor *LCGPBTimestampRoot_FileDescriptor(void) {
  // This is called by +initialize so there is no need to worry
  // about thread safety of the singleton.
  static LCGPBFileDescriptor *descriptor = NULL;
  if (!descriptor) {
    LCGPB_DEBUG_CHECK_RUNTIME_VERSIONS();
    descriptor = [[LCGPBFileDescriptor alloc] initWithPackage:@"google.protobuf"
                                                 objcPrefix:@"LCGPB"
                                                     syntax:LCGPBFileSyntaxProto3];
  }
  return descriptor;
}

#pragma mark - LCGPBTimestamp

@implementation LCGPBTimestamp

@dynamic seconds;
@dynamic nanos;

typedef struct LCGPBTimestamp__storage_ {
  uint32_t _has_storage_[1];
  int32_t nanos;
  int64_t seconds;
} LCGPBTimestamp__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "seconds",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBTimestamp_FieldNumber_Seconds,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBTimestamp__storage_, seconds),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeInt64,
      },
      {
        .name = "nanos",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBTimestamp_FieldNumber_Nanos,
        .hasIndex = 1,
        .offset = (uint32_t)offsetof(LCGPBTimestamp__storage_, nanos),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeInt32,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBTimestamp class]
                                     rootClass:[LCGPBTimestampRoot class]
                                          file:LCGPBTimestampRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBTimestamp__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end


#pragma clang diagnostic pop

// @@protoc_insertion_point(global_scope)
