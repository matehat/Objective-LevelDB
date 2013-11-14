//
//  iOS_Tests.m
//  iOS Tests
//
//  Created by Mathieu D'Amours on 11/13/13.
//
//

#import <XCTest/XCTest.h>
#import <LevelDB.h>

@interface iOS_Tests : XCTestCase

@end

@implementation iOS_Tests {
    LevelDB *db;
}

static int db_i = 0;
static dispatch_queue_t queue;

+ (void)setUp {
    queue = dispatch_queue_create("Create DB", DISPATCH_QUEUE_SERIAL);
}

- (void)setUp {
    dispatch_sync(queue, ^{
        db = [LevelDB databaseInLibraryWithName:[NSString stringWithFormat:@"TestDB%d", db_i]];
        db_i++;
    });
    [db removeAllObjects];
    
    db.encoder = ^ NSData * (LevelDBKey *key, id value) {
        return [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
    };
    db.decoder = ^ id (LevelDBKey *key, NSData *data) {
        return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    };
}

- (void)tearDown {
    [db close];
    [db deleteDatabaseFromDisk];
}

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

- (void)testPredicate {
    
}

- (NSArray *)pairs {
    NSMutableArray  *pairs = [NSMutableArray array];
    
    __block NSInteger r;
    __block NSString *key;
    __block NSArray *value;
    
    dispatch_apply(1000, queue, ^(size_t i) {
        do {
            r = arc4random_uniform(5000);
            key = [NSString stringWithFormat:@"%d", r];
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
    
    NSArray *pairs = [self pairs];
    
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
                 withSnapshot:nil
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
    
    NSArray *pairs = [self pairs];
    
    // Test that enumerating the whole set backwards yields keys in the correct orders
    r = [pairs count] - 1;
    [db enumerateKeysBackward:YES
                startingAtKey:nil
          filteredByPredicate:nil
                    andPrefix:nil
                 withSnapshot:nil
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
                 withSnapshot:nil
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
    
    NSArray *pairs = [self pairs];
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
                           withSnapshot:nil
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
    
    NSArray *pairs = [self pairs];
    // Test that enumerating the whole set backwards yields pairs in the correct orders
    r = [pairs count] - 1;
    [db enumerateKeysAndObjectsBackward:YES lazily:NO
                          startingAtKey:nil
                    filteredByPredicate:nil
                              andPrefix:nil
                           withSnapshot:nil
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
                           withSnapshot:nil
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
    
    NSArray *pairs = [self pairs];
    // Test that enumerating the set backwards and lazily at an offset yields pairs in the correct orders
    r = 567;
    [db enumerateKeysAndObjectsBackward:YES lazily:YES
                          startingAtKey:pairs[r][0]
                    filteredByPredicate:nil
                              andPrefix:nil
                           withSnapshot:nil
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
