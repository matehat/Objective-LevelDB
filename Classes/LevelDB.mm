//
//  LevelDB.m
//
//  Copyright 2011 Pave Labs. All rights reserved. 
//  See LICENCE for details.
//

#import "LevelDB.h"
#import "Snapshot.h"
#import "WriteBatch.h"

#import <leveldb/db.h>
#import <leveldb/options.h>
#import <leveldb/cache.h>
#import <leveldb/filter_policy.h>
#import <leveldb/write_batch.h>

#import "Header.h"

NSString * NSStringFromLevelDBKey(LevelDBKey * key) {
    return [[[NSString alloc] initWithBytes:key->data length:key->length encoding:NSUTF8StringEncoding] autorelease];
}
NSData   * NSDataFromLevelDBKey(LevelDBKey * key) {
    return [[NSData dataWithBytes:key->data length:key->length] autorelease];
}

@implementation LevelDB 

@synthesize db   = db;
@synthesize path = _path;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (id) initWithPath:(NSString *)path {
    LevelDBOptions opts;
    return [self initWithPath:path andOptions:opts];
}
- (id) initWithPath:(NSString *)path andOptions:(LevelDBOptions)opts {
    self = [super init];
    if (self) {
        _path = path;
        leveldb::Options options;
        
        options.create_if_missing = opts.createIfMissing;
        options.paranoid_checks = opts.paranoidCheck;
        options.error_if_exists = opts.errorIfMissing;
        
        if (!opts.compression)
            options.compression = leveldb::kNoCompression;
        
        if (opts.cacheSize > 0)
            options.block_cache = leveldb::NewLRUCache(opts.cacheSize);
        else
            readOptions.fill_cache = false;
        
        if (opts.filterPolicy > 0)
            options.filter_policy = leveldb::NewBloomFilterPolicy(opts.filterPolicy);
        
        leveldb::Status status = leveldb::DB::Open(options, [_path UTF8String], &db);
        
        readOptions.fill_cache = true;
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
    LevelDBOptions opts;
    return [LevelDB databaseInLibraryWithName:name andOptions:opts];
}

+ (LevelDB *)databaseInLibraryWithName:(NSString *)name andOptions:(LevelDBOptions)opts {
    NSString *path = [[LevelDB libraryPath] stringByAppendingPathComponent:name];
    LevelDB *ldb = [[[LevelDB alloc] initWithPath:path andOptions:opts] autorelease];
    return ldb;
}

- (void) setSafe:(BOOL)safe {
    writeOptions.sync = safe;
}
- (BOOL) safe {
    return writeOptions.sync;
}
- (void) setUseCache:(BOOL)useCache {
    readOptions.fill_cache = useCache;
}
- (BOOL) useCache {
    return readOptions.fill_cache;
}

#pragma mark - Setters

- (void) setObject:(id)value forKey:(id)key {
    leveldb::Slice k = KeyFromStringOrData(key);
    LevelDBKey lkey = GenericKeyFromSlice(k);
    leveldb::Slice v = EncodeToSlice(value, &lkey, _encoder);
    
    leveldb::Status status = db->Put(writeOptions, k, v);
    
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

- (void) applyBatch:(Writebatch *)writeBatch {
    leveldb::WriteBatch wb = writeBatch.writeBatch;
    leveldb::Status status = db->Write(writeOptions, &wb);
    if(!status.ok()) {
        NSLog(@"Problem applying the write batch in database: %s", status.ToString().c_str());
    }
}

#pragma mark - Getters

- (id) objectForKey:(id)key {
    [self objectForKey:key withSnapshot:nil];
}
- (id) objectForKey:(id)key
       withSnapshot:(Snapshot *)snapshot {
    
    std::string v_string;
    leveldb::Slice k = KeyFromStringOrData(key);
    CopyReadOptions(readOptions, _readOptions);
    if (snapshot) {
        _readOptions.snapshot = [snapshot getSnapshot];
    }
    leveldb::Status status = db->Get(_readOptions, k, &v_string);
    
    if(!status.ok()) {
        if(!status.IsNotFound())
            NSLog(@"Problem retrieving value for key '%@' from database: %s", key, status.ToString().c_str());
        return nil;
    }
    
    LevelDBKey lkey = GenericKeyFromSlice(k);
    return DecodeFromSlice(v_string, &lkey, _decoder);
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

#pragma mark - Removers

- (void) removeObjectForKey:(id)key {
    leveldb::Slice k = KeyFromStringOrData(key);
    leveldb::Status status = db->Delete(writeOptions, k);
    
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

#pragma mark - Selection

- (NSArray *)allKeys {
    NSMutableArray *keys = [[[NSMutableArray alloc] init] autorelease];
    [self enumerateKeysUsingBlock:^(LevelDBKey *key, BOOL *stop) {
        [keys addObject:NSDataFromLevelDBKey(key)];
    }];
    return [NSArray arrayWithArray:keys];
}
- (NSArray *)keysByFilteringWithPredicate:(NSPredicate *)predicate {
    NSMutableArray *keys = [[[NSMutableArray alloc] init] autorelease];
    [self enumerateKeysUsingBlock:^(LevelDBKey *key, BOOL *stop) {
        [keys addObject:NSDataFromLevelDBKey(key)];
    }
                    startingAtKey:nil
              filteredByPredicate:predicate];
    
    return [NSArray arrayWithArray:keys];
}

- (NSDictionary *)dictionaryByFilteringWithPredicate:(NSPredicate *)predicate {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    [self enumerateKeysAndObjectsUsingBlock:^(LevelDBKey *key, id obj, BOOL *stop) {
        [results setObject:obj forKey:NSDataFromLevelDBKey(key)];
    }
                    startingAtKey:nil
              filteredByPredicate:predicate];
    
    return [NSDictionary dictionaryWithDictionary:results];
}

- (Snapshot *) getSnapshot {
    return [Snapshot snapshotFromDB:self];
}

#pragma mark - Enumeration

- (void) enumerateKeysUsingBlock:(KeyBlock)block {
    [self enumerateKeysUsingBlock:block
                    startingAtKey:nil
              filteredByPredicate:nil
                     withSnapshot:nil];
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key {
    
    [self enumerateKeysUsingBlock:block
                    startingAtKey:key
              filteredByPredicate:nil
                     withSnapshot:nil];
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key
             filteredByPredicate:(NSPredicate *)predicate {
    [self enumerateKeysUsingBlock:block
                    startingAtKey:key
              filteredByPredicate:predicate
                     withSnapshot:nil];
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key
             filteredByPredicate:(NSPredicate *)predicate
                    withSnapshot:(Snapshot *)snapshot {

    CopyReadOptions(readOptions, _readOptions);
    if (snapshot) {
        _readOptions.snapshot = [snapshot getSnapshot];
    }
    leveldb::Iterator* iter = db->NewIterator(_readOptions);
    leveldb::Slice ikey, ivalue;
    BOOL stop = false;
    
    if (key) {
        iter->Seek(KeyFromStringOrData(key));
    } else {
        iter->SeekToFirst();
    }
    
    for (; iter->Valid(); iter->Next()) {
        ikey = iter->key();
        ivalue = iter->value();
        
        LevelDBKey lk = GenericKeyFromSlice(ikey);
        id v = DecodeFromSlice(ivalue, &lk, _decoder);
        if (predicate == nil || [predicate evaluateWithObject:v]) {
            block(&lk, &stop);
            if (stop) break;
        }
    }
    
    delete iter;
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block {
    [self enumerateKeysAndObjectsUsingBlock:block
                              startingAtKey:nil
                        filteredByPredicate:nil
                               withSnapshot:nil];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key {
    [self enumerateKeysAndObjectsUsingBlock:block
                              startingAtKey:key
                        filteredByPredicate:nil
                               withSnapshot:nil];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key
                       filteredByPredicate:(NSPredicate *)predicate  {
    [self enumerateKeysAndObjectsUsingBlock:block
                              startingAtKey:key
                        filteredByPredicate:predicate
                               withSnapshot:nil];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key
                       filteredByPredicate:(NSPredicate *)predicate
                              withSnapshot:(Snapshot *)snapshot {
    
    CopyReadOptions(readOptions, _readOptions);
    if (snapshot) {
        _readOptions.snapshot = [snapshot getSnapshot];
    }
    leveldb::Iterator* iter = db->NewIterator(_readOptions);
    leveldb::Slice ikey, ivalue;
    BOOL stop = false;
    
    if (key) {
        leveldb::Slice k = KeyFromStringOrData(key);
        iter->Seek(k);
    } else {
        iter->SeekToFirst();
    }
    
    for (; iter->Valid(); iter->Next()) {
        ikey = iter->key();
        ivalue = iter->value();
        LevelDBKey lk = GenericKeyFromSlice(ikey);
        id v = DecodeFromSlice(ivalue, &lk, _decoder);
        if (predicate == nil || [predicate evaluateWithObject:v]) {
            block(&lk, v, &stop);
            if (stop) break;
        }
    }
    
    delete iter;
}

#pragma mark - Bookkeeping

- (void) deleteDatabaseFromDisk {
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
