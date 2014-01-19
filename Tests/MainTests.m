//
//  iOS_Tests.m
//  iOS Tests
//
//  Created by Mathieu D'Amours on 11/13/13.
//
//

#import "BaseTestClass.h"

@interface MainTests : BaseTestClass

@end

static NSUInteger numberOfIterations = 2500;

@implementation MainTests

- (void)testDatabaseCreated {
    XCTAssertNotNil(db, @"Database should not be nil");
}

- (void)testContentIntegrity {
    id key = @"dict1";
    id value = @{@"foo": @"bar"};
    [db setObject:value forKey:key];
    XCTAssertEqualObjects([db objectForKey:key], value, @"Saving and retrieving should keep an dictionary intact");
    
    [db removeObjectForKey:@"dict1"];
    XCTAssertNil([db objectForKey:@"dict1"], @"A deleted key should return nil");
    
    value = @[@"foo", @"bar"];
    [db setObject:value forKey:key];
    XCTAssertEqualObjects([db objectForKey:key], value, @"Saving and retrieving should keep an array intact");
    
    [db removeObjectsForKeys:@[@"array1"]];
    XCTAssertNil([db objectForKey:@"array1"], @"A key that was deleted in batch should return nil");
}

- (void)testKeysManipulation {
    id value = @{@"foo": @"bar"};
    
    [db setObject:value forKey:@"dict1"];
    [db setObject:value forKey:@"dict2"];
    [db setObject:value forKey:@"dict3"];
    
    NSArray *keys = @[ @"dict1", @"dict2", @"dict3" ];
    NSArray *keysFromDB = [db allKeys];
    NSMutableArray *stringKeys = [NSMutableArray arrayWithCapacity:3];
    [keysFromDB enumerateObjectsUsingBlock:^(NSData *obj, NSUInteger idx, BOOL *stop) {
        NSString *stringKey = [[NSString alloc] initWithBytes:obj.bytes length:obj.length encoding:NSUTF8StringEncoding];
        [stringKeys addObject:stringKey];
    }];
    XCTAssertEqualObjects(stringKeys, keys, @"-[LevelDB allKeys] should return the list of keys used to insert data");
    
    [db removeAllObjects];
    XCTAssertEqual([db allKeys], @[], @"The list of keys should be empty after removing all objects from the database");
}

- (void)testRemovingKeysWithPrefix {
    id value = @{@"foo": @"bar"};
    [db setObject:value forKey:@"dict1"];
    [db setObject:value forKey:@"dict2"];
    [db setObject:value forKey:@"dict3"];
    [db setObject:@[@1,@2,@3] forKey:@"array1"];
    
    [db removeAllObjectsWithPrefix:@"dict"];
    XCTAssertEqual([[db allKeys] count], (NSUInteger)1,
                   @"There should be only 1 key remaining after removing all those prefixed with 'dict'");
}

- (void)testDictionaryManipulations {
    NSDictionary *objects = @{
        @"key1": @[@1, @2],
        @"key2": @{@"foo": @"bar"},
        @"key3": @[@{}]
    };
    [db addEntriesFromDictionary:objects];
    NSArray *keys = @[@"key1", @"key2", @"key3"];
    
    for (id key in keys)
        XCTAssertEqualObjects(db[key], objects[key],
                              @"Objects should match between dictionary and db");
    
    keys = @[@"key1", @"key2", @"key9"];
    NSDictionary *extractedObjects = [NSDictionary dictionaryWithObjects:[db objectsForKeys:keys
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
    
    XCTAssertEqualObjects([db keysByFilteringWithPredicate:predicate],
                          resultKeys,
                          @"Filtering db keys with a predicate should return the same list as expected");
    
    NSDictionary *allObjects = [db dictionaryByFilteringWithPredicate:predicate];
    XCTAssertEqualObjects([[allObjects allKeys] sortedArrayUsingComparator:dataComparator],
                          resultKeys,
                          @"A dictionary obtained by filtering with a predicate should yield the expected list of keys");
    
    __block int i = 0;
    [db enumerateKeysBackward:NO
                startingAtKey:nil
          filteredByPredicate:predicate
                    andPrefix:nil
                   usingBlock:^(LevelDBKey *key, BOOL *stop) {
                       XCTAssertEqualObjects(NSDataFromLevelDBKey(key), resultKeys[i],
                                             @"Enumerating by filtering with a predicate should yield the expected keys");
                       i++;
                   }];
    
    i = (int)resultKeys.count - 1;
    [db enumerateKeysBackward:YES
                startingAtKey:nil
          filteredByPredicate:predicate
                    andPrefix:nil
                   usingBlock:^(LevelDBKey *key, BOOL *stop) {
                       XCTAssertEqualObjects(NSDataFromLevelDBKey(key), resultKeys[i],
                                             @"Enumerating backwards by filtering with a predicate should yield the expected keys");
                       i--;
                   }];
    
    i = 0;
    [db enumerateKeysAndObjectsBackward:NO lazily:NO
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
    [db enumerateKeysAndObjectsBackward:YES lazily:NO
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

- (void)testForwardKeyEnumerations {
    __block NSInteger r;
    __block NSString *key;
    __block NSArray *value;
    
    NSArray *pairs = [self nPairs:numberOfIterations];
    
    // Test that enumerating the whole set yields keys in the correct orders
    r = 0;
    [db enumerateKeysUsingBlock:^(LevelDBKey *lkey, BOOL *stop) {
        NSArray *pair = pairs[r];
        key = pair[0];
        value = pair[1];
        
        XCTAssertEqualObjects(key, NSStringFromLevelDBKey(lkey),
                              @"Keys should be equal, given the ordering worked");
        r++;
    }];
    
    // Test that enumerating the set by starting at an offset yields keys in the correct orders
    r = 432;
    [db enumerateKeysBackward:NO
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
    
    // Test that enumerating the whole set backwards yields keys in the correct orders
    r = [pairs count] - 1;
    [db enumerateKeysBackward:YES
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
    [db enumerateKeysBackward:YES
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

- (void)testPrefixedEnumerations {
    id(^valueFor)(int) = ^ id (int i) { return @{ @"key": @(i) }; };
    NSDictionary *pairs = @{
                            @"tess:0": valueFor(0),
                            @"tesa:0": valueFor(0),
                            @"test:1": valueFor(1),
                            @"test:2": valueFor(2),
                            @"test:3": valueFor(3),
                            @"test:4": valueFor(4)
                            };
    
    __block int i = 4;
    [db addEntriesFromDictionary:pairs];
    [db enumerateKeysBackward:YES
                startingAtKey:nil
          filteredByPredicate:nil
                    andPrefix:@"test"
                   usingBlock:^(LevelDBKey *lkey, BOOL *stop) {
                       NSString *key = [NSString stringWithFormat:@"test:%d", i];
                       XCTAssertEqualObjects(NSStringFromLevelDBKey(lkey), key,
                                             @"Keys should be restricted to the prefixed region");
                       i--;
                   }];
    XCTAssertEqual(i, 0, @"");
    
    
    [db removeAllObjects];
    [db addEntriesFromDictionary:@{@"tess:0": valueFor(0),
                                   @"test:1": valueFor(1),
                                   @"test:2": valueFor(2),
                                   @"test:3": valueFor(3),
                                   @"test:4": valueFor(4),
                                   @"tesu:5": valueFor(5)}];
    i = 4;
    [db enumerateKeysAndObjectsBackward:YES
                                 lazily:NO
                          startingAtKey:nil
                    filteredByPredicate:nil
                              andPrefix:@"test"
                             usingBlock:^(LevelDBKey *lkey, NSDictionary *value, BOOL *stop) {
                                 NSString *key = [NSString stringWithFormat:@"test:%d", i];
                                 XCTAssertEqualObjects(NSStringFromLevelDBKey(lkey), key,
                                                       @"Keys should be restricted to the prefixed region");
                                 XCTAssertEqualObjects(value[@"key"], @(i),
                                                       @"Values should be restricted to the prefixed region");
                                 i--;
                             }];
    XCTAssertEqual(i, 0, @"");
    
    i = 1;
    [db addEntriesFromDictionary:pairs];
    [db enumerateKeysBackward:NO
                startingAtKey:nil
          filteredByPredicate:nil
                    andPrefix:@"test"
                   usingBlock:^(LevelDBKey *lkey, BOOL *stop) {
                       NSString *key = [NSString stringWithFormat:@"test:%d", i];
                       XCTAssertEqualObjects(NSStringFromLevelDBKey(lkey), key,
                                             @"Keys should be restricted to the prefixed region");
                       i++;
                   }];
    XCTAssertEqual(i, 5, @"");
    
    i = 1;
    [db enumerateKeysAndObjectsBackward:NO
                                 lazily:NO
                          startingAtKey:nil
                    filteredByPredicate:nil
                              andPrefix:@"test"
                             usingBlock:^(LevelDBKey *lkey, NSDictionary *value, BOOL *stop) {
                                 NSString *key = [NSString stringWithFormat:@"test:%d", i];
                                 XCTAssertEqualObjects(NSStringFromLevelDBKey(lkey), key,
                                                       @"Keys should be restricted to the prefixed region");
                                 XCTAssertEqualObjects(value[@"key"], @(i),
                                                       @"Values should be restricted to the prefixed region");
                                 i++;
                             }];
    XCTAssertEqual(i, 5, @"");
}

- (void)testForwardKeyAndValueEnumerations {
    __block NSInteger r;
    __block NSString *key;
    __block NSArray *value;
    
    NSArray *pairs = [self nPairs:numberOfIterations];
    // Test that enumerating the whole set yields pairs in the correct orders
    r = 0;
    [db enumerateKeysAndObjectsUsingBlock:^(LevelDBKey *lkey, id _value, BOOL *stop) {
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
    [db enumerateKeysAndObjectsBackward:NO lazily:NO
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
    // Test that enumerating the whole set backwards yields pairs in the correct orders
    r = [pairs count] - 1;
    [db enumerateKeysAndObjectsBackward:YES lazily:NO
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
    [db enumerateKeysAndObjectsBackward:YES lazily:NO
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
    [db enumerateKeysAndObjectsBackward:YES lazily:YES
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
