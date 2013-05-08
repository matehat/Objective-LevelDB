//
//  LevelDB.m
//
//  Copyright 2011 Pave Labs. All rights reserved. 
//  See LICENCE for details.
//

#import "LevelDB.h"

#import <leveldb/db.h>
#import <leveldb/options.h>
#import <leveldb/cache.h>

#define SliceFromString(_string_)           (Slice((char *)[_string_ UTF8String], [_string_ lengthOfBytesUsingEncoding:NSUTF8StringEncoding]))
#define StringFromSlice(_slice_)            ([[[NSString alloc] initWithBytes:_slice_.data() length:_slice_.size() encoding:NSUTF8StringEncoding] autorelease])

#define SliceFromData(_data_)               (Slice((char *)[_data_ bytes], [_data_ length]))
#define DataFromSlice(_slice_)              [NSData dataWithBytes:_slice_.data() length:_slice_.size()]

#define DecodeFromSlice(_slice_, _key_)     (_decoder) ? _decoder(_key_, DataFromSlice(_slice_)) : ObjectFromSlice(_slice_)
#define EncodeToSlice(_object_, _key_)      (_encoder) ? SliceFromData(_encoder(_key_, _object_)) : SliceFromObject(_object_)

#define KeyFromStringOrData(_key_)          ([_key_ isKindOfClass:[NSString class]]) ? SliceFromString(_key_) : \
                                            ([_key_ isKindOfClass:[NSData class]])   ? SliceFromData(_key_)   : NULL

#define GenericKeyFromSlice(_slice_)        (LevelDBKey) { .data = _slice_.data(), .length = _slice_.size() }
#define GenericKeyFromNSDataOrString(_obj_) ([_obj_ isKindOfClass:[NSString class]]) ? { .data   = [_obj_ cStringUsingEncoding:NSUTF8StringEncoding], \
                                                                                         .length = [_obj_ lengthOfBytesUsingEncoding:NSUTF8StringEncoding]} : \
                                            ([_obj_ isKindOfClass:[NSData class]])   ? { .data = [_obj_ bytes], .length = [_obj_ length] } : NULL

using namespace leveldb;

NSString * NSStringFromLevelDBKey(LevelDBKey * key) {
    return [[NSString alloc] initWithBytes:key->data length:key->length encoding:NSUTF8StringEncoding];
}
NSData * NSDataFromLevelDBKey(LevelDBKey * key) {
    return [NSData dataWithBytes:key->data length:key->length];
}

static Slice SliceFromObject(id object) {
    NSMutableData *d = [[[NSMutableData alloc] init] autorelease];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:d];
    [archiver encodeObject:object forKey:@"object"];
    [archiver finishEncoding];
    [archiver release];
    return Slice((const char *)[d bytes], (size_t)[d length]);
}

static id ObjectFromSlice(Slice v) {
    NSData *data = DataFromSlice(v);
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    id object = [[unarchiver decodeObjectForKey:@"object"] retain];
    [unarchiver finishDecoding];
    [unarchiver release];
    return object;
}

@implementation LevelDB 

@synthesize path=_path;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (id) initWithPath:(NSString *)path {
    return [self initWithPath:path andCacheSize:0];
}
- (id) initWithPath:(NSString *)path andCacheSize:(int)cacheSize {
    self = [super init];
    if (self) {
        _path = path;
        Options options;
        options.create_if_missing = true;
        
        if (cacheSize > 0)
            options.block_cache = NewLRUCache(cacheSize);
        
        Status status = DB::Open(options, [_path UTF8String], &db);
        
        readOptions.fill_cache = false;
        writeOptions.sync = false;
        
        if(!status.ok()) {
            NSLog(@"Problem creating LevelDB database: %s", status.ToString().c_str());
        }
    }
    
    return self;
}

+ (NSString *)libraryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

+ (LevelDB *)databaseInLibraryWithName:(NSString *)name {
    return [LevelDB databaseInLibraryWithName:name andCacheSize:0];
}

+ (LevelDB *)databaseInLibraryWithName:(NSString *)name andCacheSize:(int)cacheSize {
    NSString *path = [[LevelDB libraryPath] stringByAppendingPathComponent:name];
    LevelDB *ldb = [[[LevelDB alloc] initWithPath:path] autorelease];
    return ldb;
}

- (void) setSafe:(BOOL)safe {
    writeOptions.sync = safe;
}
- (BOOL) safe {
    return writeOptions.sync;
}

- (void) setObject:(id)value forKey:(id)key {
    Slice k = KeyFromStringOrData(key);
    LevelDBKey lkey = GenericKeyFromSlice(k);
    Slice v = EncodeToSlice(value, &lkey);
    
    Status status = db->Put(writeOptions, k, v);
    
    if(!status.ok()) {
        NSLog(@"Problem storing key/value pair in database: %s", status.ToString().c_str());
    }
}
- (void) setValue:(id)value forKey:(NSString *)key {
    [self setObject:value forKey:key];
}
- (void) addEntriesFromDictionary:(NSDictionary *)dictionary {
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self setObject:obj forKey:key];
    }];
}

- (id) objectForKey:(id)key {
    std::string v_string;
    Slice k = KeyFromStringOrData(key);
    Status status = db->Get(readOptions, k, &v_string);
    
    if(!status.ok()) {
        if(!status.IsNotFound())
            NSLog(@"Problem retrieving value for key '%@' from database: %s", key, status.ToString().c_str());
        return nil;
    }
    
    LevelDBKey lkey = GenericKeyFromSlice(k);
    return DecodeFromSlice(v_string, &lkey);
}
- (id) objectsForKeys:(NSArray *)keys notFoundMarker:(id)marker {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:keys.count];
    [keys enumerateObjectsUsingBlock:^(id objId, NSUInteger idx, BOOL *stop) {
        id object = [self objectForKey:objId];
        if (object == nil) object = marker;
        result[idx] = object;
    }];
    return [NSArray arrayWithArray:result];
}
- (id) valueForKey:(NSString *)key {
    if ([key characterAtIndex:0] == '@') {
        return [super valueForKey:[key stringByReplacingCharactersInRange:(NSRange){0, 1}
                                                               withString:@""]];
    } else
        return [self objectForKey:key];
}

- (void) removeObjectForKey:(id)key {
    Slice k = KeyFromStringOrData(key);
    Status status = db->Delete(writeOptions, k);
    
    if(!status.ok()) {
        NSLog(@"Problem deleting key/value pair in database: %s", status.ToString().c_str());
    }
}

- (void) removeObjectsForKeys:(NSArray *)keyArray {
    [keyArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self removeObjectForKey:obj];
    }];
}

- (void) removeAllObjects {
    [self enumerateKeysAndObjectsUsingBlock:^(LevelDBKey *key, id value, BOOL *stop) {
        [self removeObjectForKey:NSDataFromLevelDBKey(key)];
    }];
}

#pragma mark - Iteration

- (NSArray *)allKeys {
    NSMutableArray *keys = [[[NSMutableArray alloc] init] autorelease];
    [self enumerateKeysUsingBlock:^(LevelDBKey *key, BOOL *stop) {
        [keys addObject:NSDataFromLevelDBKey(key)];
    }];
    return keys;
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block {
    Iterator* iter = db->NewIterator(ReadOptions());
    BOOL stop = false;
    for (iter->SeekToFirst(); iter->Valid(); iter->Next()) {
        Slice key = iter->key(), value = iter->value();
        LevelDBKey k = GenericKeyFromSlice(key);
        id v = DecodeFromSlice(value, &k);
        block(&k, v, &stop);
        if (stop) break;
    }
    delete iter;
}


- (void) enumerateKeysUsingBlock:(KeyBlock)block {
    Iterator* iter = db->NewIterator(ReadOptions());
    BOOL stop = false;
    for (iter->SeekToFirst(); iter->Valid(); iter->Next()) {
        Slice key = iter->key();
        LevelDBKey k = GenericKeyFromSlice(key);
        block(&k, &stop);
        if (stop) break;
    }

    delete iter;
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key {
    
    Slice k = KeyFromStringOrData(key);
    Iterator* iter = db->NewIterator(ReadOptions());
    BOOL stop = false;
    
    for (iter->Seek(k); iter->Valid(); iter->Next()) {
        Slice key2 = iter->key(), value = iter->value();
        LevelDBKey k = GenericKeyFromSlice(key2);
        id v = DecodeFromSlice(value, &k);
        block(&k, v, &stop);
        if (stop) break;
    }
    
    delete iter;
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key {
    
    Slice k = KeyFromStringOrData(key);
    Iterator* iter = db->NewIterator(ReadOptions());
    BOOL stop = false;
    
    for (iter->Seek(k); iter->Valid(); iter->Next()) {
        Slice key2 = iter->key();
        LevelDBKey k = GenericKeyFromSlice(key2);
        block(&k, &stop);
        if (stop) break;
    }
    
    delete iter;
}

- (void) deleteDatabase {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    [fileManager removeItemAtPath:_path error:&error];
}

- (void) close {
    delete db;
}
- (void) dealloc {
    [self close];
    [super dealloc];
}

@end
