//
//  WriteBatch.h
//
//  Copyright 2013 Storm Labs. 
//  See LICENCE for details.
//

#import <Foundation/Foundation.h>
#import <leveldb/db.h>
#import <leveldb/write_batch.h>
#import "LevelDB.h"

@interface Writebatch : NSObject {
    leveldb::WriteBatch _writeBatch;
}

@property (readonly) leveldb::WriteBatch writeBatch;

+ (Writebatch *) writeBatchFromDB:(LevelDB *)db;

- (void) removeObjectForKey:(id)key;
- (void) removeObjectsForKeys:(NSArray *)keyArray;
- (void) removeAllObjects;

- (void) setObject:(id)value forKey:(id)key;
- (void) setValue:(id)value forKey:(NSString *)key;
- (void) addEntriesFromDictionary:(NSDictionary *)dictionary;

- (void) apply;

@end