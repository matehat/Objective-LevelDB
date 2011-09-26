//
//  LevelDB.m
//
//  Created by Michael Hoisie on 9/23/11.
//  Copyright 2011 Pave Labs. All rights reserved.
//

#import "LevelDB.h"

#import <leveldb/db.h>
#import <leveldb/options.h>

#define SliceFromString(_string_) (Slice((char *)[_string_ UTF8String], [_string_ lengthOfBytesUsingEncoding:NSUTF8StringEncoding]))
#define StringFromSlice(_slice_) ([[[NSString alloc] initWithBytes:_slice_.data() length:_slice_.size() encoding:NSUTF8StringEncoding] autorelease])


using namespace leveldb;

static Slice SliceFromObject(id object) {
    NSMutableData *d = [[[NSMutableData alloc] init] autorelease];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:d];
    [archiver encodeObject:object forKey:@"object"];
    [archiver finishEncoding];
    [archiver release];
    return Slice((const char *)[d bytes], (size_t)[d length]);
}

static id ObjectFromSlice(Slice v) {
    NSData *data = [NSData dataWithBytes:v.data() length:v.size()];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    id object = [[unarchiver decodeObjectForKey:@"object"] retain];
    [unarchiver finishDecoding];
    [unarchiver release];
    return object;
}

@implementation LevelDB 

@synthesize path=_path;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (id) initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _path = path;
        Options options;
        options.create_if_missing = true;
        Status status = leveldb::DB::Open(options, [_path UTF8String], &db);
        
        readOptions.fill_cache = false;
        writeOptions.sync = false;
        
        if(!status.ok()) {
            NSLog(@"Problem creating LevelDB database: %s", status.ToString().c_str());
        }
        
    }
    
    return self;
}

+ (NSString *)libraryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

+ (LevelDB *)databaseInLibraryWithName:(NSString *)name {
    NSString *path = [[LevelDB libraryPath] stringByAppendingPathComponent:name];
    LevelDB *ldb = [[[LevelDB alloc] initWithPath:path] autorelease];
    return ldb;
}

- (void) setObject:(id)value forKey:(NSString *)key {
    Slice k = SliceFromString(key);
    Slice v = SliceFromObject(value);
    Status status = db->Put(writeOptions, k, v);
    
    if(!status.ok()) {
        NSLog(@"Problem storing key/value pair in database: %s", status.ToString().c_str());
    }
}

- (id) getObject:(NSString *)key {
    std::string v_string;
    
    Slice k = SliceFromString(key);
    Status status = db->Get(readOptions, k, &v_string);
    
    if(!status.ok()) {
        if(!status.IsNotFound())
            NSLog(@"Problem retrieving value for key '%@' from database: %s", key, status.ToString().c_str());
        return nil;
    }
    
    return ObjectFromSlice(v_string);
}

- (NSString *) getString:(NSString *)key {
    return (NSString *)[self getObject:key];
}

- (NSDictionary *) getDictionary:(NSString *)key {
    return (NSDictionary *)[self getObject:key];
}

- (NSArray *) getArray:(NSString *)key {
    return (NSArray *)[self getObject:key];
}

- (void)deleteObject:(NSString *)key {
    
    Slice k = SliceFromString(key);
    Status status = db->Delete(writeOptions, k);
    
    if(!status.ok()) {
        NSLog(@"Problem deleting key/value pair in database: %s", status.ToString().c_str());
    }
}

- (void) clear {
    NSArray *keys = [self allKeys];
    for (NSString *k in keys) {
        [self deleteObject:k];
    }
}

- (NSArray *)allKeys {
    NSMutableArray *keys = [[[NSMutableArray alloc] init] autorelease];
    //test iteration
    [self iterateKeys:^BOOL(NSString *key) {
        [keys addObject:key];
        return TRUE;
    }];
    return keys;
}

- (void) iterate:(KeyValueBlock)block {
    Iterator* iter = db->NewIterator(ReadOptions());
    for (iter->SeekToFirst(); iter->Valid(); iter->Next()) {
        Slice key = iter->key(), value = iter->value();
        NSString *k = StringFromSlice(key);
        id v = ObjectFromSlice(value);
        if (!block(k, v)) {
            break;
        }
    }

    delete iter;
}


- (void) iterateKeys:(KeyBlock)block {
    Iterator* iter = db->NewIterator(ReadOptions());
    for (iter->SeekToFirst(); iter->Valid(); iter->Next()) {
        Slice key = iter->key();
        NSString *k = StringFromSlice(key);
        if (!block(k)) {
            break;
        }
    }

    delete iter;
}

- (void) deleteDatabase {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    [fileManager removeItemAtPath:_path error:&error];
}

@end
