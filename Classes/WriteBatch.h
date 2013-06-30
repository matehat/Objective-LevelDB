//
//  WriteBatch.h
//
//  Copyright 2013 Storm Labs. 
//  See LICENCE for details.
//

#import <Foundation/Foundation.h>

#import "LevelDB.h"

@interface Writebatch : NSObject

@property (nonatomic, assign) id db;

+ (instancetype) writeBatchFromDB:(id)db;

- (void) removeObjectForKey:(id)key;
- (void) removeObjectsForKeys:(NSArray *)keyArray;
- (void) removeAllObjects;

- (void) setData:(NSData *)data forKey:(id)key;
- (void) setObject:(id)value forKey:(id)key;
- (void) setValue:(id)value forKey:(NSString *)key;
- (void) addEntriesFromDictionary:(NSDictionary *)dictionary;

- (void) apply;

@end