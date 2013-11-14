//
//  Header.h
//  Pods
//
//  Created by Mathieu D'Amours on 5/8/13.
//
//

#pragma once

#define SliceFromString(_string_)           leveldb::Slice((char *)[_string_ UTF8String], [_string_ lengthOfBytesUsingEncoding:NSUTF8StringEncoding])
#define StringFromSlice(_slice_)            [[[NSString alloc] initWithBytes:_slice_.data() length:_slice_.size() encoding:NSUTF8StringEncoding] autorelease]

#define SliceFromData(_data_)               leveldb::Slice((char *)[_data_ bytes], [_data_ length])
#define DataFromSlice(_slice_)              [NSData dataWithBytes:_slice_.data() length:_slice_.size()]

#define DecodeFromSlice(_slice_, _key_, _d) (_d) ? _d(_key_, DataFromSlice(_slice_))  : ObjectFromSlice(_slice_)
#define EncodeToSlice(_object_, _key_, _e)  (_e) ? SliceFromData(_e(_key_, _object_)) : SliceFromObject(_object_)

#define KeyFromStringOrData(_key_)          ([_key_ isKindOfClass:[NSString class]]) ? SliceFromString(_key_) \
                                            : ([_key_ isKindOfClass:[NSData class]]) ? SliceFromData(_key_) \
                                            : NULL

#define GenericKeyFromSlice(_slice_)        (LevelDBKey) { .data = _slice_.data(), .length = static_cast<int>(_slice_.size()) }
#define GenericKeyFromNSDataOrString(_obj_) ([_obj_ isKindOfClass:[NSString class]]) ? \
                                                (LevelDBKey) { \
                                                    .data   = [_obj_ cStringUsingEncoding:NSUTF8StringEncoding], \
                                                    .length = [_obj_ lengthOfBytesUsingEncoding:NSUTF8StringEncoding] \
                                                } \
                                            : ([_obj_ isKindOfClass:[NSData class]])   ? \
                                                (LevelDBKey) { \
                                                            .data = [_obj_ bytes], .length = [_obj_ length] \
                                                } \
                                            : NULL

static leveldb::Slice SliceFromObject(id object) {
    NSMutableData *d = [[[NSMutableData alloc] init] autorelease];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:d];
    [archiver encodeObject:object forKey:@"object"];
    [archiver finishEncoding];
    [archiver release];
    return leveldb::Slice((const char *)[d bytes], (size_t)[d length]);
}

static id ObjectFromSlice(leveldb::Slice v) {
    NSData *data = DataFromSlice(v);
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    id object = [[unarchiver decodeObjectForKey:@"object"] retain];
    [unarchiver finishDecoding];
    [unarchiver release];
    return [object autorelease];
}
