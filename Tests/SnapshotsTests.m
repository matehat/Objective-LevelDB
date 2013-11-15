//
//  iOS_SnapshotsTests.m
//  Objective-LevelDB Tests
//
//  Created by Mathieu D'Amours on 11/14/13.
//
//

#import "BaseTestClass.h"
#import <Objective-LevelDB/LDBSnapshot.h>

static NSUInteger numberOfIterations = 2500;

@interface SnapshotsTests : BaseTestClass

@end

@implementation SnapshotsTests {
    LDBSnapshot *snapshot;
}

- (void) testInvariability {
    snapshot = [db newSnapshot];
    [db setObject:@{@"foo": @"bar"} forKey:@"key"];
    XCTAssertNil([snapshot objectForKey:@"key"],
                 @"Fetching a key inserted after snapshot was taken should yield nil");
    
    snapshot = nil;
}

- (NSArray *)nPairs:(NSUInteger)n {
    NSMutableArray  *pairs = [NSMutableArray array];
    
    __block NSInteger r;
    __block NSString *key;
    __block NSArray *value;
    
    dispatch_apply(n, lvldb_test_queue, ^(size_t i) {
        do {
            r = arc4random_uniform(5000);
            key = [NSString stringWithFormat:@"%ld", (long)r];
        } while ([db objectExistsForKey:key]);
        
        value = @[@(r), @(i)];
        [pairs addObject:@[key, value]];
        [db setObject:value forKey:key];
    });
    
    [pairs sortUsingComparator:^NSComparisonResult(NSArray *obj1, NSArray *obj2) {
        return [obj1[0] compare:obj2[0]];
    }];
    return pairs;
}

- (void)testContentIntegrity {
    id key = @"dict1";
    id value = @{@"foo": @"bar"};
    [db setObject:value forKey:key];
    snapshot = [db newSnapshot];
    XCTAssertEqualObjects([snapshot objectForKey:key], value,
                          @"Saving and retrieving should keep an dictionary intact");
    
    [db removeObjectForKey:key];
    XCTAssertEqualObjects([snapshot objectForKey:key], value,
                          @"Removing a key from the db should affect a snapshot right away");
    
    snapshot = [db newSnapshot];
    XCTAssertNil([snapshot objectForKey:@"dict1"],
                 @"A new snapshot should have those changes");
    
    value = @[@"foo", @"bar"];
    [db setObject:value forKey:key];
    XCTAssertNil([snapshot objectForKey:@"dict1"],
                 @"Inserting a new value in the db should not affect a previous snapshot");
    
    snapshot = [db newSnapshot];
    XCTAssertEqualObjects([snapshot objectForKey:key], value, @"Saving and retrieving should keep an array intact");
    
    [db removeObjectsForKeys:@[@"array1"]];
    XCTAssertEqualObjects([snapshot objectForKey:key], value,
                          @"Removing a key from the db should affect a snapshot right away");
    
    snapshot = [db newSnapshot];
    XCTAssertNil([snapshot objectForKey:@"array1"], @"A key that was deleted in batch should return nil");
}

- (void)testKeysManipulation {
    id value = @{@"foo": @"bar"};
    
    [db setObject:value forKey:@"dict1"];
    [db setObject:value forKey:@"dict2"];
    [db setObject:value forKey:@"dict3"];
    
    snapshot = [db newSnapshot];
    [db removeAllObjects];
    
    NSArray *keys = @[ @"dict1", @"dict2", @"dict3" ];
    NSArray *keysFromDB = [snapshot allKeys];
    NSMutableArray *stringKeys = [NSMutableArray arrayWithCapacity:3];
    [keysFromDB enumerateObjectsUsingBlock:^(NSData *obj, NSUInteger idx, BOOL *stop) {
        NSString *stringKey = [[NSString alloc] initWithBytes:obj.bytes length:obj.length encoding:NSUTF8StringEncoding];
        [stringKeys addObject:stringKey];
    }];
    XCTAssertEqualObjects(stringKeys, keys, @"-[LevelDB allKeys] should return the list of keys used to insert data");
    
    snapshot = [db newSnapshot];
    XCTAssertEqual([snapshot allKeys], @[],
                   @"The list of keys should be empty after removing all objects from the database");
}

- (void)testDictionaryManipulations {
    NSDictionary *objects = @{
                              @"key1": @[@1, @2],
                              @"key2": @{@"foo": @"bar"},
                              @"key3": @[@{}]
                              };
    [db addEntriesFromDictionary:objects];
    NSArray *keys = @[@"key1", @"key2", @"key3"];
    
    snapshot = [db newSnapshot];
    [db removeAllObjects];
    
    for (id key in keys)
        XCTAssertEqualObjects(snapshot[key], objects[key],
                              @"Objects should match between dictionary and db");
    
    keys = @[@"key1", @"key2", @"key9"];
    NSDictionary *extractedObjects = [NSDictionary dictionaryWithObjects:[snapshot objectsForKeys:keys
                                                                                   notFoundMarker:[NSNull null]]
                                                                 forKeys:keys];
    for (id key in keys) {
        id val;
        XCTAssertEqualObjects(extractedObjects[key],
                              (val = [objects objectForKey:key]) ? val : [NSNull null],
                              @"Objects should match between dictionary and db, or return the noFoundMarker");
    }
}

- (void)testPredicateFiltering {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"price BETWEEN {25, 50}"];
    NSMutableArray *resultKeys = [NSMutableArray array];
    
    NSUInteger *keyDataPtr = malloc(sizeof(NSUInteger));
    NSInteger price;
    
    NSComparator dataComparator = ^ NSComparisonResult (NSData *key1, NSData *key2) {
        int cmp = memcmp(key1.bytes, key2.bytes, MIN(key1.length, key2.length));
        
        if (cmp == 0)
            return NSOrderedSame;
        else if (cmp > 0)
            return NSOrderedDescending;
        else
            return NSOrderedAscending;
    };
    
    arc4random_stir();
    for (int i=0; i<numberOfIterations; i++) {
        *keyDataPtr = i;
        NSData *keyData = [NSData dataWithBytes:keyDataPtr
                                         length:sizeof(NSUInteger)];
        
        price = arc4random_uniform(100);
        if (price >= 25 && price <= 50) {
            [resultKeys addObject:keyData];
        }
        [db setObject:@{@"price": @(price)} forKey:keyData];
    }
    [resultKeys sortUsingComparator:dataComparator];
    snapshot = [db newSnapshot];
    [db removeAllObjects];
    
    XCTAssertEqualObjects([snapshot keysByFilteringWithPredicate:predicate],
                          resultKeys,
                          @"Filtering db keys with a predicate should return the same list as expected");
    
    NSDictionary *allObjects = [snapshot dictionaryByFilteringWithPredicate:predicate];
    XCTAssertEqualObjects([[allObjects allKeys] sortedArrayUsingComparator:dataComparator],
                          resultKeys,
                          @"A dictionary obtained by filtering with a predicate should yield the expected list of keys");
    
    __block int i = 0;
    [snapshot enumerateKeysBackward:NO
                startingAtKey:nil
          filteredByPredicate:predicate
                    andPrefix:nil
                   usingBlock:^(LevelDBKey *key, BOOL *stop) {
                       XCTAssertEqualObjects(NSDataFromLevelDBKey(key), resultKeys[i],
                                             @"Enumerating by filtering with a predicate should yield the expected keys");
                       i++;
                   }];
    
    i = (int)resultKeys.count - 1;
    [snapshot enumerateKeysBackward:YES
                startingAtKey:nil
          filteredByPredicate:predicate
                    andPrefix:nil
                   usingBlock:^(LevelDBKey *key, BOOL *stop) {
                       XCTAssertEqualObjects(NSDataFromLevelDBKey(key), resultKeys[i],
                                             @"Enumerating backwards by filtering with a predicate should yield the expected keys");
                       i--;
                   }];
    
    i = 0;
    [snapshot enumerateKeysAndObjectsBackward:NO lazily:NO
                          startingAtKey:nil
                    filteredByPredicate:predicate
                              andPrefix:nil
                             usingBlock:^(LevelDBKey *key, id value, BOOL *stop) {
                                 XCTAssertEqualObjects(NSDataFromLevelDBKey(key), resultKeys[i],
                                                       @"Enumerating keys and objects by filtering with a predicate should yield the expected keys");
                                 XCTAssertEqualObjects(value, allObjects[resultKeys[i]],
                                                       @"Enumerating keys and objects by filtering with a predicate should yield the expected values");
                                 i++;
                             }];
    
    i = (int)resultKeys.count - 1;
    [snapshot enumerateKeysAndObjectsBackward:YES lazily:NO
                          startingAtKey:nil
                    filteredByPredicate:predicate
                              andPrefix:nil
                             usingBlock:^(LevelDBKey *key, id value, BOOL *stop) {
                                 XCTAssertEqualObjects(NSDataFromLevelDBKey(key), resultKeys[i],
                                                       @"Enumerating keys and objects by filtering with a predicate should yield the expected keys");
                                 XCTAssertEqualObjects(value, allObjects[resultKeys[i]],
                                                       @"Enumerating keys and objects by filtering with a predicate should yield the expected values");
                                 i--;
                             }];
}

- (void)testForwardKeyEnumerations {
    __block NSInteger r;
    __block NSString *key;
    __block NSArray *value;
    
    NSArray *pairs = [self nPairs:numberOfIterations];
    
    snapshot = [db newSnapshot];
    [db removeAllObjects];
    
    // Test that enumerating the whole set yields keys in the correct orders
    r = 0;
    [snapshot enumerateKeysUsingBlock:^(LevelDBKey *lkey, BOOL *stop) {
        NSArray *pair = pairs[r];
        key = pair[0];
        value = pair[1];
        
        XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                              @"Keys should be equal, given the ordering worked");
        r++;
    }];
    
    // Test that enumerating the set by starting at an offset yields keys in the correct orders
    r = 432;
    [snapshot enumerateKeysBackward:NO
                startingAtKey:pairs[r][0]
          filteredByPredicate:nil
                    andPrefix:nil
                   usingBlock:^(LevelDBKey *lkey, BOOL *stop) {
                       NSArray *pair = pairs[r];
                       key = pair[0];
                       value = pair[1];
                       
                       XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                                             @"Keys should be equal, given the ordering worked");
                       r++;
                   }];
}

- (void)testBackwardKeyEnumerations {
    __block NSInteger r;
    __block NSString *key;
    __block NSArray *value;
    
    NSArray *pairs = [self nPairs:numberOfIterations];
    
    snapshot = [db newSnapshot];
    [db removeAllObjects];
    
    // Test that enumerating the whole set backwards yields keys in the correct orders
    r = [pairs count] - 1;
    [snapshot enumerateKeysBackward:YES
                startingAtKey:nil
          filteredByPredicate:nil
                    andPrefix:nil
                   usingBlock:^(LevelDBKey *lkey, BOOL *stop) {
                       NSArray *pair = pairs[r];
                       key = pair[0];
                       value = pair[1];
                       XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                                             @"Keys should be equal, given the ordering worked");
                       r--;
                   }];
    
    // Test that enumerating the set backwards at an offset yields keys in the correct orders
    r = 567;
    [snapshot enumerateKeysBackward:YES
                startingAtKey:pairs[r][0]
          filteredByPredicate:nil
                    andPrefix:nil
                   usingBlock:^(LevelDBKey *lkey, BOOL *stop) {
                       NSArray *pair = pairs[r];
                       key = pair[0];
                       value = pair[1];
                       XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                                             @"Keys should be equal, given the ordering worked");
                       r--;
                   }];
    
}

- (void)testForwardKeyAndValueEnumerations {
    __block NSInteger r;
    __block NSString *key;
    __block NSArray *value;
    
    NSArray *pairs = [self nPairs:numberOfIterations];
    // Test that enumerating the whole set yields pairs in the correct orders
    r = 0;
    
    snapshot = [db newSnapshot];
    [db removeAllObjects];
    
    [snapshot enumerateKeysAndObjectsUsingBlock:^(LevelDBKey *lkey, id _value, BOOL *stop) {
        NSArray *pair = pairs[r];
        key = pair[0];
        value = pair[1];
        
        XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                              @"Keys should be equal, given the ordering worked");
        XCTAssertEqualObjects(_value, value,
                              @"Values should be equal, given the ordering worked");
        r++;
    }];
    
    // Test that enumerating the set by starting at an offset yields pairs in the correct orders
    r = 432;
    [snapshot enumerateKeysAndObjectsBackward:NO lazily:NO
                          startingAtKey:pairs[r][0]
                    filteredByPredicate:nil
                              andPrefix:nil
                             usingBlock:^(LevelDBKey *lkey, id _value, BOOL *stop) {
                                 NSArray *pair = pairs[r];
                                 key = pair[0];
                                 value = pair[1];
                                 
                                 XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                                                       @"Keys should be equal, given the ordering worked");
                                 XCTAssertEqualObjects(_value, value,
                                                       @"Values should be equal, given the ordering worked");
                                 r++;
                             }];
}

- (void)testBackwardKeyAndValueEnumerations {
    __block NSInteger r;
    __block NSString *key;
    __block NSArray *value;
    
    NSArray *pairs = [self nPairs:numberOfIterations];
    
    snapshot = [db newSnapshot];
    [db removeAllObjects];
    
    // Test that enumerating the whole set backwards yields pairs in the correct orders
    r = [pairs count] - 1;
    [snapshot enumerateKeysAndObjectsBackward:YES lazily:NO
                          startingAtKey:nil
                    filteredByPredicate:nil
                              andPrefix:nil
                             usingBlock:^(LevelDBKey *lkey, id _value, BOOL *stop) {
                                 NSArray *pair = pairs[r];
                                 key = pair[0];
                                 value = pair[1];
                                 XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                                                       @"Keys should be equal, given the ordering worked");
                                 XCTAssertEqualObjects(_value, value,
                                                       @"Values should be equal, given the ordering worked");
                                 r--;
                             }];
    
    // Test that enumerating the set backwards at an offset yields pairs in the correct orders
    r = 567;
    [snapshot enumerateKeysAndObjectsBackward:YES lazily:NO
                          startingAtKey:pairs[r][0]
                    filteredByPredicate:nil
                              andPrefix:nil
                             usingBlock:^(LevelDBKey *lkey, id _value, BOOL *stop) {
                                 NSArray *pair = pairs[r];
                                 key = pair[0];
                                 value = pair[1];
                                 XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                                                       @"Keys should be equal, given the ordering worked");
                                 XCTAssertEqualObjects(_value, value,
                                                       @"Values should be equal, given the ordering worked");
                                 r--;
                             }];
}

- (void)testBackwardLazyKeyAndValueEnumerations {
    __block NSInteger r;
    __block NSString *key;
    __block NSArray *value;
    
    NSArray *pairs = [self nPairs:numberOfIterations];
    // Test that enumerating the set backwards and lazily at an offset yields pairs in the correct orders
    r = 567;
    
    snapshot = [db newSnapshot];
    [db removeAllObjects];
    
    [snapshot enumerateKeysAndObjectsBackward:YES lazily:YES
                          startingAtKey:pairs[r][0]
                    filteredByPredicate:nil
                              andPrefix:nil
                             usingBlock:^(LevelDBKey *lkey, LevelDBValueGetterBlock getter, BOOL *stop) {
                                 NSArray *pair = pairs[r];
                                 key = pair[0];
                                 value = pair[1];
                                 XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                                                       @"Keys should be equal, given the ordering worked");
                                 XCTAssertEqualObjects(getter(), value,
                                                       @"Values should be equal, given the ordering worked");
                                 r--;
                             }];
    
    [db removeAllObjects];
}

@end