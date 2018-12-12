Pod::Spec.new do |s|
  s.name         =  'Objective-LevelDB'
  s.version      =  '2.1.5'
  s.license      =  'MIT'
  s.summary      =  'A feature-complete wrapper for LevelDB in Objective-C.'
  s.description  =  'This is a feature-complete wrapper for Google\'s LevelDB. LevelDB is a fast key-value store written by Google.'
  s.homepage     =  'https://github.com/matehat/Objective-LevelDB'
  s.authors      =  'Michael Hoisie', 'Mathieu D\'Amours'

  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'

  s.source       =  { :git => 'https://github.com/matehat/Objective-LevelDB.git', :tag => s.version.to_s, :submodules => true }

  s.source_files = 'Classes/*.{h,m,mm}'
  s.dependency "leveldb-library"
  s.requires_arc = false
end
