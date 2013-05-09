//
//  LevelDB.h
//
//  Copyright 2011 Pave Labs. 
//  See LICENCE for details.
//

#import <Foundation/Foundation.h>
#import "leveldb/db.h"

@class Snapshot;
@class Writebatch;

typedef struct LevelDBOptions {
    BOOL createIfMissing = true;
    BOOL errorIfMissing  = false;
    BOOL paranoidCheck   = false;
    BOOL compression     = true;
    int  filterPolicy    = 0;
    unsigned long long cacheSize  = 0;
} LevelDBOptions;

typedef struct {
    const char * data;
    int          length;
} LevelDBKey;

typedef NSData * (^EncoderBlock) (LevelDBKey * key, id object);
typedef id       (^DecoderBlock) (LevelDBKey * key, id data);

typedef void     (^KeyBlock)     (LevelDBKey * key, BOOL *stop);
typedef void     (^KeyValueBlock)(LevelDBKey * key, id value, BOOL *stop);

NSString * NSStringFromLevelDBKey(LevelDBKey * key);
NSData   * NSDataFromLevelDBKey  (LevelDBKey * key);

@interface LevelDB : NSObject {
    leveldb::DB * db;
    leveldb::ReadOptions readOptions;
    leveldb::WriteOptions writeOptions;
}

@property (nonatomic, readonly) leveldb::DB * db;
@property (nonatomic, retain) NSString *path;

@property (nonatomic) BOOL safe;
@property (nonatomic) BOOL useCache;

@property (nonatomic, copy) EncoderBlock encoder;
@property (nonatomic, copy) DecoderBlock decoder;

+ (id) libraryPath;

+ (LevelDB *) databaseInLibraryWithName:(NSString *)name;
+ (LevelDB *) databaseInLibraryWithName:(NSString *)name andOptions:(LevelDBOptions)opts;

- (id) initWithPath:(NSString *)path;
- (id) initWithPath:(NSString *)path andOptions:(LevelDBOptions)opts;

#pragma mark - Setters

- (void) setObject:(id)value forKey:(id)key;
- (void) setValue:(id)value forKey:(NSString *)key ;
- (void) addEntriesFromDictionary:(NSDictionary *)dictionary;

- (void) applyBatch:(Writebatch *)writeBatch;

#pragma mark - Getters

- (id) objectForKey:(id)key;
- (id) objectForKey:(id)key withSnapshot:(Snapshot *)snapshot;

- (id) objectsForKeys:(NSArray *)keys notFoundMarker:(id)marker;
- (id) valueForKey:(NSString *)key;

#pragma mark - Removers

- (void) removeObjectForKey:(id)key;
- (void) removeObjectsForKeys:(NSArray *)keyArray;
- (void) removeAllObjects;

#pragma mark - Selection

- (NSArray *) allKeys;
- (NSArray *) keysByFilteringWithPredicate:(NSPredicate *)predicate;
- (NSDictionary *)dictionaryByFilteringWithPredicate:(NSPredicate *)predicate;
- (Snapshot *) getSnapshot;

#pragma mark - Enumeration

- (void) enumerateKeysUsingBlock:(KeyBlock)block;
- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key;
- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key
             filteredByPredicate:(NSPredicate *)predicate;
- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key
             filteredByPredicate:(NSPredicate *)predicate
                    withSnapshot:(Snapshot *)snapshot;

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block;
- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key;
- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key
                       filteredByPredicate:(NSPredicate *)predicate;
- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key
                       filteredByPredicate:(NSPredicate *)predicate
                              withSnapshot:(Snapshot *)snapshot;

#pragma mark - Bookkeeping

- (void) deleteDatabaseFromDisk;
- (void) close;

@end
