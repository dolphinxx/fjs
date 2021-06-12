# Flutter JS plugin

A Flutter plugin brings JavaScript Engine to your App.

This plugin uses *dart:ffi* to communicate between Flutter and C to reduce performance loss.

We uses [QuickJS](https://bellard.org/quickjs/) for Android/Windows/Linux and JavaScriptCore for iOS/MacOS. 

On Apple devices, it is prohibited to ship mobile applications that run JavaScript using a different JIT engine than the one originally provided with the system. Thus we have no choise other than using JavascriptCore.

## License

FlutterJS is under the [BSD 3-clause license](https://opensource.org/licenses/BSD-3-Clause) as recommended by [dart.dev](https://dart.dev/tools/pub/publishing)

[QuickJS](https://bellard.org/quickjs/) is under the [MIT license](https://opensource.org/licenses/MIT)

## Thanks To

This plugin borrowed a lot of code from the following awesome projects:

- [flutter_jscore](https://github.com/xuelongqy/flutter_jscore.git)

- [flutter_qjs](https://github.com/ekibun/flutter_qjs)

- [flutter_js](https://github.com/abner/flutter_js.git)

- [quickjs-emscripten](https://github.com/justjake/quickjs-emscripten.git)