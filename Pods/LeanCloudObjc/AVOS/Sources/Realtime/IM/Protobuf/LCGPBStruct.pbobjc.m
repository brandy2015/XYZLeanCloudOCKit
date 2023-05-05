// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: google/protobuf/struct.proto

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

#import <stdatomic.h>

#if LCGPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
 #import <Protobuf/LCGPBStruct.pbobjc.h>
#else
 #import "LCGPBStruct.pbobjc.h"
#endif
// @@protoc_insertion_point(imports)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdirect-ivar-access"
#pragma clang diagnostic ignored "-Wdollar-in-identifier-extension"

#pragma mark - Objective C Class declarations
// Forward declarations of Objective C classes that we can use as
// static values in struct initializers.
// We don't use [Foo class] because it is not a static value.
LCGPBObjCClassDeclaration(LCGPBListValue);
LCGPBObjCClassDeclaration(LCGPBStruct);
LCGPBObjCClassDeclaration(LCGPBValue);

#pragma mark - LCGPBStructRoot

@implementation LCGPBStructRoot

// No extensions in the file and no imports, so no need to generate
// +extensionRegistry.

@end

#pragma mark - LCGPBStructRoot_FileDescriptor

static LCGPBFileDescriptor *LCGPBStructRoot_FileDescriptor(void) {
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

#pragma mark - Enum LCGPBNullValue

LCGPBEnumDescriptor *LCGPBNullValue_EnumDescriptor(void) {
  static _Atomic(LCGPBEnumDescriptor*) descriptor = nil;
  if (!descriptor) {
    static const char *valueNames =
        "NullValue\000";
    static const int32_t values[] = {
        LCGPBNullValue_NullValue,
    };
    LCGPBEnumDescriptor *worker =
        [LCGPBEnumDescriptor allocDescriptorForName:LCGPBNSStringifySymbol(LCGPBNullValue)
                                       valueNames:valueNames
                                           values:values
                                            count:(uint32_t)(sizeof(values) / sizeof(int32_t))
                                     enumVerifier:LCGPBNullValue_IsValidValue];
    LCGPBEnumDescriptor *expected = nil;
    if (!atomic_compare_exchange_strong(&descriptor, &expected, worker)) {
      [worker release];
    }
  }
  return descriptor;
}

BOOL LCGPBNullValue_IsValidValue(int32_t value__) {
  switch (value__) {
    case LCGPBNullValue_NullValue:
      return YES;
    default:
      return NO;
  }
}

#pragma mark - LCGPBStruct

@implementation LCGPBStruct

@dynamic fields, fields_Count;

typedef struct LCGPBStruct__storage_ {
  uint32_t _has_storage_[1];
  NSMutableDictionary *fields;
} LCGPBStruct__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "fields",
        .dataTypeSpecific.clazz = LCGPBObjCClass(LCGPBValue),
        .number = LCGPBStruct_FieldNumber_Fields,
        .hasIndex = LCGPBNoHasBit,
        .offset = (uint32_t)offsetof(LCGPBStruct__storage_, fields),
        .flags = LCGPBFieldMapKeyString,
        .dataType = LCGPBDataTypeMessage,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBStruct class]
                                     rootClass:[LCGPBStructRoot class]
                                          file:LCGPBStructRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBStruct__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - LCGPBValue

@implementation LCGPBValue

@dynamic kindOneOfCase;
@dynamic nullValue;
@dynamic numberValue;
@dynamic stringValue;
@dynamic boolValue;
@dynamic structValue;
@dynamic listValue;

typedef struct LCGPBValue__storage_ {
  uint32_t _has_storage_[2];
  LCGPBNullValue nullValue;
  NSString *stringValue;
  LCGPBStruct *structValue;
  LCGPBListValue *listValue;
  double numberValue;
} LCGPBValue__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "nullValue",
        .dataTypeSpecific.enumDescFunc = LCGPBNullValue_EnumDescriptor,
        .number = LCGPBValue_FieldNumber_NullValue,
        .hasIndex = -1,
        .offset = (uint32_t)offsetof(LCGPBValue__storage_, nullValue),
        .flags = (LCGPBFieldFlags)(LCGPBFieldOptional | LCGPBFieldHasEnumDescriptor),
        .dataType = LCGPBDataTypeEnum,
      },
      {
        .name = "numberValue",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBValue_FieldNumber_NumberValue,
        .hasIndex = -1,
        .offset = (uint32_t)offsetof(LCGPBValue__storage_, numberValue),
        .flags = LCGPBFieldOptional,
        .dataType = LCGPBDataTypeDouble,
      },
      {
        .name = "stringValue",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBValue_FieldNumber_StringValue,
        .hasIndex = -1,
        .offset = (uint32_t)offsetof(LCGPBValue__storage_, stringValue),
        .flags = LCGPBFieldOptional,
        .dataType = LCGPBDataTypeString,
      },
      {
        .name = "boolValue",
        .dataTypeSpecific.clazz = Nil,
        .number = LCGPBValue_FieldNumber_BoolValue,
        .hasIndex = -1,
        .offset = 0,  // Stored in _has_storage_ to save space.
        .flags = LCGPBFieldOptional,
        .dataType = LCGPBDataTypeBool,
      },
      {
        .name = "structValue",
        .dataTypeSpecific.clazz = LCGPBObjCClass(LCGPBStruct),
        .number = LCGPBValue_FieldNumber_StructValue,
        .hasIndex = -1,
        .offset = (uint32_t)offsetof(LCGPBValue__storage_, structValue),
        .flags = LCGPBFieldOptional,
        .dataType = LCGPBDataTypeMessage,
      },
      {
        .name = "listValue",
        .dataTypeSpecific.clazz = LCGPBObjCClass(LCGPBListValue),
        .number = LCGPBValue_FieldNumber_ListValue,
        .hasIndex = -1,
        .offset = (uint32_t)offsetof(LCGPBValue__storage_, listValue),
        .flags = LCGPBFieldOptional,
        .dataType = LCGPBDataTypeMessage,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBValue class]
                                     rootClass:[LCGPBStructRoot class]
                                          file:LCGPBStructRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBValue__storage_)
                                         flags:(LCGPBDescriptorInitializationFlags)(LCGPBDescriptorInitializationFlag_UsesClassRefs | LCGPBDescriptorInitializationFlag_Proto3OptionalKnown)];
    static const char *oneofs[] = {
      "kind",
    };
    [localDescriptor setupOneofs:oneofs
                           count:(uint32_t)(sizeof(oneofs) / sizeof(char*))
                   firstHasIndex:-1];
    #if defined(DEBUG) && DEBUG
      NSAssert(descriptor == nil, @"Startup recursed!");
    #endif  // DEBUG
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

int32_t LCGPBValue_NullValue_RawValue(LCGPBValue *message) {
  LCGPBDescriptor *descriptor = [LCGPBValue descriptor];
  LCGPBFieldDescriptor *field = [descriptor fieldWithNumber:LCGPBValue_FieldNumber_NullValue];
  return LCGPBGetMessageRawEnumField(message, field);
}

void SetLCGPBValue_NullValue_RawValue(LCGPBValue *message, int32_t value) {
  LCGPBDescriptor *descriptor = [LCGPBValue descriptor];
  LCGPBFieldDescriptor *field = [descriptor fieldWithNumber:LCGPBValue_FieldNumber_NullValue];
  LCGPBSetMessageRawEnumField(message, field, value);
}

void LCGPBValue_ClearKindOneOfCase(LCGPBValue *message) {
  LCGPBDescriptor *descriptor = [LCGPBValue descriptor];
  LCGPBOneofDescriptor *oneof = [descriptor.oneofs objectAtIndex:0];
  LCGPBClearOneof(message, oneof);
}
#pragma mark - LCGPBListValue

@implementation LCGPBListValue

@dynamic valuesArray, valuesArray_Count;

typedef struct LCGPBListValue__storage_ {
  uint32_t _has_storage_[1];
  NSMutableArray *valuesArray;
} LCGPBListValue__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCGPBDescriptor *)descriptor {
  static LCGPBDescriptor *descriptor = nil;
  if (!descriptor) {
    static LCGPBMessageFieldDescription fields[] = {
      {
        .name = "valuesArray",
        .dataTypeSpecific.clazz = LCGPBObjCClass(LCGPBValue),
        .number = LCGPBListValue_FieldNumber_ValuesArray,
        .hasIndex = LCGPBNoHasBit,
        .offset = (uint32_t)offsetof(LCGPBListValue__storage_, valuesArray),
        .flags = LCGPBFieldRepeated,
        .dataType = LCGPBDataTypeMessage,
      },
    };
    LCGPBDescriptor *localDescriptor =
        [LCGPBDescriptor allocDescriptorForClass:[LCGPBListValue class]
                                     rootClass:[LCGPBStructRoot class]
                                          file:LCGPBStructRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(LCGPBMessageFieldDescription))
                                   storageSize:sizeof(LCGPBListValue__storage_)
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
