ROOT=$(pwd)

cd Tests
rm -fR Pods
pod install && rm -fR Pods/Objective-LevelDB/Classes

cd ..
ln -nfs $ROOT $ROOT/Tests/Pods/Objective-LevelDB
