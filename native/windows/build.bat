@echo off

cd /D "%~dp0"

echo "Setup MSVC env..."
call "D:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x64

echo "Copy source files to build..."
call prebuild.bat

echo "Building..."
cmake -S . -B .\build -DCMAKE_BUILD_TYPE=Release -G "Ninja"

cmake --build .\build

echo "Press any key to exit . . ."
pause>nul