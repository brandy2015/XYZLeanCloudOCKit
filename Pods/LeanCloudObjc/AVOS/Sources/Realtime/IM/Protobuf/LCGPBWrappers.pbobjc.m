// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: google/protobuf/wrappers.proto

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
 #import <Protobuf/LCGPBWrappers.pbobjc.h>
#else
 #import "LCGPBWrappers.pbobjc.h"
#endif
// @@protoc_insertion_point(imports)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark - LCGPBWrappersRoot

@implementation LCGPBWrappersRoot

// No extensions in the file and no imports, so no need to generate
// +extensionRegistry.

@end

#pragma mark - LCGPBWrappersRoot_FileDescriptor

static LCGPBFileDescriptor *LCGPBWrappersRoot_FileDescriptor(void) {
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

#pragma mark - LCGPBDoubleValue

@implementation LCGPBDoubleValue

@dynamic value;

typedef struct LCGPBDoubleValue__storage_ {
  uint32_t _has_storage_[1];
  double value;
} LCGPBDoubleValue__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBDoubleValue_FieldNumber_Value,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBDoubleValue__storage_, value),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeDouble,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBDoubleValue class]
                                     rootClass:[LCGPBWrappersRoot class]
                                          file:LCGPBWrappersRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBDoubleValue__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - LCGPBFloatValue

@implementation LCGPBFloatValue

@dynamic value;

typedef struct LCGPBFloatValue__storage_ {
  uint32_t _has_storage_[1];
  float value;
} LCGPBFloatValue__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBFloatValue_FieldNumber_Value,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBFloatValue__storage_, value),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeFloat,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBFloatValue class]
                                     rootClass:[LCGPBWrappersRoot class]
                                          file:LCGPBWrappersRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBFloatValue__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - LCGPBInt64Value

@implementation LCGPBInt64Value

@dynamic value;

typedef struct LCGPBInt64Value__storage_ {
  uint32_t _has_storage_[1];
  int64_t value;
} LCGPBInt64Value__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBInt64Value_FieldNumber_Value,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBInt64Value__storage_, value),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeInt64,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBInt64Value class]
                                     rootClass:[LCGPBWrappersRoot class]
                                          file:LCGPBWrappersRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBInt64Value__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - LCGPBUInt64Value

@implementation LCGPBUInt64Value

@dynamic value;

typedef struct LCGPBUInt64Value__storage_ {
  uint32_t _has_storage_[1];
  uint64_t value;
} LCGPBUInt64Value__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBUInt64Value_FieldNumber_Value,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBUInt64Value__storage_, value),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeUInt64,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBUInt64Value class]
                                     rootClass:[LCGPBWrappersRoot class]
                                          file:LCGPBWrappersRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBUInt64Value__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - LCGPBInt32Value

@implementation LCGPBInt32Value

@dynamic value;

typedef struct LCGPBInt32Value__storage_ {
  uint32_t _has_storage_[1];
  int32_t value;
} LCGPBInt32Value__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBInt32Value_FieldNumber_Value,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBInt32Value__storage_, value),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeInt32,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBInt32Value class]
                                     rootClass:[LCGPBWrappersRoot class]
                                          file:LCGPBWrappersRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBInt32Value__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - LCGPBUInt32Value

@implementation LCGPBUInt32Value

@dynamic value;

typedef struct LCGPBUInt32Value__storage_ {
  uint32_t _has_storage_[1];
  uint32_t value;
} LCGPBUInt32Value__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBUInt32Value_FieldNumber_Value,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBUInt32Value__storage_, value),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeUInt32,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBUInt32Value class]
                                     rootClass:[LCGPBWrappersRoot class]
                                          file:LCGPBWrappersRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBUInt32Value__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - LCGPBBoolValue

@implementation LCGPBBoolValue

@dynamic value;

typedef struct LCGPBBoolValue__storage_ {
  uint32_t _has_storage_[1];
} LCGPBBoolValue__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBBoolValue_FieldNumber_Value,
        .hasIndex = 0,
        .offset = 1,  // Stored in _has_storage_ to save space.
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeBool,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBBoolValue class]
                                     rootClass:[LCGPBWrappersRoot class]
                                          file:LCGPBWrappersRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBBoolValue__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - LCGPBStringValue

@implementation LCGPBStringValue

@dynamic value;

typedef struct LCGPBStringValue__storage_ {
  uint32_t _has_storage_[1];
  NSString *value;
} LCGPBStringValue__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBStringValue_FieldNumber_Value,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBStringValue__storage_, value),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeString,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBStringValue class]
                                     rootClass:[LCGPBWrappersRoot class]
                                          file:LCGPBWrappersRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBStringValue__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - LCGPBBytesValue

@implementation LCGPBBytesValue

@dynamic value;

typedef struct LCGPBBytesValue__storage_ {
  uint32_t _has_storage_[1];
  NSData *value;
} LCGPBBytesValue__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBBytesValue_FieldNumber_Value,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBBytesValue__storage_, value),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeBytes,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBBytesValue class]
                                     rootClass:[LCGPBWrappersRoot class]
                                          file:LCGPBWrappersRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBBytesValue__storage_)
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
