//
//  Snapshot.mm
//
//  Copyright 2013 Storm Labs.
//  See LICENCE for details.
//

#import "Snapshot.h"

@interface Snapshot () {
    const leveldb::Snapshot * _snapshot;
}

@property (readonly, getter = getSnapshot) const leveldb::Snapshot * snapshot;

@end

@implementation Snapshot

+ (Snapshot *) snapshotFromDB:(LevelDB *)database {
    Snapshot *snapshot = [[[Snapshot alloc] init] autorelease];
    snapshot->_snapshot = database.db->GetSnapshot();
    snapshot->_db = database;
    return snapshot;
}

- (const leveldb::Snapshot *) getSnapshot {
    return _snapshot;
}

- (id) objectForKey:(id)key {
    [_db objectForKey:key withSnapshot:self];
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
    [_db enumerateKeysUsingBlock:block
                    startingAtKey:nil
              filteredByPredicate:nil
                     withSnapshot:self];
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key {
    [_db enumerateKeysUsingBlock:block
                    startingAtKey:key
              filteredByPredicate:nil
                     withSnapshot:self];
}

- (void) enumerateKeysUsingBlock:(KeyBlock)block
                   startingAtKey:(id)key
             filteredByPredicate:(NSPredicate *)predicate {
    [_db enumerateKeysUsingBlock:block
                    startingAtKey:key
              filteredByPredicate:predicate
                     withSnapshot:nil];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block {
    [_db enumerateKeysAndObjectsUsingBlock:block
                              startingAtKey:nil
                        filteredByPredicate:nil
                               withSnapshot:self];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key {
    [_db enumerateKeysAndObjectsUsingBlock:block
                              startingAtKey:key
                        filteredByPredicate:nil
                               withSnapshot:self];
}

- (void) enumerateKeysAndObjectsUsingBlock:(KeyValueBlock)block
                             startingAtKey:(id)key
                       filteredByPredicate:(NSPredicate *)predicate  {
    [_db enumerateKeysAndObjectsUsingBlock:block
                              startingAtKey:key
                        filteredByPredicate:predicate
                               withSnapshot:self];
}

@end