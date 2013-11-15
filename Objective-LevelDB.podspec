Pod::Spec.new do |s|
  s.name         =  'Objective-LevelDB'
  s.version      =  '2.0.0'
  s.license      =  'MIT'
  s.summary      =  'A feature-complete wrapper for LevelDB in Objective-C.'
  s.description  =  'This is a feature-complete wrapper for Google\'s LevelDB. LevelDB is a fast key-value store written by Google.'
  s.homepage     =  'https://github.com/matehat/Objective-LevelDB'
  s.authors      =  'Michael Hoisie', 'Mathieu D\'Amours'
  
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
  
  s.source       =  { :git => 'https://github.com/matehat/Objective-LevelDB.git', :tag => 'v2.0.0', :submodules => true }
  s.source_files =  'Classes/*.{h,m,mm}'
  s.library      =  'leveldb'
  
  s.preserve_paths = 'leveldb-library'
  s.xcconfig = {
      'LIBRARY_SEARCH_PATHS'    => '"$(PODS_ROOT)/Objective-LevelDB/leveldb-library"',
      'HEADER_SEARCH_PATHS'     => '"$(PODS_ROOT)/Objective-LevelDB/leveldb-library/include"',
      'CC'                      => 'clang',
      'CXX'                     => 'clang++'
  }
 
  s.pre_install do |pod, target_definition|
    Dir.chdir(pod.root + 'leveldb-library') do
      # build static library for iOS
      `make PLATFORM=IOS CC=clang CXX=clang++ libleveldb.a`
      
      # If you want it to work for OS X instead, go in leveldb-library subfolder, and do the following
      # make clean
      # make CC=clang CXX=clang++
    end
  end
end
