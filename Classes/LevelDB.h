//
//  LevelDB.h
//  HackerNews
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
- (NSString *) getString:(NSString *)key;
- (void) setObject:(NSString *)value forKey:(NSString *)key;

@end
