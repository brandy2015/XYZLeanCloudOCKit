// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
// https://developers.google.com/protocol-buffers/
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "LCGPBCodedOutputStream_PackagePrivate.h"

#import <mach/vm_param.h>

#import "LCGPBArray.h"
#import "LCGPBUnknownFieldSet_PackagePrivate.h"
#import "LCGPBUtilities_PackagePrivate.h"

// These values are the existing values so as not to break any code that might
// have already been inspecting them when they weren't documented/exposed.
NSString *const LCGPBCodedOutputStreamException_OutOfSpace = @"OutOfSpace";
NSString *const LCGPBCodedOutputStreamException_WriteFailed = @"WriteFailed";

// Structure for containing state of a LCGPBCodedInputStream. Brought out into
// a struct so that we can inline several common functions instead of dealing
// with overhead of ObjC dispatch.
typedef struct LCGPBOutputBufferState {
  uint8_t *bytes;
  size_t size;
  size_t position;
  NSOutputStream *output;
} LCGPBOutputBufferState;

@implementation LCGPBCodedOutputStream {
  LCGPBOutputBufferState state_;
  NSMutableData *buffer_;
}

static const int32_t LITTLE_ENDIAN_32_SIZE = sizeof(uint32_t);
static const int32_t LITTLE_ENDIAN_64_SIZE = sizeof(uint64_t);

// Internal helper that writes the current buffer to the output. The
// buffer position is reset to its initial value when this returns.
static void LCGPBRefreshBuffer(LCGPBOutputBufferState *state) {
  if (state->output == nil) {
    // We're writing to a single buffer.
    [NSException raise:LCGPBCodedOutputStreamException_OutOfSpace format:@""];
  }
  if (state->position != 0) {
    NSInteger written =
        [state->output write:state->bytes maxLength:state->position];
    if (written != (NSInteger)state->position) {
      [NSException raise:LCGPBCodedOutputStreamException_WriteFailed format:@""];
    }
    state->position = 0;
  }
}

static void LCGPBWriteRawByte(LCGPBOutputBufferState *state, uint8_t value) {
  if (state->position == state->size) {
    LCGPBRefreshBuffer(state);
  }
  state->bytes[state->position++] = value;
}

static void LCGPBWriteRawVarint32(LCGPBOutputBufferState *state, int32_t value) {
  while (YES) {
    if ((value & ~0x7F) == 0) {
      uint8_t val = (uint8_t)value;
      LCGPBWriteRawByte(state, val);
      return;
    } else {
      LCGPBWriteRawByte(state, (value & 0x7F) | 0x80);
      value = LCGPBLogicalRightShift32(value, 7);
    }
  }
}

static void LCGPBWriteRawVarint64(LCGPBOutputBufferState *state, int64_t value) {
  while (YES) {
    if ((value & ~0x7FL) == 0) {
      uint8_t val = (uint8_t)value;
      LCGPBWriteRawByte(state, val);
      return;
    } else {
      LCGPBWriteRawByte(state, ((int32_t)value & 0x7F) | 0x80);
      value = LCGPBLogicalRightShift64(value, 7);
    }
  }
}

static void LCGPBWriteInt32NoTag(LCGPBOutputBufferState *state, int32_t value) {
  if (value >= 0) {
    LCGPBWriteRawVarint32(state, value);
  } else {
    // Must sign-extend
    LCGPBWriteRawVarint64(state, value);
  }
}

static void LCGPBWriteUInt32(LCGPBOutputBufferState *state, int32_t fieldNumber,
                           uint32_t value) {
  LCGPBWriteTagWithFormat(state, fieldNumber, LCGPBWireFormatVarint);
  LCGPBWriteRawVarint32(state, value);
}

static void LCGPBWriteTagWithFormat(LCGPBOutputBufferState *state,
                                  uint32_t fieldNumber, LCGPBWireFormat format) {
  LCGPBWriteRawVarint32(state, LCGPBWireFormatMakeTag(fieldNumber, format));
}

static void LCGPBWriteRawLittleEndian32(LCGPBOutputBufferState *state,
                                      int32_t value) {
  LCGPBWriteRawByte(state, (value)&0xFF);
  LCGPBWriteRawByte(state, (value >> 8) & 0xFF);
  LCGPBWriteRawByte(state, (value >> 16) & 0xFF);
  LCGPBWriteRawByte(state, (value >> 24) & 0xFF);
}

static void LCGPBWriteRawLittleEndian64(LCGPBOutputBufferState *state,
                                      int64_t value) {
  LCGPBWriteRawByte(state, (int32_t)(value)&0xFF);
  LCGPBWriteRawByte(state, (int32_t)(value >> 8) & 0xFF);
  LCGPBWriteRawByte(state, (int32_t)(value >> 16) & 0xFF);
  LCGPBWriteRawByte(state, (int32_t)(value >> 24) & 0xFF);
  LCGPBWriteRawByte(state, (int32_t)(value >> 32) & 0xFF);
  LCGPBWriteRawByte(state, (int32_t)(value >> 40) & 0xFF);
  LCGPBWriteRawByte(state, (int32_t)(value >> 48) & 0xFF);
  LCGPBWriteRawByte(state, (int32_t)(value >> 56) & 0xFF);
}

- (void)dealloc {
  [self flush];
  [state_.output close];
  [state_.output release];
  [buffer_ release];

  [super dealloc];
}

- (instancetype)initWithOutputStream:(NSOutputStream *)output {
  NSMutableData *data = [NSMutableData dataWithLength:PAGE_SIZE];
  return [self initWithOutputStream:output data:data];
}

- (instancetype)initWithData:(NSMutableData *)data {
  return [self initWithOutputStream:nil data:data];
}

// This initializer isn't exposed, but it is the designated initializer.
// Setting OutputStream and NSData is to control the buffering behavior/size
// of the work, but that is more obvious via the bufferSize: version.
- (instancetype)initWithOutputStream:(NSOutputStream *)output
                                data:(NSMutableData *)data {
  if ((self = [super init])) {
    buffer_ = [data retain];
    state_.bytes = [data mutableBytes];
    state_.size = [data length];
    state_.output = [output retain];
    [state_.output open];
  }
  return self;
}

+ (instancetype)streamWithOutputStream:(NSOutputStream *)output {
  NSMutableData *data = [NSMutableData dataWithLength:PAGE_SIZE];
  return [[[self alloc] initWithOutputStream:output
                                        data:data] autorelease];
}

+ (instancetype)streamWithData:(NSMutableData *)data {
  return [[[self alloc] initWithData:data] autorelease];
}

// Direct access is use for speed, to avoid even internally declaring things
// read/write, etc. The warning is enabled in the project to ensure code calling
// protos can turn on -Wdirect-ivar-access without issues.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

- (void)writeDoubleNoTag:(double)value {
  LCGPBWriteRawLittleEndian64(&state_, LCGPBConvertDoubleToInt64(value));
}

- (void)writeDouble:(int32_t)fieldNumber value:(double)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatFixed64);
  LCGPBWriteRawLittleEndian64(&state_, LCGPBConvertDoubleToInt64(value));
}

- (void)writeFloatNoTag:(float)value {
  LCGPBWriteRawLittleEndian32(&state_, LCGPBConvertFloatToInt32(value));
}

- (void)writeFloat:(int32_t)fieldNumber value:(float)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatFixed32);
  LCGPBWriteRawLittleEndian32(&state_, LCGPBConvertFloatToInt32(value));
}

- (void)writeUInt64NoTag:(uint64_t)value {
  LCGPBWriteRawVarint64(&state_, value);
}

- (void)writeUInt64:(int32_t)fieldNumber value:(uint64_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatVarint);
  LCGPBWriteRawVarint64(&state_, value);
}

- (void)writeInt64NoTag:(int64_t)value {
  LCGPBWriteRawVarint64(&state_, value);
}

- (void)writeInt64:(int32_t)fieldNumber value:(int64_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatVarint);
  LCGPBWriteRawVarint64(&state_, value);
}

- (void)writeInt32NoTag:(int32_t)value {
  LCGPBWriteInt32NoTag(&state_, value);
}

- (void)writeInt32:(int32_t)fieldNumber value:(int32_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatVarint);
  LCGPBWriteInt32NoTag(&state_, value);
}

- (void)writeFixed64NoTag:(uint64_t)value {
  LCGPBWriteRawLittleEndian64(&state_, value);
}

- (void)writeFixed64:(int32_t)fieldNumber value:(uint64_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatFixed64);
  LCGPBWriteRawLittleEndian64(&state_, value);
}

- (void)writeFixed32NoTag:(uint32_t)value {
  LCGPBWriteRawLittleEndian32(&state_, value);
}

- (void)writeFixed32:(int32_t)fieldNumber value:(uint32_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatFixed32);
  LCGPBWriteRawLittleEndian32(&state_, value);
}

- (void)writeBoolNoTag:(BOOL)value {
  LCGPBWriteRawByte(&state_, (value ? 1 : 0));
}

- (void)writeBool:(int32_t)fieldNumber value:(BOOL)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatVarint);
  LCGPBWriteRawByte(&state_, (value ? 1 : 0));
}

- (void)writeStringNoTag:(const NSString *)value {
  size_t length = [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
  LCGPBWriteRawVarint32(&state_, (int32_t)length);
  if (length == 0) {
    return;
  }

  const char *quickString =
      CFStringGetCStringPtr((CFStringRef)value, kCFStringEncodingUTF8);

  // Fast path: Most strings are short, if the buffer already has space,
  // add to it directly.
  NSUInteger bufferBytesLeft = state_.size - state_.position;
  if (bufferBytesLeft >= length) {
    NSUInteger usedBufferLength = 0;
    BOOL result;
    if (quickString != NULL) {
      memcpy(state_.bytes + state_.position, quickString, length);
      usedBufferLength = length;
      result = YES;
    } else {
      result = [value getBytes:state_.bytes + state_.position
                     maxLength:bufferBytesLeft
                    usedLength:&usedBufferLength
                      encoding:NSUTF8StringEncoding
                       options:(NSStringEncodingConversionOptions)0
                         range:NSMakeRange(0, [value length])
                remainingRange:NULL];
    }
    if (result) {
      NSAssert2((usedBufferLength == length),
                @"Our UTF8 calc was wrong? %tu vs %zd", usedBufferLength,
                length);
      state_.position += usedBufferLength;
      return;
    }
  } else if (quickString != NULL) {
    [self writeRawPtr:quickString offset:0 length:length];
  } else {
    // Slow path: just get it as data and write it out.
    NSData *utf8Data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSAssert2(([utf8Data length] == length),
              @"Strings UTF8 length was wrong? %tu vs %zd", [utf8Data length],
              length);
    [self writeRawData:utf8Data];
  }
}

- (void)writeString:(int32_t)fieldNumber value:(NSString *)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatLengthDelimited);
  [self writeStringNoTag:value];
}

- (void)writeGroupNoTag:(int32_t)fieldNumber value:(LCGPBMessage *)value {
  [value writeToCodedOutputStream:self];
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatEndGroup);
}

- (void)writeGroup:(int32_t)fieldNumber value:(LCGPBMessage *)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatStartGroup);
  [self writeGroupNoTag:fieldNumber value:value];
}

- (void)writeUnknownGroupNoTag:(int32_t)fieldNumber
                         value:(const LCGPBUnknownFieldSet *)value {
  [value writeToCodedOutputStream:self];
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatEndGroup);
}

- (void)writeUnknownGroup:(int32_t)fieldNumber
                    value:(LCGPBUnknownFieldSet *)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatStartGroup);
  [self writeUnknownGroupNoTag:fieldNumber value:value];
}

- (void)writeMessageNoTag:(LCGPBMessage *)value {
  LCGPBWriteRawVarint32(&state_, (int32_t)[value serializedSize]);
  [value writeToCodedOutputStream:self];
}

- (void)writeMessage:(int32_t)fieldNumber value:(LCGPBMessage *)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatLengthDelimited);
  [self writeMessageNoTag:value];
}

- (void)writeBytesNoTag:(NSData *)value {
  LCGPBWriteRawVarint32(&state_, (int32_t)[value length]);
  [self writeRawData:value];
}

- (void)writeBytes:(int32_t)fieldNumber value:(NSData *)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatLengthDelimited);
  [self writeBytesNoTag:value];
}

- (void)writeUInt32NoTag:(uint32_t)value {
  LCGPBWriteRawVarint32(&state_, value);
}

- (void)writeUInt32:(int32_t)fieldNumber value:(uint32_t)value {
  LCGPBWriteUInt32(&state_, fieldNumber, value);
}

- (void)writeEnumNoTag:(int32_t)value {
  LCGPBWriteInt32NoTag(&state_, value);
}

- (void)writeEnum:(int32_t)fieldNumber value:(int32_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatVarint);
  LCGPBWriteInt32NoTag(&state_, value);
}

- (void)writeSFixed32NoTag:(int32_t)value {
  LCGPBWriteRawLittleEndian32(&state_, value);
}

- (void)writeSFixed32:(int32_t)fieldNumber value:(int32_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatFixed32);
  LCGPBWriteRawLittleEndian32(&state_, value);
}

- (void)writeSFixed64NoTag:(int64_t)value {
  LCGPBWriteRawLittleEndian64(&state_, value);
}

- (void)writeSFixed64:(int32_t)fieldNumber value:(int64_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatFixed64);
  LCGPBWriteRawLittleEndian64(&state_, value);
}

- (void)writeSInt32NoTag:(int32_t)value {
  LCGPBWriteRawVarint32(&state_, LCGPBEncodeZigZag32(value));
}

- (void)writeSInt32:(int32_t)fieldNumber value:(int32_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatVarint);
  LCGPBWriteRawVarint32(&state_, LCGPBEncodeZigZag32(value));
}

- (void)writeSInt64NoTag:(int64_t)value {
  LCGPBWriteRawVarint64(&state_, LCGPBEncodeZigZag64(value));
}

- (void)writeSInt64:(int32_t)fieldNumber value:(int64_t)value {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, LCGPBWireFormatVarint);
  LCGPBWriteRawVarint64(&state_, LCGPBEncodeZigZag64(value));
}

//%PDDM-DEFINE WRITE_PACKABLE_DEFNS(NAME, ARRAY_TYPE, TYPE, ACCESSOR_NAME)
//%- (void)write##NAME##Array:(int32_t)fieldNumber
//%       NAME$S     values:(LCGPB##ARRAY_TYPE##Array *)values
//%       NAME$S        tag:(uint32_t)tag {
//%  if (tag != 0) {
//%    if (values.count == 0) return;
//%    __block size_t dataSize = 0;
//%    [values enumerate##ACCESSOR_NAME##ValuesWithBlock:^(TYPE value, NSUInteger idx, BOOL *stop) {
//%#pragma unused(idx, stop)
//%      dataSize += LCGPBCompute##NAME##SizeNoTag(value);
//%    }];
//%    LCGPBWriteRawVarint32(&state_, tag);
//%    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
//%    [values enumerate##ACCESSOR_NAME##ValuesWithBlock:^(TYPE value, NSUInteger idx, BOOL *stop) {
//%#pragma unused(idx, stop)
//%      [self write##NAME##NoTag:value];
//%    }];
//%  } else {
//%    [values enumerate##ACCESSOR_NAME##ValuesWithBlock:^(TYPE value, NSUInteger idx, BOOL *stop) {
//%#pragma unused(idx, stop)
//%      [self write##NAME:fieldNumber value:value];
//%    }];
//%  }
//%}
//%
//%PDDM-DEFINE WRITE_UNPACKABLE_DEFNS(NAME, TYPE)
//%- (void)write##NAME##Array:(int32_t)fieldNumber values:(NSArray *)values {
//%  for (TYPE *value in values) {
//%    [self write##NAME:fieldNumber value:value];
//%  }
//%}
//%
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(Double, Double, double, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeDoubleArray:(int32_t)fieldNumber
                  values:(LCGPBDoubleArray *)values
                     tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(double value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeDoubleSizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(double value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeDoubleNoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(double value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeDouble:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(Float, Float, float, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeFloatArray:(int32_t)fieldNumber
                 values:(LCGPBFloatArray *)values
                    tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(float value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeFloatSizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(float value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeFloatNoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(float value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeFloat:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(UInt64, UInt64, uint64_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeUInt64Array:(int32_t)fieldNumber
                  values:(LCGPBUInt64Array *)values
                     tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(uint64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeUInt64SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(uint64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeUInt64NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(uint64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeUInt64:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(Int64, Int64, int64_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeInt64Array:(int32_t)fieldNumber
                 values:(LCGPBInt64Array *)values
                    tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(int64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeInt64SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(int64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeInt64NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(int64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeInt64:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(Int32, Int32, int32_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeInt32Array:(int32_t)fieldNumber
                 values:(LCGPBInt32Array *)values
                    tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeInt32SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeInt32NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeInt32:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(UInt32, UInt32, uint32_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeUInt32Array:(int32_t)fieldNumber
                  values:(LCGPBUInt32Array *)values
                     tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(uint32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeUInt32SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(uint32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeUInt32NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(uint32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeUInt32:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(Fixed64, UInt64, uint64_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeFixed64Array:(int32_t)fieldNumber
                   values:(LCGPBUInt64Array *)values
                      tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(uint64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeFixed64SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(uint64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeFixed64NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(uint64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeFixed64:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(Fixed32, UInt32, uint32_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeFixed32Array:(int32_t)fieldNumber
                   values:(LCGPBUInt32Array *)values
                      tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(uint32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeFixed32SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(uint32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeFixed32NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(uint32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeFixed32:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(SInt32, Int32, int32_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeSInt32Array:(int32_t)fieldNumber
                  values:(LCGPBInt32Array *)values
                     tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeSInt32SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeSInt32NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeSInt32:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(SInt64, Int64, int64_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeSInt64Array:(int32_t)fieldNumber
                  values:(LCGPBInt64Array *)values
                     tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(int64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeSInt64SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(int64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeSInt64NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(int64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeSInt64:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(SFixed64, Int64, int64_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeSFixed64Array:(int32_t)fieldNumber
                    values:(LCGPBInt64Array *)values
                       tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(int64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeSFixed64SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(int64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeSFixed64NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(int64_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeSFixed64:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(SFixed32, Int32, int32_t, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeSFixed32Array:(int32_t)fieldNumber
                    values:(LCGPBInt32Array *)values
                       tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeSFixed32SizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeSFixed32NoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeSFixed32:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(Bool, Bool, BOOL, )
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeBoolArray:(int32_t)fieldNumber
                values:(LCGPBBoolArray *)values
                   tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateValuesWithBlock:^(BOOL value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeBoolSizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateValuesWithBlock:^(BOOL value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeBoolNoTag:value];
    }];
  } else {
    [values enumerateValuesWithBlock:^(BOOL value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeBool:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_PACKABLE_DEFNS(Enum, Enum, int32_t, Raw)
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeEnumArray:(int32_t)fieldNumber
                values:(LCGPBEnumArray *)values
                   tag:(uint32_t)tag {
  if (tag != 0) {
    if (values.count == 0) return;
    __block size_t dataSize = 0;
    [values enumerateRawValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      dataSize += LCGPBComputeEnumSizeNoTag(value);
    }];
    LCGPBWriteRawVarint32(&state_, tag);
    LCGPBWriteRawVarint32(&state_, (int32_t)dataSize);
    [values enumerateRawValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeEnumNoTag:value];
    }];
  } else {
    [values enumerateRawValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      [self writeEnum:fieldNumber value:value];
    }];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_UNPACKABLE_DEFNS(String, NSString)
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeStringArray:(int32_t)fieldNumber values:(NSArray *)values {
  for (NSString *value in values) {
    [self writeString:fieldNumber value:value];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_UNPACKABLE_DEFNS(Message, LCGPBMessage)
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeMessageArray:(int32_t)fieldNumber values:(NSArray *)values {
  for (LCGPBMessage *value in values) {
    [self writeMessage:fieldNumber value:value];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_UNPACKABLE_DEFNS(Bytes, NSData)
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeBytesArray:(int32_t)fieldNumber values:(NSArray *)values {
  for (NSData *value in values) {
    [self writeBytes:fieldNumber value:value];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_UNPACKABLE_DEFNS(Group, LCGPBMessage)
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeGroupArray:(int32_t)fieldNumber values:(NSArray *)values {
  for (LCGPBMessage *value in values) {
    [self writeGroup:fieldNumber value:value];
  }
}

// clang-format on
//%PDDM-EXPAND WRITE_UNPACKABLE_DEFNS(UnknownGroup, LCGPBUnknownFieldSet)
// This block of code is generated, do not edit it directly.
// clang-format off

- (void)writeUnknownGroupArray:(int32_t)fieldNumber values:(NSArray *)values {
  for (LCGPBUnknownFieldSet *value in values) {
    [self writeUnknownGroup:fieldNumber value:value];
  }
}

// clang-format on
//%PDDM-EXPAND-END (19 expansions)

- (void)writeMessageSetExtension:(int32_t)fieldNumber
                           value:(LCGPBMessage *)value {
  LCGPBWriteTagWithFormat(&state_, LCGPBWireFormatMessageSetItem,
                        LCGPBWireFormatStartGroup);
  LCGPBWriteUInt32(&state_, LCGPBWireFormatMessageSetTypeId, fieldNumber);
  [self writeMessage:LCGPBWireFormatMessageSetMessage value:value];
  LCGPBWriteTagWithFormat(&state_, LCGPBWireFormatMessageSetItem,
                        LCGPBWireFormatEndGroup);
}

- (void)writeRawMessageSetExtension:(int32_t)fieldNumber value:(NSData *)value {
  LCGPBWriteTagWithFormat(&state_, LCGPBWireFormatMessageSetItem,
                        LCGPBWireFormatStartGroup);
  LCGPBWriteUInt32(&state_, LCGPBWireFormatMessageSetTypeId, fieldNumber);
  [self writeBytes:LCGPBWireFormatMessageSetMessage value:value];
  LCGPBWriteTagWithFormat(&state_, LCGPBWireFormatMessageSetItem,
                        LCGPBWireFormatEndGroup);
}

- (void)flush {
  if (state_.output != nil) {
    LCGPBRefreshBuffer(&state_);
  }
}

- (void)writeRawByte:(uint8_t)value {
  LCGPBWriteRawByte(&state_, value);
}

- (void)writeRawData:(const NSData *)data {
  [self writeRawPtr:[data bytes] offset:0 length:[data length]];
}

- (void)writeRawPtr:(const void *)value
             offset:(size_t)offset
             length:(size_t)length {
  if (value == nil || length == 0) {
    return;
  }

  NSUInteger bufferLength = state_.size;
  NSUInteger bufferBytesLeft = bufferLength - state_.position;
  if (bufferBytesLeft >= length) {
    // We have room in the current buffer.
    memcpy(state_.bytes + state_.position, ((uint8_t *)value) + offset, length);
    state_.position += length;
  } else {
    // Write extends past current buffer.  Fill the rest of this buffer and
    // flush.
    size_t bytesWritten = bufferBytesLeft;
    memcpy(state_.bytes + state_.position, ((uint8_t *)value) + offset,
           bytesWritten);
    offset += bytesWritten;
    length -= bytesWritten;
    state_.position = bufferLength;
    LCGPBRefreshBuffer(&state_);
    bufferLength = state_.size;

    // Now deal with the rest.
    // Since we have an output stream, this is our buffer
    // and buffer offset == 0
    if (length <= bufferLength) {
      // Fits in new buffer.
      memcpy(state_.bytes, ((uint8_t *)value) + offset, length);
      state_.position = length;
    } else {
      // Write is very big.  Let's do it all at once.
      NSInteger written = [state_.output write:((uint8_t *)value) + offset maxLength:length];
      if (written != (NSInteger)length) {
        [NSException raise:LCGPBCodedOutputStreamException_WriteFailed format:@""];
      }
    }
  }
}

- (void)writeTag:(uint32_t)fieldNumber format:(LCGPBWireFormat)format {
  LCGPBWriteTagWithFormat(&state_, fieldNumber, format);
}

- (void)writeRawVarint32:(int32_t)value {
  LCGPBWriteRawVarint32(&state_, value);
}

- (void)writeRawVarintSizeTAs32:(size_t)value {
  // Note the truncation.
  LCGPBWriteRawVarint32(&state_, (int32_t)value);
}

- (void)writeRawVarint64:(int64_t)value {
  LCGPBWriteRawVarint64(&state_, value);
}

- (void)writeRawLittleEndian32:(int32_t)value {
  LCGPBWriteRawLittleEndian32(&state_, value);
}

- (void)writeRawLittleEndian64:(int64_t)value {
  LCGPBWriteRawLittleEndian64(&state_, value);
}

#pragma clang diagnostic pop

@end

size_t LCGPBComputeDoubleSizeNoTag(Float64 value) {
#pragma unused(value)
  return LITTLE_ENDIAN_64_SIZE;
}

size_t LCGPBComputeFloatSizeNoTag(Float32 value) {
#pragma unused(value)
  return LITTLE_ENDIAN_32_SIZE;
}

size_t LCGPBComputeUInt64SizeNoTag(uint64_t value) {
  return LCGPBComputeRawVarint64Size(value);
}

size_t LCGPBComputeInt64SizeNoTag(int64_t value) {
  return LCGPBComputeRawVarint64Size(value);
}

size_t LCGPBComputeInt32SizeNoTag(int32_t value) {
  if (value >= 0) {
    return LCGPBComputeRawVarint32Size(value);
  } else {
    // Must sign-extend.
    return 10;
  }
}

size_t LCGPBComputeSizeTSizeAsInt32NoTag(size_t value) {
  return LCGPBComputeInt32SizeNoTag((int32_t)value);
}

size_t LCGPBComputeFixed64SizeNoTag(uint64_t value) {
#pragma unused(value)
  return LITTLE_ENDIAN_64_SIZE;
}

size_t LCGPBComputeFixed32SizeNoTag(uint32_t value) {
#pragma unused(value)
  return LITTLE_ENDIAN_32_SIZE;
}

size_t LCGPBComputeBoolSizeNoTag(BOOL value) {
#pragma unused(value)
  return 1;
}

size_t LCGPBComputeStringSizeNoTag(NSString *value) {
  NSUInteger length = [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
  return LCGPBComputeRawVarint32SizeForInteger(length) + length;
}

size_t LCGPBComputeGroupSizeNoTag(LCGPBMessage *value) {
  return [value serializedSize];
}

size_t LCGPBComputeUnknownGroupSizeNoTag(LCGPBUnknownFieldSet *value) {
  return value.serializedSize;
}

size_t LCGPBComputeMessageSizeNoTag(LCGPBMessage *value) {
  size_t size = [value serializedSize];
  return LCGPBComputeRawVarint32SizeForInteger(size) + size;
}

size_t LCGPBComputeBytesSizeNoTag(NSData *value) {
  NSUInteger valueLength = [value length];
  return LCGPBComputeRawVarint32SizeForInteger(valueLength) + valueLength;
}

size_t LCGPBComputeUInt32SizeNoTag(int32_t value) {
  return LCGPBComputeRawVarint32Size(value);
}

size_t LCGPBComputeEnumSizeNoTag(int32_t value) {
  return LCGPBComputeInt32SizeNoTag(value);
}

size_t LCGPBComputeSFixed32SizeNoTag(int32_t value) {
#pragma unused(value)
  return LITTLE_ENDIAN_32_SIZE;
}

size_t LCGPBComputeSFixed64SizeNoTag(int64_t value) {
#pragma unused(value)
  return LITTLE_ENDIAN_64_SIZE;
}

size_t LCGPBComputeSInt32SizeNoTag(int32_t value) {
  return LCGPBComputeRawVarint32Size(LCGPBEncodeZigZag32(value));
}

size_t LCGPBComputeSInt64SizeNoTag(int64_t value) {
  return LCGPBComputeRawVarint64Size(LCGPBEncodeZigZag64(value));
}

size_t LCGPBComputeDoubleSize(int32_t fieldNumber, double value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeDoubleSizeNoTag(value);
}

size_t LCGPBComputeFloatSize(int32_t fieldNumber, float value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeFloatSizeNoTag(value);
}

size_t LCGPBComputeUInt64Size(int32_t fieldNumber, uint64_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeUInt64SizeNoTag(value);
}

size_t LCGPBComputeInt64Size(int32_t fieldNumber, int64_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeInt64SizeNoTag(value);
}

size_t LCGPBComputeInt32Size(int32_t fieldNumber, int32_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeInt32SizeNoTag(value);
}

size_t LCGPBComputeFixed64Size(int32_t fieldNumber, uint64_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeFixed64SizeNoTag(value);
}

size_t LCGPBComputeFixed32Size(int32_t fieldNumber, uint32_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeFixed32SizeNoTag(value);
}

size_t LCGPBComputeBoolSize(int32_t fieldNumber, BOOL value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeBoolSizeNoTag(value);
}

size_t LCGPBComputeStringSize(int32_t fieldNumber, NSString *value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeStringSizeNoTag(value);
}

size_t LCGPBComputeGroupSize(int32_t fieldNumber, LCGPBMessage *value) {
  return LCGPBComputeTagSize(fieldNumber) * 2 + LCGPBComputeGroupSizeNoTag(value);
}

size_t LCGPBComputeUnknownGroupSize(int32_t fieldNumber,
                                  LCGPBUnknownFieldSet *value) {
  return LCGPBComputeTagSize(fieldNumber) * 2 +
         LCGPBComputeUnknownGroupSizeNoTag(value);
}

size_t LCGPBComputeMessageSize(int32_t fieldNumber, LCGPBMessage *value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeMessageSizeNoTag(value);
}

size_t LCGPBComputeBytesSize(int32_t fieldNumber, NSData *value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeBytesSizeNoTag(value);
}

size_t LCGPBComputeUInt32Size(int32_t fieldNumber, uint32_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeUInt32SizeNoTag(value);
}

size_t LCGPBComputeEnumSize(int32_t fieldNumber, int32_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeEnumSizeNoTag(value);
}

size_t LCGPBComputeSFixed32Size(int32_t fieldNumber, int32_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeSFixed32SizeNoTag(value);
}

size_t LCGPBComputeSFixed64Size(int32_t fieldNumber, int64_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeSFixed64SizeNoTag(value);
}

size_t LCGPBComputeSInt32Size(int32_t fieldNumber, int32_t value) {
  return LCGPBComputeTagSize(fieldNumber) + LCGPBComputeSInt32SizeNoTag(value);
}

size_t LCGPBComputeSInt64Size(int32_t fieldNumber, int64_t value) {
  return LCGPBComputeTagSize(fieldNumber) +
         LCGPBComputeRawVarint64Size(LCGPBEncodeZigZag64(value));
}

size_t LCGPBComputeMessageSetExtensionSize(int32_t fieldNumber,
                                         LCGPBMessage *value) {
  return LCGPBComputeTagSize(LCGPBWireFormatMessageSetItem) * 2 +
         LCGPBComputeUInt32Size(LCGPBWireFormatMessageSetTypeId, fieldNumber) +
         LCGPBComputeMessageSize(LCGPBWireFormatMessageSetMessage, value);
}

size_t LCGPBComputeRawMessageSetExtensionSize(int32_t fieldNumber,
                                            NSData *value) {
  return LCGPBComputeTagSize(LCGPBWireFormatMessageSetItem) * 2 +
         LCGPBComputeUInt32Size(LCGPBWireFormatMessageSetTypeId, fieldNumber) +
         LCGPBComputeBytesSize(LCGPBWireFormatMessageSetMessage, value);
}

size_t LCGPBComputeTagSize(int32_t fieldNumber) {
  return LCGPBComputeRawVarint32Size(
      LCGPBWireFormatMakeTag(fieldNumber, LCGPBWireFormatVarint));
}

size_t LCGPBComputeWireFormatTagSize(int field_number, LCGPBDataType dataType) {
  size_t result = LCGPBComputeTagSize(field_number);
  if (dataType == LCGPBDataTypeGroup) {
    // Groups have both a start and an end tag.
    return result * 2;
  } else {
    return result;
  }
}

size_t LCGPBComputeRawVarint32Size(int32_t value) {
  // value is treated as unsigned, so it won't be sign-extended if negative.
  if ((value & (0xffffffff << 7)) == 0) return 1;
  if ((value & (0xffffffff << 14)) == 0) return 2;
  if ((value & (0xffffffff << 21)) == 0) return 3;
  if ((value & (0xffffffff << 28)) == 0) return 4;
  return 5;
}

size_t LCGPBComputeRawVarint32SizeForInteger(NSInteger value) {
  // Note the truncation.
  return LCGPBComputeRawVarint32Size((int32_t)value);
}

size_t LCGPBComputeRawVarint64Size(int64_t value) {
  if ((value & (0xffffffffffffffffL << 7)) == 0) return 1;
  if ((value & (0xffffffffffffffffL << 14)) == 0) return 2;
  if ((value & (0xffffffffffffffffL << 21)) == 0) return 3;
  if ((value & (0xffffffffffffffffL << 28)) == 0) return 4;
  if ((value & (0xffffffffffffffffL << 35)) == 0) return 5;
  if ((value & (0xffffffffffffffffL << 42)) == 0) return 6;
  if ((value & (0xffffffffffffffffL << 49)) == 0) return 7;
  if ((value & (0xffffffffffffffffL << 56)) == 0) return 8;
  if ((value & (0xffffffffffffffffL << 63)) == 0) return 9;
  return 10;
}
