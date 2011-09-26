### Introduction

This is a simple wrapper for Google's LevelDB. LevelDB is a fast key-value store written by Google. 

### Instructions

1. Drag LevelDB.h and LevelDB.mm into your project. 
2. Clone [Google's leveldb](http://code.google.com/p/leveldb/source/checkout), preferably as a submodule of your project
3. In the leveldb library source directory, run `make PLATFORM=IOS` to build the library file
4. Add libleveldb.a to your project as a dependency
5. Add the leveldb/include path to your header path
6. Make sure any class that imports leveldb is a `.mm` file. LevelDB is written in C++, so it can only be included by an Objective-C++ file

### Example

    LevelDB *ldb = [LevelDB databaseInLibraryWithName:@"test.ldb"];

    //test string
    [ldb setObject:@"laval" forKey:@"string_test"];
    NSLog(@"String Value: %@", [ldb getString:@"string_test"]);

    //test dictionary
    [ldb setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"val1", @"key1", @"val2", @"key2", nil] forKey:@"dict_test"];
    NSLog(@"Dictionary Value: %@", [ldb getDictionary:@"dict_test"]);
    [super viewDidLoad];
    
### License

Distributed under the MIT license