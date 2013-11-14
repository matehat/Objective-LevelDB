//
//  LevelDB.h
//
//  Copyright 2011 Pave Labs. 
//  See LICENCE for details.
//

#import <Foundation/Foundation.h>

@class Snapshot;
@class Writebatch;

typedef struct LevelDBOptions {
    BOOL createIfMissing ;
    BOOL createIntermediateDirectories;
    BOOL errorIfExists   ;
    BOOL paranoidCheck   ;
    BOOL compression     ;
    int  filterPolicy    ;
    unsigned long long cacheSize;
} LevelDBOptions;

typedef struct {
    const char * data;
    int          length;
} LevelDBKey;

typedef NSData * (^LevelDBEncoderBlock) (LevelDBKey * key, id object);
typedef id       (^LevelDBDecoderBlock) (LevelDBKey * key, id data);

typedef void     (^LevelDBKeyBlock)     (LevelDBKey * key, BOOL *stop);
typedef void     (^LevelDBKeyValueBlock)(LevelDBKey * key, id value, BOOL *stop);

typedef id       (^LevelDBValueGetterBlock)  (void);
typedef void     (^LevelDBLazyKeyValueBlock) (LevelDBKey * key, LevelDBValueGetterBlock lazyValue, BOOL *stop);

FOUNDATION_EXPORT NSString * const kLevelDBChangeType;
FOUNDATION_EXPORT NSString * const kLevelDBChangeTypePut;
FOUNDATION_EXPORT NSString * const kLevelDBChangeTypeDelete;
FOUNDATION_EXPORT NSString * const kLevelDBChangeValue;
FOUNDATION_EXPORT NSString * const kLevelDBChangeKey;

#ifdef __cplusplus
extern "C" {
#endif
    
NSString * NSStringFromLevelDBKey(LevelDBKey * key);
NSData   * NSDataFromLevelDBKey  (LevelDBKey * key);

#ifdef __cplusplus
}
#endif

@interface LevelDB : NSObject

@property (nonatomic, retain) NSString *path;
@property (nonatomic, retain) NSString *name;

@property (nonatomic) BOOL safe;
@property (nonatomic) BOOL useCache;
@property (readonly) BOOL closed;

@property (nonatomic, copy) LevelDBEncoderBlock encoder;
@property (nonatomic, copy) LevelDBDecoderBlock decoder;

+ (LevelDBOptions) makeOptions;

+ (id) databaseInLibraryWithName:(NSString *)name;
+ (id) databaseInLibraryWithName:(NSString *)name andOptions:(LevelDBOptions)opts;

- (id) initWithPath:(NSString *)path andName:(NSString *)name;
- (id) initWithPath:(NSString *)path name:(NSString *)name andOptions:(LevelDBOptions)opts;

- (void) deleteDatabaseFromDisk;
- (void) close;

#pragma mark - Setters

- (void) setObject:(id)value forKey:(id)key;
- (void) setValue:(id)value forKey:(NSString *)key ;
- (void) addEntriesFromDictionary:(NSDictionary *)dictionary;

- (void) applyBatch:(Writebatch *)writeBatch;

#pragma mark - Getters

- (id) objectForKey:(id)key;
- (id) objectForKey:(id)key withSnapshot:(Snapshot *)snapshot;
- (id) objectForKeyedSubscript:(id)key;

- (id) objectsForKeys:(NSArray *)keys notFoundMarker:(id)marker;
- (id) valueForKey:(NSString *)key;

- (BOOL) objectExistsForKey:(id)key;
- (BOOL) objectExistsForKey:(id)key
               withSnapshot:(Snapshot *)snapshot;

#pragma mark - Removers

- (void) removeObjectForKey:(id)key;
- (void) removeObjectsForKeys:(NSArray *)keyArray;
- (void) removeAllObjects;
- (void) removeAllObjectsWithPrefix:(id)prefix;

#pragma mark - Selection

- (NSArray *) allKeys;
- (NSArray *) keysByFilteringWithPredicate:(NSPredicate *)predicate;
- (NSDictionary *) dictionaryByFilteringWithPredicate:(NSPredicate *)predicate;
- (Snapshot *) getSnapshot;

#pragma mark - Enumeration

- (void) enumerateKeysUsingBlock:(LevelDBKeyBlock)block;
- (void) enumerateKeysBackward:(BOOL)backward
                 startingAtKey:(id)key
           filteredByPredicate:(NSPredicate *)predicate
                     andPrefix:(id)prefix
                  withSnapshot:(Snapshot *)snapshot
                    usingBlock:(LevelDBKeyBlock)block;

- (void) enumerateKeysAndObjectsUsingBlock:(LevelDBKeyValueBlock)block;
- (void) enumerateKeysAndObjectsBackward:(BOOL)backward
                                  lazily:(BOOL)lazily
                           startingAtKey:(id)key
                     filteredByPredicate:(NSPredicate *)predicate
                               andPrefix:(id)prefix
                            withSnapshot:(Snapshot *)snapshot
                              usingBlock:(id)block;

@end
