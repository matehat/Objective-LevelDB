//
//  LevelDB.m
//  HackerNews
//
//  Created by Michael Hoisie on 9/23/11.
//  Copyright 2011 Pave Labs. All rights reserved.
//

#import "LevelDB.h"

#import <leveldb/db.h>
#import <leveldb/options.h>

using namespace leveldb;


@implementation LevelDB 

@synthesize path;

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
        self.path = path;
        Options options;
        options.create_if_missing = true;
        Status status = leveldb::DB::Open(options, [path UTF8String], &db);
        
        readOptions.fill_cache = false;
        writeOptions.sync = false;
        
        if(!status.ok()) {
            NSLog(@"Problem creating LevelDB database: %s", status.ToString().c_str());
        }
        
    }
    
    return self;
}

+(Slice) SliceFromObject:(id) object {
    NSMutableData *d = [[[NSMutableData alloc] init] autorelease];
    if ([(id)object isKindOfClass:[NSString class]]) {
        [d appendData:[(NSString *)object dataUsingEncoding:NSUTF8StringEncoding]];
    } else if ([(id)object isKindOfClass:[NSDictionary class]]) {
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:d];
        [archiver encodeObject:object forKey:@"dictionary"];
        [archiver finishEncoding];
        [archiver release];
    }
    
    return Slice((const char *)[d bytes], (size_t)[d length]);
}

+ (NSString *)libraryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

- (NSData *) getData:(NSString *)key {
    std::string v_string;
    
    Slice k = [LevelDB SliceFromObject:key];
    Status status = db->Get(readOptions, k, &v_string);
    
    if(!status.ok()) {
        if(!status.IsNotFound())
            NSLog(@"Problem retrieving value for key '%@' from database: %s", key, status.ToString().c_str());
        return nil;
    }
    
    
    Slice v = v_string;
    return [NSData dataWithBytes:v.data() length:v.size()];
}

- (NSString *) getString:(NSString *)key {
    NSData *data = [self getData:key];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSDictionary *) getDictionary:(NSString *)key {
    NSData *data = [self getData:key];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    NSDictionary *dictionary = [[unarchiver decodeObjectForKey:@"dictionary"] retain];
    [unarchiver finishDecoding];
    [unarchiver release];
    return dictionary;
}

- (void) setObject:(NSString *)value forKey:(NSString *)key {
    Slice k = [LevelDB SliceFromObject:key];
    Slice v = [LevelDB SliceFromObject:value];
    Status status = db->Put(writeOptions, k, v);
    
    if(!status.ok())
    {
        NSLog(@"Problem storing key/value pair in database: %s", status.ToString().c_str());
    }

    return (BOOL)status.ok();
}

@end
