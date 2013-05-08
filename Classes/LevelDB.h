//
//  LevelDB.h
//
//  Copyright 2011 Pave Labs. 
//  See LICENCE for details.
//

#import <Foundation/Foundation.h>

#import "leveldb/db.h"

using namespace leveldb;

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
    DB *db;
    ReadOptions readOptions;
    WriteOptions writeOptions;
}

@property (nonatomic, retain) NSString *path;
@property (nonatomic) BOOL safe;

@property (nonatomic, copy) EncoderBlock encoder;
@property (nonatomic, copy) DecoderBlock decoder;

+ (id)libraryPath;
+ (LevelDB *)databaseInLibraryWithName:(NSString *)name;

- (id) initWithPath:(NSString *)path;

- (void) setObject:(id)value forKey:(id)key;
- (void) setValue:(id)value forKey:(NSString *)key ;
- (void) addEntriesFromDictionary:(NSDictionary *)dictionary;

- (id) objectForKey:(id)key;
- (id) objectsForKeys:(NSArray *)keys notFoundMarker:(id)marker;
- (id) valueForKey:(NSString *)key;

- (void) removeObjectForKey:(id)key;
- (void) removeObjectsForKeys:(NSArray *)keyArray;
- (void) removeAllObjects;

#pragma mark - Iteration

- (NSArray *)allKeys;

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block;
- (void) enumerateKeysUsingBlock:(KeyBlock)block;

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key;

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key;

- (void) deleteDatabase;

- (void) close;

@end
