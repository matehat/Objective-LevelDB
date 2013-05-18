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

#define MaybeAddSnapshotToOptions(_from_, _to_, _snap_) \
    leveldb::ReadOptions __to_;\
    leveldb::ReadOptions * _to_ = &__to_;\
    if (_snap_ != nil) { \
        _to_->fill_cache = _from_.fill_cache; \
        _to_->snapshot = [_snap_ getSnapshot]; \
    } else \
        _to_ = &_from_;

#define SeekToFirstOrKey(iter, key, _backward_) \
    (key != nil) ? iter->Seek(KeyFromStringOrData(key)) : \
    _backward_ ? iter->SeekToLast() : iter->SeekToFirst()

#define MoveCursor(_iter_, _backward_) \
    _backward_ ? iter->Prev() : iter->Next()

namespace {
    class BatchIterator : public leveldb::WriteBatch::Handler {
    public:
        void (^putCallback)(const leveldb::Slice& key, const leveldb::Slice& value);
        void (^deleteCallback)(const leveldb::Slice& key);
        
        virtual void Put(const leveldb::Slice& key, const leveldb::Slice& value) {
            putCallback(key, value);
        }
        virtual void Delete(const leveldb::Slice& key) {
            deleteCallback(key);
        }
    };
}

NSString * NSStringFromLevelDBKey(LevelDBKey * key) {
    return [[[NSString alloc] initWithBytes:key->data length:key->length encoding:NSUTF8StringEncoding] autorelease];
}
NSData   * NSDataFromLevelDBKey(LevelDBKey * key) {
    return [NSData dataWithBytes:key->data length:key->length];
}

NSString * getLibraryPath() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

NSString * const kLevelDBChangeType         = @"changeType";
NSString * const kLevelDBChangeTypePut      = @"put";
NSString * const kLevelDBChangeTypeDelete   = @"del";
NSString * const kLevelDBChangeValue        = @"value";
NSString * const kLevelDBChangeKey          = @"key";

LevelDBOptions MakeLevelDBOptions() {
    return (LevelDBOptions) {true, true, false, false, true, 0, 0};
}

@interface Snapshot ()
- (const leveldb::Snapshot *) getSnapshot;
@end

@interface Writebatch ()
- (leveldb::WriteBatch) writeBatch;
@end

@interface LevelDB () {
    leveldb::DB * db;
    leveldb::ReadOptions readOptions;
    leveldb::WriteOptions writeOptions;
}

@property (nonatomic, readonly) leveldb::DB * db;

@end

@implementation LevelDB {
    BOOL _hasObservers;
}

@synthesize db   = db;
@synthesize path = _path;

static NSNotificationCenter * _notificationCenter;

+ (LevelDBOptions) makeOptions {
    return MakeLevelDBOptions();
}
+ (void) ensureNotificationCenterExists {
    if (_notificationCenter == nil)
        _notificationCenter = [[NSNotificationCenter alloc] init];
}

- (id) initWithPath:(NSString *)path andName:(NSString *)name {
    LevelDBOptions opts = MakeLevelDBOptions();
    return [self initWithPath:path name:name andOptions:opts];
}
- (id) initWithPath:(NSString *)path name:(NSString *)name andOptions:(LevelDBOptions)opts {
    self = [super init];
    if (self) {
        _name = name;
        _hasObservers = false;
        _path = path;
        
        leveldb::Options options;
        
        options.create_if_missing = opts.createIfMissing;
        options.paranoid_checks = opts.paranoidCheck;
        options.error_if_exists = opts.errorIfExists;
        
        if (!opts.compression)
            options.compression = leveldb::kNoCompression;
        
        if (opts.cacheSize > 0)
            options.block_cache = leveldb::NewLRUCache(opts.cacheSize);
        else
            readOptions.fill_cache = false;
        
        if (opts.createIntermediateDirectories) {
            NSString *dirpath = [path stringByDeletingLastPathComponent];
            NSFileManager *fm = [NSFileManager defaultManager];
            NSError *crError;
            
            BOOL success = [fm createDirectoryAtPath:dirpath
                         withIntermediateDirectories:true
                                          attributes:nil
                                               error:&crError];
            if (!success) {
                NSLog(@"Problem creating parent directory: %@", crError);
            }
        }
        
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

+ (id)databaseInLibraryWithName:(NSString *)name {
    LevelDBOptions opts = MakeLevelDBOptions();
    return [self databaseInLibraryWithName:name andOptions:opts];
}

+ (id)databaseInLibraryWithName:(NSString *)name andOptions:(LevelDBOptions)opts {
    NSString *path = [getLibraryPath() stringByAppendingPathComponent:name];
    LevelDB *ldb = [[[self alloc] initWithPath:path name:name andOptions:opts] autorelease];
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

#pragma mark - Notifications

- (void) addObserver:(NSObject *)observer
            selector:(SEL)selector
                 key:(NSString *)key {
    
    _hasObservers = true;
    [LevelDB ensureNotificationCenterExists];
    [_notificationCenter addObserver:observer
                            selector:selector
                                name:[self notificationNameForKey:key]
                              object:self];
}
- (id) addObserverForKey:(NSString *)key
                   queue:(NSOperationQueue *)queue
              usingBlock:(void (^)(NSNotification *))block {
    
    _hasObservers = true;
    [LevelDB ensureNotificationCenterExists];
    return [_notificationCenter addObserverForName:[self notificationNameForKey:key]
                                            object:self
                                             queue:queue
                                        usingBlock:block];
}
- (void) removeObserver:(id)observer {
    [_notificationCenter removeObserver:observer name:nil object:self];
}
- (void) removeObserver:(id)observer forKey:(NSString *)key {
    [_notificationCenter removeObserver:observer
                                   name:[self notificationNameForKey:key]
                                 object:self];
}
- (void) pauseObserving {
    _hasObservers = false;
}
- (void) resumeObserving {
    _hasObservers = true;
}

- (NSString *)notificationNameForKey:(NSString *)key {
    return [NSString stringWithFormat:@"%@.%@", _name, key];
}

#pragma mark - Setters

- (void) setObject:(id)value forKey:(id)key {
    leveldb::Slice k = KeyFromStringOrData(key);
    LevelDBKey lkey = GenericKeyFromSlice(k);
    leveldb::Slice v = EncodeToSlice(value, &lkey, _encoder);
    
    leveldb::Status status = db->Put(writeOptions, k, v);
    
    if(!status.ok()) {
        NSLog(@"Problem storing key/value pair in database: %s", status.ToString().c_str());
    } else if (_hasObservers && [key isKindOfClass:[NSString class]]) {
        [_notificationCenter postNotificationName:[self notificationNameForKey:key]
                                           object:self
                                         userInfo:@{    kLevelDBChangeType : kLevelDBChangeTypePut,
                                                        kLevelDBChangeKey  : key,
                                                        kLevelDBChangeValue: value }];
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
    leveldb::WriteBatch wb = [writeBatch writeBatch];
    
    if (_hasObservers) {
        BatchIterator iterator;
        __block NSString *key;
        
        iterator.putCallback = ^(const leveldb::Slice& lkey, const leveldb::Slice& lvalue) {
            key = StringFromSlice(lkey);
            LevelDBKey llkey = GenericKeyFromSlice(lkey);
            [_notificationCenter postNotificationName:[self notificationNameForKey:key]
                                               object:self
                                             userInfo:@{    kLevelDBChangeType : kLevelDBChangeTypePut,
                                                            kLevelDBChangeKey  : key,
                                                            kLevelDBChangeValue: DecodeFromSlice(lvalue, &llkey, _decoder) }];
        };
        iterator.deleteCallback = ^(const leveldb::Slice& lkey) {
            key = StringFromSlice(lkey);
            [_notificationCenter postNotificationName:[self notificationNameForKey:key]
                                               object:self
                                             userInfo:@{    kLevelDBChangeType : kLevelDBChangeTypeDelete,
                                                            kLevelDBChangeKey  : key }];
        };
        wb.Iterate(&iterator);
    }
    
    leveldb::Status status = db->Write(writeOptions, &wb);
    if(!status.ok()) {
        NSLog(@"Problem applying the write batch in database: %s", status.ToString().c_str());
    }
}

#pragma mark - Getters

- (id) objectForKey:(id)key {
    return [self objectForKey:key withSnapshot:nil];
}
- (id) objectForKey:(id)key
       withSnapshot:(Snapshot *)snapshot {
    
    std::string v_string;
    MaybeAddSnapshotToOptions(readOptions, readOptionsPtr, snapshot);
    leveldb::Slice k = KeyFromStringOrData(key);
    leveldb::Status status = db->Get(*readOptionsPtr, k, &v_string);
    
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

- (BOOL) objectExistsForKey:(id)key {
    return [self objectExistsForKey:key withSnapshot:nil];
}
- (BOOL) objectExistsForKey:(id)key
               withSnapshot:(Snapshot *)snapshot {
    std::string v_string;
    MaybeAddSnapshotToOptions(readOptions, readOptionsPtr, snapshot);
    leveldb::Slice k = KeyFromStringOrData(key);
    leveldb::Status status = db->Get(*readOptionsPtr, k, &v_string);
    
    if (!status.ok()) {
        if (status.IsNotFound())
            return false;
        else {
            NSLog(@"Problem retrieving value for key '%@' from database: %s", key, status.ToString().c_str());
            return NULL;
        }
    } else
        return true;
}

#pragma mark - Removers

- (void) removeObjectForKey:(id)key {
    leveldb::Slice k = KeyFromStringOrData(key);
    leveldb::Status status = db->Delete(writeOptions, k);
    
    if(!status.ok()) {
        NSLog(@"Problem deleting key/value pair in database: %s", status.ToString().c_str());
    } else if (_hasObservers && [key isKindOfClass:[NSString class]]) {
        [_notificationCenter postNotificationName:[self notificationNameForKey:key]
                                           object:self
                                         userInfo:@{ kLevelDBChangeType : kLevelDBChangeTypeDelete,
                                                     kLevelDBChangeKey  : key }];
    }
}

- (void) removeObjectsForKeys:(NSArray *)keyArray {
    [keyArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self removeObjectForKey:obj];
    }];
}

- (void) removeAllObjects {
    leveldb::Iterator * iter = db->NewIterator(readOptions);
    leveldb::Slice lkey;
    
    if (_hasObservers) {
        NSMutableArray * keys = [NSMutableArray arrayWithCapacity:100];
        void(^notifyForKeys)(NSArray *keys) = ^(NSArray *keys) {
            for (NSString *key in [keys objectEnumerator]) {
                [_notificationCenter postNotificationName:[self notificationNameForKey:key]
                                                   object:self
                                                 userInfo:@{ kLevelDBChangeType : kLevelDBChangeTypeDelete,
                                                             kLevelDBChangeKey  : key }];
            }
        };
        
        for (iter->SeekToFirst(); iter->Valid(); iter->Next()) {
            lkey = iter->key();
            [keys addObject:StringFromSlice(lkey)];
            db->Delete(writeOptions, lkey);
            
            if (keys.count == 100) {
                notifyForKeys(keys);
                [keys removeAllObjects];
            }
        }
        if (keys.count > 0)
            notifyForKeys(keys);
        
    } else {
        for (iter->SeekToFirst(); iter->Valid(); iter->Next())
            db->Delete(writeOptions, iter->key());
    }
    delete iter;
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
    
    [self enumerateKeysBackward:FALSE
                     usingBlock:block
                  startingAtKey:nil
            filteredByPredicate:nil
                   withSnapshot:nil];
}

- (void) enumerateKeysBackwardUsingBlock:(KeyBlock)block {
    
    [self enumerateKeysBackward:TRUE
                     usingBlock:block
                  startingAtKey:nil
            filteredByPredicate:nil
                   withSnapshot:nil];
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key {
    
    [self enumerateKeysBackward:FALSE
                     usingBlock:block
                  startingAtKey:key
            filteredByPredicate:nil
                   withSnapshot:nil];
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key
             filteredByPredicate:(NSPredicate *)predicate {
    
    [self enumerateKeysBackward:FALSE
                     usingBlock:block
                  startingAtKey:key
            filteredByPredicate:predicate
                   withSnapshot:nil];
}

- (void) enumerateKeysBackward:(BOOL)backward
                    usingBlock:(KeyBlock)block
                 startingAtKey:(id)key
           filteredByPredicate:(NSPredicate *)predicate
                  withSnapshot:(Snapshot *)snapshot {

    MaybeAddSnapshotToOptions(readOptions, readOptionsPtr, snapshot);
    leveldb::Iterator* iter = db->NewIterator(*readOptionsPtr);
    BOOL stop = false;
    
    KeyValueBlock iterate = (predicate != nil)
        ? ^(LevelDBKey *lk, id value, BOOL *stop) {
            if ([predicate evaluateWithObject:value]) block(lk, stop);
          }
        
        : ^(LevelDBKey *lk, id value, BOOL *stop) {
            block(lk, stop);
          };
    
    for (SeekToFirstOrKey(iter, key, backward);
         iter->Valid();
         MoveCursor(iter, backward)) {
        
        LevelDBKey lk = GenericKeyFromSlice(iter->key());
        id v = (predicate == nil) ? nil : DecodeFromSlice(iter->value(), &lk, _decoder);
        iterate(&lk, v, &stop);
        if (stop) break;
    }
    
    delete iter;
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block {
    [self enumerateKeysAndObjectsBackward:FALSE
                               usingBlock:block
                            startingAtKey:nil
                      filteredByPredicate:nil
                             withSnapshot:nil];
}
- (void) enumerateKeysAndObjectsBackwardUsingBlock:(KeyValueBlock)block {
    [self enumerateKeysAndObjectsBackward:TRUE
                               usingBlock:block
                            startingAtKey:nil
                      filteredByPredicate:nil
                             withSnapshot:nil];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key {
    [self enumerateKeysAndObjectsBackward:FALSE
                               usingBlock:block
                            startingAtKey:key
                      filteredByPredicate:nil
                             withSnapshot:nil];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key
                       filteredByPredicate:(NSPredicate *)predicate  {
    [self enumerateKeysAndObjectsBackward:FALSE
                               usingBlock:block
                            startingAtKey:key
                      filteredByPredicate:predicate
                             withSnapshot:nil];
}

- (void) enumerateKeysAndObjectsBackward:(BOOL)backward
                              usingBlock:(KeyValueBlock)block
                           startingAtKey:(id)key
                     filteredByPredicate:(NSPredicate *)predicate
                            withSnapshot:(Snapshot *)snapshot {
    
    MaybeAddSnapshotToOptions(readOptions, readOptionsPtr, snapshot);
    leveldb::Iterator* iter = db->NewIterator(*readOptionsPtr);
    BOOL stop = false;
    
    KeyValueBlock iterate = (predicate != nil) ? ^(LevelDBKey *lk, id value, BOOL *stop) {
        if ([predicate evaluateWithObject:value]) block(lk, value, stop);
    } : block;
    
    for (SeekToFirstOrKey(iter, key, backward);
         iter->Valid();
         MoveCursor(iter, backward)) {
        
        LevelDBKey lk = GenericKeyFromSlice(iter->key());
        id v = DecodeFromSlice(iter->value(), &lk, _decoder);
        iterate(&lk, v, &stop);
        if (stop) break;
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
