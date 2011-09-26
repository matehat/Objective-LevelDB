//
//  LevelDB.h
//
//  Created by Michael Hoisie on 9/23/11.
//  Copyright 2011 Pave Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "leveldb/db.h"

using namespace leveldb;

@interface LevelDB : NSObject {
    DB *db;
    ReadOptions readOptions;
    WriteOptions writeOptions;
}

@property (nonatomic, retain) NSString *path;

+ (NSString *)libraryPath;
- (id) initWithPath:(NSString *)path;

- (void) setObject:(NSString *)value forKey:(NSString *)key;
- (id) getObject:(NSString *)key;
- (NSString *) getString:(NSString *)key;
- (NSDictionary *) getDictionary:(NSString *)key;
- (NSArray *) getArray:(NSString *)key;

@end
