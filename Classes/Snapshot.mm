//
//  Snapshot.mm
//
//  Copyright 2013 Storm Labs.
//  See LICENCE for details.
//

#import "Snapshot.h"
#import <leveldb/db.h>

@interface LevelDB ()
- (leveldb::DB *)db;
@end

@interface Snapshot () {
    const leveldb::Snapshot * _snapshot;
}

@property (readonly, getter = getSnapshot) const leveldb::Snapshot * snapshot;
- (const leveldb::Snapshot *) getSnapshot;

@end

@implementation Snapshot 

+ (Snapshot *) snapshotFromDB:(LevelDB *)database {
    Snapshot *snapshot = [[[Snapshot alloc] init] autorelease];
    snapshot->_snapshot = [database db]->GetSnapshot();
    snapshot->_db = database;
    return snapshot;
}

- (const leveldb::Snapshot *) getSnapshot {
    return _snapshot;
}

- (id) objectForKey:(id)key {
    return [_db objectForKey:key withSnapshot:self];
}
- (BOOL) objectExistsForKey:(id)key {
    return [_db objectExistsForKey:key withSnapshot:self];
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

- (void) enumerateKeysUsingBlock:(KeyBlock)block {
    [_db enumerateKeysBackward:FALSE
                    usingBlock:block
                 startingAtKey:nil
           filteredByPredicate:nil
                  withSnapshot:self];
}
- (void) enumerateKeysBackwardUsingBlock:(KeyBlock)block {
    [_db enumerateKeysBackward:TRUE
                    usingBlock:block
                 startingAtKey:nil
           filteredByPredicate:nil
                  withSnapshot:self];
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key {
    [_db enumerateKeysBackward:FALSE
                    usingBlock:block
                 startingAtKey:key
           filteredByPredicate:nil
                  withSnapshot:self];
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key
             filteredByPredicate:(NSPredicate *)predicate {
    [_db enumerateKeysBackward:FALSE
                    usingBlock:block
                 startingAtKey:key
           filteredByPredicate:predicate
                  withSnapshot:nil];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block {
    [_db enumerateKeysAndObjectsBackward:FALSE
                              usingBlock:block
                           startingAtKey:nil
                     filteredByPredicate:nil
                            withSnapshot:self];
}
- (void) enumerateKeysAndObjectsBackwardUsingBlock:(KeyValueBlock)block {
    [_db enumerateKeysAndObjectsBackward:TRUE
                              usingBlock:block
                           startingAtKey:nil
                     filteredByPredicate:nil
                            withSnapshot:self];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key {
    [_db enumerateKeysAndObjectsBackward:FALSE
                              usingBlock:block
                           startingAtKey:key
                     filteredByPredicate:nil
                            withSnapshot:self];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key
                       filteredByPredicate:(NSPredicate *)predicate  {
    [_db enumerateKeysAndObjectsBackward:FALSE
                              usingBlock:block
                           startingAtKey:key
                     filteredByPredicate:predicate
                            withSnapshot:self];
}

- (void) release {
    [_db db]->ReleaseSnapshot(_snapshot);
}
- (void) dealloc {
    [self release];
    [super dealloc];
}

@end