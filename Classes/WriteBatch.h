//
//  WriteBatch.h
//
//  Copyright 2013 Storm Labs. 
//  See LICENCE for details.
//

#import <Foundation/Foundation.h>
#import "LevelDB.h"

@interface Writebatch : NSObject

+ (Writebatch *) writeBatchFromDB:(LevelDB *)db;

- (void) removeObjectForKey:(id)key;
- (void) removeObjectsForKeys:(NSArray *)keyArray;
- (void) removeAllObjects;

- (void) setObject:(id)value forKey:(id)key;
- (void) setValue:(id)value forKey:(NSString *)key;
- (void) addEntriesFromDictionary:(NSDictionary *)dictionary;

- (leveldb::WriteBatch) getWriteBatch;
- (void) apply;

@end