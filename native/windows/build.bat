@echo off

cd /D "%~dp0"

echo "Setup MSVC env..."
call "D:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x64

echo "Copy source files to build..."

if exist .\build\ rmdir .\build\ /s /q
if not exist .\build\ mkdir build
for %%f in (Makefile,VERSION,cutils.c,cutils.h,libbf.c,libbf.h,libregexp-opcode.h,libregexp.c,libregexp.h,libunicode-table.h,libunicode.c,libunicode.h,list.h,qjs.c,qjsc.c,quickjs-atom.h,quickjs-libc.c,quickjs-libc.h,quickjs-opcode.h,quickjs.c,quickjs.h,unicode_gen.c,unicode_gen_def.h) do xcopy /s /i ..\src\quickjs\%%f .\build\ /Y
for %%f in (interface.cpp,quickjs.def) do xcopy /s /i ..\src\%%f .\build\ /Y
for %%f in (cutils.h,quickjs.c,quickjs.h) do xcopy /s /i ..\src\patch\%%f .\build\ /Y

echo "Building..."
cmake -S . -B .\build -DCMAKE_BUILD_TYPE=Release -G "Ninja"

cmake --build .\build

echo "Press any key to exit . . ."
pause>nul