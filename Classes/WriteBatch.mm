//
//  WriteBatch.mm
//
//  Copyright 2013 Storm Labs. 
//  See LICENCE for details.
//

#import <leveldb/db.h>
#import <leveldb/write_batch.h>
#import "WriteBatch.h"
#import "Header.h"

@interface Writebatch () {
    leveldb::WriteBatch writeBatch;
}

@property (nonatomic, assign) LevelDB * db;

@end

@implementation Writebatch

+ (Writebatch *) writeBatchFromDB:(LevelDB *)db {
    Writebatch *wb = [[Writebatch alloc] init];
    wb.db = db;
    return wb;
}

- (Writebatch *) init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void) removeObjectForKey:(id)key {
    leveldb::Slice k = KeyFromStringOrData(key);
    writeBatch.Delete(k);
}
- (void) removeObjectsForKeys:(NSArray *)keyArray {
    [keyArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self removeObjectForKey:obj];
    }];
}
- (void) removeAllObjects {
    [_db enumerateKeysUsingBlock:^(LevelDBKey *key, BOOL *stop) {
        [self removeObjectForKey:NSDataFromLevelDBKey(key)];
    }];
}

- (void) setObject:(id)value forKey:(id)key {
    leveldb::Slice k = KeyFromStringOrData(key);
    LevelDBKey lkey = GenericKeyFromSlice(k);
    leveldb::Slice v = EncodeToSlice(value, &lkey, _db.encoder);
    writeBatch.Put(k, v);
}
- (void) setValue:(id)value forKey:(NSString *)key {
    [self setObject:value forKey:key];
}
- (void) addEntriesFromDictionary:(NSDictionary *)dictionary {
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self setObject:obj forKey:key];
    }];
}

- (leveldb::WriteBatch) getWriteBatch {
    return writeBatch;
}
- (void) apply {
    [_db applyBatch:self];
}

@end