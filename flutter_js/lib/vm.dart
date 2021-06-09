import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/module.dart';

import 'promise.dart';
export 'promise.dart';
import 'types.dart';
export 'types.dart';

typedef ModuleResolver = JSValuePointer Function(Vm vm);

abstract class Vm {
  @protected
  @mustCallSuper
  void postConstruct() {
    _setupModuleResolver();
  }

  @mustCallSuper
  void dispose() {
    _moduleMap.values.forEach((element) => element.dispose());
    _moduleMap.clear();
  }

  Map<String, FlutterJSModule> _moduleMap = {};
  void _setupModuleResolver() {
    final requireFn = newFunction('require', (args, {thisObj}) {
      String moduleName = jsToDart(args[0]);
      if(!_moduleMap.containsKey(moduleName)) {
        return $undefined;
      }
      return _moduleMap[moduleName]!.resolve(this);
    });
    setProperty(global, 'require', requireFn);
  }

  /// Register a module to this vm, which can be `require`d later.
  ///
  /// Since the Vm is rarely reused(prefer to create a new vm for each eval call), the result of [module].`resolve` is not cached, which is different from NodeJS.
  ///
  /// If you do need to cache the result of `require` call, have a look at `module_loader_test.dart`.
  void registerModule(FlutterJSModule module) {
    _moduleMap[module.name] = module;
  }

  /// [`undefined`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/undefined)
  JSValuePointer get $undefined;

  /// [`null`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null)
  JSValuePointer get $null;

  /// [`true`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/true)
  JSValuePointer get $true;

  /// [`false`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/false)
  JSValuePointer get $false;

  /// [`global`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects)
  ///
  /// You can set properties to create global variables.
  JSValuePointer get global;

  /// A value indicates that the `this` object in a function call is undefined.
  ///
  /// In QuickJS it is the global `undefined`, while in JavaScriptCore it is `nullptr`.
  JSValuePointer get nullThis;

  /// Converts a Dart number into a QuickJS value.
  JSValuePointer newNumber(num value);

  /// Converts [value] into a Dart number.
  ///
  /// Returns `null` on error, otherwise a `number`.
  double? getNumber(JSValuePointer value);

  String getString(JSValuePointer value);

  JSValuePointer newString(String value);

  JSValuePointer newDate(int timestamp);

  /// Create a new JS [object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Object_initializer).
  ///
  /// [properties] can be used to initialize the properties of the created object.
  JSValuePointer newObject([Map? properties]);

  /// Create a new JS [array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array).
  ///
  /// Provide [elements] to initialize the created Array.
  JSValuePointer newArray([List<JSValuePointer>? elements]);

  /// Create a new JS [ArrayBuffer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer) using [value] as the underlying data.
  JSValuePointer newArrayBuffer(Uint8List value);

  /// Create a new JS [Error](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error).
  JSValuePointer newError(dynamic error);

  /// Create a new JS [Promise](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise).
  ///
  /// If a [future] is provided, it will be used to drive the `Promise`.
  /// That is: the `Promise` is fulfilled(resolved) when the [future] is `complete`d, and the `completeError` of the [future] results in the rejection of the `Promise`.
  ///
  /// You can still use your own `Future` to handle `Promise`.
  JSDeferredPromise newPromise([Future? future]);

  /// Convert a Dart [function] into a JS [Function](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function) value.
  ///
  /// [name] is only used to set the [name](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/name) of the created function.
  /// You will still need to set the function as a property of an object(eg: the globalThis) to be able to call it in JS.
  ///
  /// See [[JSToDartFunction]] for more details.
  JSValuePointer newFunction(String? name, JSToDartFunction function);

  /// Convert a Dart [function] into a JS constructor value.
  ///
  /// It is still a [Function](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function), but can be called via `new xx()`.
  JSValuePointer newConstructor(JSToDartFunction function);

  /// Set a property on a JSValue.
  void setProp(
      JSValuePointer obj, JSValueConstPointer key, JSValuePointer value);

  /// A wrapper of [setProp], which automatically converts [key] to JS value.
  ///
  /// **Note:** only `num`, `String` or JSValuePointer is acceptable for [key].
  void setProperty(JSValuePointer obj, dynamic key, JSValuePointer value);

  /// Get a property from a JSValue.
  JSValuePointer getProp(JSValuePointer obj, JSValueConstPointer key);

  /// A wrapper of [getProp], which automatically converts [key] to JS value.
  ///
  /// **Note:** only `num`, `String` or JSValuePointer is acceptable for [key].
  JSValuePointer getProperty(JSValuePointer obj, dynamic key);

  bool hasProp(JSValuePointer obj, JSValueConstPointer key);

  bool hasProperty(JSValuePointer obj, dynamic key);

  /// [`func.call(thisVal, ...args)`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/call).
  ///
  /// Call a JSValue as a function.
  ///
  /// Returns The result of the function call, or throws a JSError If the code threw.
  JSValuePointer callFunction(JSValuePointer func,
      [JSValuePointer? thisVal, List<JSValuePointer>? args]);

  /// Call a JS void function.
  ///
  /// [func] is not limited to actual `void`, it just ignores the result of the function call.
  void callVoidFunction(JSValuePointer func,
      [JSValuePointer? thisVal, List<JSValuePointer>? args]);

  /// Call a JS function as constructor
  JSValuePointer callConstructor(JSValuePointer constructor, [List<JSValuePointer>? args]);

  /// Like [`eval(code)`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval#Description).
  ///
  /// Evaluates the Javascript source `code` in the global scope of this VM.
  ///
  /// When working with async code in QuickJS, you many need to call `executePendingJobs`
  /// to execute callbacks pending after synchronous evaluation returns.
  ///
  /// Returns The last statement's value, or throws a JSError If the code threw.
  JSValuePointer evalCode(String code, {String? filename});

  /// Convert JS [value] to Dart value.
  ///
  /// **Note:** For `ArrayBuffer` value, the returned value is just a Pointer to the uint8_t* data hold by the js value.
  /// If you want to access the data after the `ArrayBuffer` is freed, you must clone it to somewhere else(such as `Uint8List.fromList(..)`).
  dynamic jsToDart(JSValuePointer value);

  /// If [value] is dart function, it must be able to cast to [JSToDartFunction].
  ///
  /// [value] must be able to be serialize to JSON through `jsonEncode` if it is not one of the supported types.
  JSValuePointer dartToJS(dynamic value);

  /// Call this function when you try to return to JS a JSValue that was not created by you.
  ///
  /// It is required by QuickJS. For JavaScriptCore, the function just return the [value].
  ///
  /// See the sample bellow:
  /// ```dart
  /// vm.newFunction('foo', (args, {thisObj}) {
  ///   // here you need to call dupRef to args[0] since it is not created by you.
  ///   return vm.dupRef(args[0]);
  /// });
  /// ```
  JSValuePointer dupRef(JSValuePointer value) {
    return value;
  }

  /// Start an event loop to call `executePendingJobs` every [ms].
  ///
  /// You only need to call it when you are running asynchronous code inside the QuickJS vm.
  ///
  /// The event loop keep alive until the vm disposed.
  /// It is safe calling this method multiple times.
  ///
  /// Calling this method when using JavaScriptCore has no effect.
  void startEventLoop([int ms = 50]) {
    // default do nothing.
  }

  /// Stop the running event loop.
  ///
  /// The event loop will stop when the vm disposed. For long living vm, you can stop it by calling this function.
  void stopEventLoop() {
    // default do nothing.
  }
}
