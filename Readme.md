### Introduction

A feature-complete Objective-C wrapper for [Google's LevelDB](http://code.google.com/p/leveldb), a fast key-value store written by Google.

### Instructions

1. Drag all `.h` and `.mm` files into your project.
2. Clone [Google's leveldb](http://code.google.com/p/leveldb/source/checkout), preferably as a submodule of your project
3. In the leveldb library source directory, run `make PLATFORM=IOS` to build the library file
4. Add libleveldb.a to your project as a dependency
5. Add the leveldb/include path to your header path

Although Google's leveldb library is written in C++, this wrapper was written in a way that you can import Objective-LevelDB into your Objective-C
project without worrying about turning your `.m` files into `.mm`.

### Examples

```objective-c
LevelDB *ldb = [LevelDB databaseInLibraryWithName:@"test.ldb"];
```

##### Custom Encoder/Decoder

```objective-c
ldb.encoder = ^ NSData * (LeveldBKey *key, id object) {
  // return some data, given an object
}
ldb.decoder = ^ id (LeveldBKey *key, NSData * data) {
  // return an object, given some data
}
```

#####  NSMutableDictionary-like API

```objective-c
[ldb setObject:@"laval" forKey:@"string_test"];
NSLog(@"String Value: %@", [ldb objectForKey:@"string_test"]);

[ldb setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"val1", @"key1", @"val2", @"key2", nil] forKey:@"dict_test"];
NSLog(@"Dictionary Value: %@", [ldb objectForKey:@"dict_test"]);
```

##### Enumeration

```objective-c
[self enumerateKeysAndObjectsUsingBlock:^(LevelDBKey *key, id value, BOOL *stop) {
    // This step is necessary since the key could be a string or raw data (use NSDataFromLevelDBKey in that case)
    NSString *keyString = NSStringFromLevelDBKey(key); // Assumes UTF-8 encoding
    // Do something clever
}];

// Start enumeration at a certain key
[self enumerateKeysAndObjectsUsingBlock:^(LevelDBKey *key, id value, BOOL *stop) {
    // Do something else clever
}
                          startingAtKey:key];
                          
// Filter with a NSPredicate instance
[self enumerateKeysAndObjectsUsingBlock:^(LevelDBKey *key, id value, BOOL *stop) {
    // Do something else clever, like really clever
}
                          startingAtKey:key
                  filteredWithPredicate:predicate];
```

##### Snapshots, NSDictionary-like API (immutable)
    
```objective-c
Snapshot *snap = [ldb getSnapshot];
[ldb removeObjectForKey:@"string_test"];

// These calls will reflect the state of ldb when the snapshot was taken
NSLog(@"String Value: %@", [snap objectForKey:@"string_test"]);
NSLog(@"Dictionary Value: %@", [ldb objectForKey:@"dict_test"]);

// Dispose (automatically done in dealloc)
[snap release];
```

##### Writebatches, a set of atomic updates

```objective-c
Writebatch *wb = [Writebatch writebatchFromDB:ldb];
[wb setObject:@{ @"foo" : @"bar" } forKey: @"another_test"];
[wb removeObjectForKey:@"dict_test"];

// Those changes aren't yet applied to ldb
// To apply them in batch, 
[wb apply];
```

##### LevelDB options

```objective-c
// The following values are the default
LevelDBOptions options = [LevelDB makeOptions];
options.createIfMissing = true;
options.errorIfExists   = false;
options.paranoidCheck   = false;
options.compression     = true;
options.filterPolicy    = 0;      // Size in bits per key, allocated for a bloom filter, used in testing presence of key
options.cacheSize       = 0;      // Size in bytes, allocated for a LRU cache used for speeding up lookups

// Then, you can provide it when initializing a db instance.
LevelDB *ldb = [LevelDB databaseInLibraryWithName:@"test.ldb" andOptions:options];
```

##### Per-request options

```objective-c
db.safe = true; // Make sure to data was actually written to disk before returning from write operations.
[ldb setObject:@"laval" forKey:@"string_test"];
[ldb setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"val1", @"key1", @"val2", @"key2", nil] forKey:@"dict_test"];
db.safe = false; // Switch back to default

db.useCache = false; // Do not use DB cache when reading data (default to true);
```

### License

Distributed under the MIT license