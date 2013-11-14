//
//  BaseTestClass.h
//  Objective-LevelDB Tests
//
//  Created by Mathieu D'Amours on 11/14/13.
//
//

#import <LevelDB.h>
#import <XCTest/XCTest.h>

extern dispatch_queue_t lvldb_test_queue;

@interface BaseTestClass : XCTestCase {
    LevelDB *db;
}

@end

