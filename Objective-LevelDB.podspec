Pod::Spec.new do |s|
  s.name         =  'Objective-LevelDB'
  s.version      =  '0.1.0'
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.6'
  s.license      =  'MIT'
  s.summary      =  'A NSMutableDictionary-like wrapper for LevelDB in Objective-C.'
  s.description  =  'This is a simple wrapper for Google\'s LevelDB. LevelDB is a fast key-value store written by Google. This is a forked version for updated leveldb and XCode after 4.2.'
  s.homepage     =  'https://github.com/matehat/Objective-LevelDB'
  s.author       =  'Michael Hoisie'
  s.source       =  { :git => 'https://github.com/matehat/Objective-LevelDB.git', :submodules => true }
  s.source_files =  'Classes/*.{h,m,mm}'
  s.library      =  'leveldb'
 
  s.public_header_files   =  'Classes/levelDB.h'
  s.preserve_paths = 'leveldb-library'

  s.xcconfig = {
      'LIBRARY_SEARCH_PATHS'    => '"$(PODS_ROOT)/Objective-LevelDB/leveldb-library"',
      'HEADER_SEARCH_PATHS'     => '"$(PODS_ROOT)/Objective-LevelDB/leveldb-library/include"',
      'OTHER_LDFLAGS'           => '-lstdc++'
  }
 
  def s.pre_install(pod, target_definition)
    Dir.chdir(pod.root + 'leveldb-library') do
      # build static library
      `make PLATFORM=IOS CC=clang CXX=clang++ libleveldb.a`
    end
  end
end