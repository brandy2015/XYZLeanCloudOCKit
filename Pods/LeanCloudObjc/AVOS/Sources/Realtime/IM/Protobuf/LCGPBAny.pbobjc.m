// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: google/protobuf/any.proto

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
 #import <Protobuf/LCGPBAny.pbobjc.h>
#else
 #import "LCGPBAny.pbobjc.h"
#endif
// @@protoc_insertion_point(imports)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark - LCGPBAnyRoot

@implementation LCGPBAnyRoot

// No extensions in the file and no imports, so no need to generate
// +extensionRegistry.

@end

#pragma mark - LCGPBAnyRoot_FileDescriptor

static LCGPBFileDescriptor *LCGPBAnyRoot_FileDescriptor(void) {
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

#pragma mark - LCGPBAny

@implementation LCGPBAny

@dynamic typeURL;
@dynamic value;

typedef struct LCGPBAny__storage_ {
  uint32_t _has_storage_[1];
  NSString *typeURL;
  NSData *value;
} LCGPBAny__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "typeURL",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBAny_FieldNumber_TypeURL,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCGPBAny__storage_, typeURL),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldTextFormatNameCustom | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeString,
      },
      {
        .name = "value",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBAny_FieldNumber_Value,
        .hasIndex = 1,
        .offset = (uint32_t)offsetof(LCGPBAny__storage_, value),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldClearHasIvarOnZero),
        .dataType = LCGPBDataTypeBytes,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBAny class]
                                     rootClass:[LCGPBAnyRoot class]
                                          file:LCGPBAnyRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBAny__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
#if !LCGPBOBJC_SKIP_MESSAGE_TEXTFORMAT_EXTRAS
    static const char *extraTextFormatInfo =
        "\001\001\004\241!!\000";
    [localDescriptor setupExtraTextInfo:extraTextFormatInfo];
#endif  // !LCGPBOBJC_SKIP_MESSAGE_TEXTFORMAT_EXTRAS
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
