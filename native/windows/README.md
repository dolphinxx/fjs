# Windows

Generates shared binaries libraries to be consumed by flutter_js on desktop platforms.

## Build

### Prebuild

Go to windows directory, run `prebuild.bat`

### Creating Ninja Structure

Run in Developer Command Prompt for VS2019 in this project rootFolder:

First, prepare to target x64:

```bash
"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
```

Now generate the Ninja project:

#### Release

```bash
cmake -S . -B .\build -DCMAKE_BUILD_TYPE=Release -G "Ninja"
```

#### Debug

```bash
cmake -S . -B .\build -G "Ninja"
```

### Compile

Now compile using the ninja project generated:

```bash
cmake --build .\build
```
