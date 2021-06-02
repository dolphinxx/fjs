# Dart wrapper of `JavaScriptCore` and `QuickJS`

FlutterJS is a <b>Dart</b> wrapper of `JavaScriptCore`(for Mac/iOS) and `QuickJS`(for Android/Windows/Linux).
It is based on [abner/flutter_js](https://github.com/abner/flutter_js).

## Data types support and codecs

This plugin uses `ffi` to receive data from JavaScript and vice versa.

The following table shows how they are transferred:

| Dart                              | JavaScript    | JavaScript    | Dart                 |
| --------------------------------- | ------------- | ------------- | -------------------- |
| null                              | null          | null          | null                 |
| null                              | undefined     | undefined     | null                 |
| bool                              | boolean       | boolean       | bool                 |
| int                               | Number        | Number(int)   | int                  |
| double                            | Number        | Number(float) | double<sup>1</sup>   |
| DateTime<sup>2</sup>              | Number        | Date          | int<sup>3</sup>      |
| String                            | String        | String        | String               |
| TypedData&`List<int>`<sup>2</sup> | ArrayBuffer   | ArrayBuffer   | Uint8List            |
| List                              | Array         | Array         | List                 |
| Map                               | Object        | Object        | Map<String, dynamic> |
| Function                          | Function      | Function      | Function             |
| Future                            | Promise       | Promise       | Future               |
| Exception                         | Error         | Error         | JSError              |
| Error                             | Error         |               |                      |

**Note:**
1. JS `Number` values without fractional part are stored as `int` in QuickJS, and thus transferred to type `int` in Dart.
2. Since create a JS object through C is complex, so we use number here instead.
3. When `Vm.constructDate=true`, a Dart `DateTime` is constructed for JS `Date` value. 
3. Set `Vm.reserveUndefined=true` to store JS `undefined` as `DART_UNDEFINED`(a const Symbol)

**TODO:** Convert type `Error` in JavaScript to type `Error` in Dart. 

## Installation

Add `flutter_js` to your `pubspec.yaml` 

```yaml
dependencies:
  flutter_js: 0.1.0+0
```

### Android

Change the minimum Android sdk version to 21 (or higher) in your *android/app/build.gradle* file.

```
minSdkVersion 21
```

Merge the following proguard rules to your *android/app/proguard-rules.pro*

```
#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class de.prosiebensat1digital.** { *; }
``` 

### iOS

Minimal required iOS version is 9.

## Usage

## Evaluate JavaScript source code

```dart
jsRuntime.evaluate('console.log("Hello World!")');
```

## Call a JavaScript function

```dart
jsRuntime.callFunction(function, thisObj:thisObj, args:args);
```

## Add a native function to JavaScript

```dart
jsRuntime.bindNative('plus', (List args, {dynamic thisObj}) {
  return args[0] + args[1];
}, receiveThisObj: true);
```

```javascript
const result = plus(1, 2);
console.log(result);
// output: 3
```

**Tip:** `bindNative` supports async function, which returns a `Promise` to JavaScript.

## Run Tests

### Run tests for `QuickJS`

#### Windows

There is a prebuilt [quickjs_c_bridge.dll](../flutter_js_windows/windows/shared/quickjs_c_bridge.dll) in this project.

Create an environment variable `QUICKJS_TEST_PATH` and set its value to the absolute path of `quickjs_c_bridge.dll`.

The DynamicLibrary loader will use this path to load quickjs dll when in test mode.

### Run tests for `JavaScriptCore`

#### Mac

As mentioned [here](https://flutter.dev/docs/development/platform-integration/c-interop#platform-library),
you need to add `JavaScriptCore` library in Xcode.

#### Windows

In order to run `JavaScriptCore` on Windows, you need to setup a runnable `JavaScriptCore` in your `PATH`.

[jsvu](https://github.com/GoogleChromeLabs/jsvu) provides an easy way for this.

  Install `jsvu` and then run `jsvu` command to install `JavaScriptCore`, add the absolute path of `.jsvu\engines\javascriptcore` to your `PATH`

  Download [WebKitRequirements](https://github.com/WebKitForWindows/WebKitRequirements/releases) and add the absolute path of `WebKitRequirementsWin64\bin64` to your `PATH`.


