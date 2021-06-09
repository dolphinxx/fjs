# Android

Works for both Windows 10 and WSL

Need to set the environment variable `ANDROID_NDK` to NDK root directory, eg: `C:\devtools\android-sdk-windows\ndk-bundle`

## Build with Gradle

```cmd
.\gradlew build
```

## Build without Gradle

Build arm64-v8a abi

```cmd
cmake -DCMAKE_TOOLCHAIN_FILE="${env:ANDROID_NDK}/build/cmake/android.toolchain.cmake" -G Ninja -DANDROID_NDK="${env:ANDROID_NDK}" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-29 -DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_static -DCMAKE_LIBRARY_OUTPUT_DIRECTORY=libs -S . -B libs/arm64-v8a
cmake --build libs/arm64-v8a
```

And build other abi libraries by your self.