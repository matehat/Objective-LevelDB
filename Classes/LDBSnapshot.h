//
//  LDBSnapshot.h
//
//  Copyright 2013 Storm Labs.
//  See LICENCE for details.
//

#import <Foundation/Foundation.h>
#import "LevelDB.h"

@class LevelDB;

@interface LDBSnapshot : NSObject 

@property (nonatomic, readonly, assign) LevelDB * db;

+ (id) snapshotFromDB:(LevelDB *)database;

- (id) objectForKey:(id)key;
- (id) objectForKeyedSubscript:(id)key;

- (id) objectsForKeys:(NSArray *)keys notFoundMarker:(id)marker;
- (id) valueForKey:(NSString *)key;

- (BOOL) objectExistsForKey:(id)key;

- (NSArray *)allKeys;
- (NSArray *)keysByFilteringWithPredicate:(NSPredicate *)predicate;
- (NSDictionary *)dictionaryByFilteringWithPredicate:(NSPredicate *)predicate;

- (void) enumerateKeysUsingBlock:(LevelDBKeyBlock)block;
- (void) enumerateKeysBackward:(BOOL)backward
                 startingAtKey:(id)key
           filteredByPredicate:(NSPredicate *)predicate
                     andPrefix:(id)prefix
                    usingBlock:(LevelDBKeyBlock)block;

- (void) enumerateKeysAndObjectsUsingBlock:(LevelDBKeyValueBlock)block;
- (void) enumerateKeysAndObjectsBackward:(BOOL)backward
                                  lazily:(BOOL)lazily
                           startingAtKey:(id)key
                     filteredByPredicate:(NSPredicate *)predicate
                               andPrefix:(id)prefix
                              usingBlock:(id)block;

- (void) close;

@end