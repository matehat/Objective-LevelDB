//
//  LDBWritebatch.m
//  Objective-LevelDB Tests
//
//  Created by Mathieu D'Amours on 11/14/13.
//
//

#import <Objective-LevelDB/LDBWriteBatch.h>
#import "BaseTestClass.h"

@interface WritebatchTests : BaseTestClass

@end

@implementation WritebatchTests

- (void) testDatabaseIntegrity {
    LDBWritebatch *wb = [db newWritebatch];
    
    id key = @"dict1";
    id value = @{@"foo": @"bar"};
    [wb setObject:value forKey:key];
    XCTAssertNil([db objectForKey:@"dict1"],
                 @"An insertion operation on the writebatch alone should be reflected in the DB yet");
    
    [wb apply];
    XCTAssertEqualObjects([db objectForKey:key], value,
                          @"Applying the writebatch should reflect its changes in the DB");
    
    wb = [db newWritebatch];
    [wb removeObjectForKey:@"dict1"];
    XCTAssertEqualObjects([db objectForKey:key], value,
                          @"A delete operation on a writebatch alone should not be reflected in the DB yet");
    [wb apply];
    XCTAssertNil([db objectForKey:@"dict1"], @"A deleted key, once the writebatch is applied, should return nil");
    
    wb = nil;
}

- (void)testKeysManipulation {
    id value = @{@"foo": @"bar"};
    
    LDBWritebatch *wb = [db newWritebatch];
    
    [wb setObject:value forKey:@"dict1"];
    [wb setObject:value forKey:@"dict2"];
    [wb setObject:value forKey:@"dict3"];
    
    XCTAssertEqual([db allKeys], @[], @"The list of keys should be empty before applying the writebatch");
    [wb apply];
    
    wb = [db newWritebatch];
    [wb removeAllObjects];
    
    NSArray *keys = @[ @"dict1", @"dict2", @"dict3" ];
    NSArray *keysFromDB = [db allKeys];
    NSMutableArray *stringKeys = [NSMutableArray arrayWithCapacity:3];
    [keysFromDB enumerateObjectsUsingBlock:^(NSData *obj, NSUInteger idx, BOOL *stop) {
        NSString *stringKey = [[NSString alloc] initWithBytes:obj.bytes length:obj.length encoding:NSUTF8StringEncoding];
        [stringKeys addObject:stringKey];
    }];
    XCTAssertEqualObjects(stringKeys, keys, @"-[LevelDB allKeys] should return the list of keys used to insert data");
    
    [wb apply];
    XCTAssertEqual([db allKeys], @[], @"The list of keys should be empty after removing all objects from the database");
}

- (void)testDictionaryManipulations {
    NSDictionary *objects = @{
                              @"key1": @[@1, @2],
                              @"key2": @{@"foo": @"bar"},
                              @"key3": @[@{}]
                              };
    
    LDBWritebatch *wb = [db newWritebatch];
    [wb addEntriesFromDictionary:objects];
    NSArray *keys = @[@"key1", @"key2", @"key3"];
    
    XCTAssertEqual([db allKeys], @[], @"The list of keys should be empty before applying the writebatch");
    [wb apply];
    
    for (id key in keys)
        XCTAssertEqualObjects(db[key], objects[key],
                              @"Objects should match between dictionary and db");
}

@end
