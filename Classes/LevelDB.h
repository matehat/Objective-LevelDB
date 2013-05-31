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

@property (nonatomic, copy) LevelDBEncoderBlock encoder;
@property (nonatomic, copy) LevelDBDecoderBlock decoder;

+ (LevelDBOptions) makeOptions;

+ (id) databaseInLibraryWithName:(NSString *)name;
+ (id) databaseInLibraryWithName:(NSString *)name andOptions:(LevelDBOptions)opts;

- (id) initWithPath:(NSString *)path andName:(NSString *)name;
- (id) initWithPath:(NSString *)path name:(NSString *)name andOptions:(LevelDBOptions)opts;

#pragma mark - Notifications

- (void) addObserver:(NSObject *)observer
            selector:(SEL)selector
                 key:(NSString *)key;

- (id) addObserverForKey:(NSString *)key
                   queue:(NSOperationQueue *)queue
              usingBlock:(void (^)(NSNotification *))block;

- (void) removeObserver:(id)observer;
- (void) removeObserver:(id)observer
                 forKey:(NSString *)key;

- (void) pauseObserving;
- (void) resumeObserving;

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

- (BOOL) objectExistsForKey:(id)key;
- (BOOL) objectExistsForKey:(id)key
               withSnapshot:(Snapshot *)snapshot;

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

- (void) enumerateKeysUsingBlock:(LevelDBKeyBlock)block;
- (void) enumerateKeysBackwardUsingBlock:(LevelDBKeyBlock)block;

- (void) enumerateKeysUsingBlock:(LevelDBKeyBlock)block
                   startingAtKey:(id)key;

- (void) enumerateKeysBackward:(BOOL)backward
                    usingBlock:(LevelDBKeyBlock)block
                 startingAtKey:(id)key
           filteredByPredicate:(NSPredicate *)predicate
                  withSnapshot:(Snapshot *)snapshot;

- (void) enumerateKeysAndObjectsUsingBlock:(LevelDBKeyValueBlock)block;
- (void) enumerateKeysAndObjectsBackwardUsingBlock:(LevelDBKeyValueBlock)block;

- (void) enumerateKeysAndObjectsUsingBlock:(LevelDBKeyValueBlock)block
                             startingAtKey:(id)key;

- (void) enumerateKeysAndObjectsBackward:(BOOL)backward
                              usingBlock:(LevelDBKeyValueBlock)block
                           startingAtKey:(id)key
                     filteredByPredicate:(NSPredicate *)predicate
                            withSnapshot:(Snapshot *)snapshot;

- (void) enumerateKeysAndObjectsBackward:(BOOL)backward
                        lazilyUsingBlock:(LevelDBLazyKeyValueBlock)block
                           startingAtKey:(id)key
                     filteredByPredicate:(NSPredicate *)predicate
                            withSnapshot:(Snapshot *)snapshot;

#pragma mark - Bookkeeping

- (void) deleteDatabaseFromDisk;
- (void) close;

@end
