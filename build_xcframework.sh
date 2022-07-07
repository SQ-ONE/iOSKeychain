if [ -d "build" ]; then
  rm -rf build
fi

if [-d "DerivedData"]; then
  rm -rf DerivedData
fi

# Build static library for simulators

xcodebuild build \
  -scheme Keychain \
  -derivedDataPath DerivedData \
  -arch x86_64 \
  -sdk iphonesimulator \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
mkdir -p build/simulators
cp -r DerivedData/Build/Products/Release-iphonesimulator/* build/simulators

# Build static library for devices

xcodebuild build \
  -scheme Keychain \
  -derivedDataPath DerivedData \
  -arch arm64 \
  -sdk iphoneos \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
mkdir -p build/devices
cp -r DerivedData/Build/Products/Release-iphoneos/* build/devices

# Create XCFramework for static library build variants

xcodebuild -create-xcframework \
    -library build/simulators/libKeychain.a \
    -library build/devices/libKeychain.a \
    -output Keychain.xcframework
