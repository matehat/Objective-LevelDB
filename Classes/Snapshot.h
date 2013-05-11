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

- (NSArray *)allKeys;
- (NSArray *)keysByFilteringWithPredicate:(NSPredicate *)predicate;
- (NSDictionary *)dictionaryByFilteringWithPredicate:(NSPredicate *)predicate;

- (void) enumerateKeysUsingBlock:(KeyBlock)block;

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key;

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key
             filteredByPredicate:(NSPredicate *)predicate;

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block;

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key;

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key
                       filteredByPredicate:(NSPredicate *)predicate;

- (void) release;

@end