//
//  Snapshot.h
//
//  Copyright 2013 Storm Labs.
//  See LICENCE for details.
//

#import <Foundation/Foundation.h>
#import "LevelDB.h"

@class LevelDB;

@interface Snapshot : NSObject 

@property (nonatomic, readonly, assign) LevelDB * db;

+ (id) snapshotFromDB:(LevelDB *)database;

- (id) objectForKey:(id)key;
- (id) objectsForKeys:(NSArray *)keys notFoundMarker:(id)marker;
- (id) valueForKey:(NSString *)key;

- (BOOL) objectExistsForKey:(id)key;

- (NSArray *)allKeys;
- (NSArray *)keysByFilteringWithPredicate:(NSPredicate *)predicate;
- (NSDictionary *)dictionaryByFilteringWithPredicate:(NSPredicate *)predicate;

- (void) enumerateKeysUsingBlock:(LevelDBKeyBlock)block;
- (void) enumerateKeysBackwardUsingBlock:(LevelDBKeyBlock)block;

- (void) enumerateKeysUsingBlock:(LevelDBKeyBlock)block
                   startingAtKey:(id)key;

- (void) enumerateKeysUsingBlock:(LevelDBKeyBlock)block
                   startingAtKey:(id)key
             filteredByPredicate:(NSPredicate *)predicate;

- (void) enumerateKeysAndObjectsUsingBlock:(LevelDBKeyValueBlock)block;
- (void) enumerateKeysAndObjectsBackwardUsingBlock:(LevelDBKeyValueBlock)block;

- (void) enumerateKeysAndObjectsUsingBlock:(LevelDBKeyValueBlock)block
                             startingAtKey:(id)key;

- (void) enumerateKeysAndObjectsUsingBlock:(LevelDBKeyValueBlock)block
                             startingAtKey:(id)key
                       filteredByPredicate:(NSPredicate *)predicate;

- (void) enumerateKeysAndObjectsLazilyUsingBlock:(LevelDBLazyKeyValueBlock)block
                                   startingAtKey:(id)key
                             filteredByPredicate:(NSPredicate *)predicate;

- (void) release;

@end