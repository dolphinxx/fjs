# Flutter JS plugin

A Flutter plugin brings JavaScript Engine to your App.

This plugin uses *dart:ffi* to communicate between Flutter and C to reduce performance loss.

We uses [QuickJS](https://bellard.org/quickjs/) for Android/Windows/Linux and JavaScriptCore for iOS/MacOS. 

On Apple devices, it is prohibited to ship mobile applications that run JavaScript using a different JIT engine than the one originally provided with the system. Thus we have no choise other than using JavascriptCore.

We use QuickJS for other platforms, since it has several obvious benefits:

1. Much smaller bundle size.
2. Competitive performance advantage.
3. Free control of exposing C api.
4. Consist behavior on various devices.
5. In time sync with official version.



## Features:

### Evaluate JavaScript code

```dart
Context ctx = getJavaScriptContext();
String result = ctx.eval(r'Hello Flutter!')
  .consume((value) => ctx.jsToDart(value));
print(result);// Hello Flutter!
ctx.dispose();
```

### Call JavaScript function

```dart
Context ctx = getJavaScriptContext();
// TODO:
```


## Thanks To

This plugin borrowed a lot of code from the following awesome projects:

- [flutter_jscore](https://github.com/xuelongqy/flutter_jscore.git)

- [flutter_qjs](https://github.com/ekibun/flutter_qjs)

- [flutter_js](https://github.com/abner/flutter_js.git)

- [quickjs-emscripten](https://github.com/justjake/quickjs-emscripten.git)