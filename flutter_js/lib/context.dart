import 'package:flutter/foundation.dart';

import 'types.dart';
import 'vm.dart';

abstract class JavaScriptContext {

  late JSValuePointer channelInstance;

  @protected
  void postCreate() {
  }

  @mustCallSuper
  void dispose() {
  }

  /// Evaluate a JS [code] and return the result.
  JSValuePointer eval(String code, {String? name});

  /// Call a JS function [fn] with [args] and [thisObject].
  ///
  /// **Note:** The caller has respond to free all the arguments, ie: [fn], [args], [thisObject].
  JSValuePointer callFunction(JSValuePointer fn,
      {List<JSValuePointer>? args, JSValuePointer? thisObject});

  /// Convert a JS value [jsValueRef] into dart value.
  dynamic jsToDart(JSValuePointer jsValueRef);

  /// Convert a dart value [val] into JS value.
  JSValuePointer dartToJS(dynamic val);

  /// Call this method when you are using asynchronous code inside the QuickJSVm.
  /// The number of executed pending jobs is returned.
  ///
  /// There is no event loop in QuickJS.
  /// You need to call this method to execute pending job of promises.
  ///
  /// **Note:** It is safe to call this method multiple times and calling this method on iOS(which uses JavaScriptCore) has no effect.
  ///
  int executePendingJob() {
    return 0;
  }

  /// Register a module with name [moduleName] to this context, and can be `require`d later.
  ///
  /// Since the Vm is rarely reused(prefer to create a new vm for each eval call), the result of ModuleResolver is not cached, which is different from NodeJS.
  ///
  /// If you do need to cache the result of `require` call, have a look at `module_loader_test.dart`.
  void registerModule(String moduleName, ModuleResolver resolver);

  // /// Add a callback for internal usage.
  // ///
  // /// Current usage:
  // ///
  // /// 1. Convert dart function to JS function.
  // ///
  // /// Since `Pointer.fromFunction` in ffi doesn't support dynamic functions,
  // /// we reuse the sendMessage mechanism to provide a proxy function for JS.
  // /// When that function is invoked, it simply call `FlutterJS.sendMessage` to
  // /// transfer the calling, and returns result from native.
  // ///
  // /// 2. Convert JS promise to dart Future.
  // ///
  // /// It's similar to the previous one. While converting JS promise to dart Future,
  // /// the promise's then function is invoked with an onFulfilled callback and an onError callback,
  // /// each one send result to dart through `FlutterJS.sendMessage`.
  // ///
  // /// Note: parameters defined in [fn] should follow the result types of [jsToDart], especially for numbers.
  // /// Use double to receive numbers and convert them to int in the function body.
  // @protected
  // int addNativeCallback(Function fn) {
  //   return _addNativeCallback(instanceId, fn);
  // }

  // /// Add a bridge callback. It is invoked when calling following JS code
  // ///
  // /// ```javascript
  // /// FlutterJS.sendMessage("$channelName", args);
  // /// ```
  // ///
  // /// [fn] receives a single parameter of type [List] and might return any data that can be converted to JS value through [dartToJS].
  // @protected
  // void addBridgeCallback(String channelName, Function fn) {
  //   __addNativeCallback(instanceId, channelName, fn);
  // }

  // /// Int [callbackId] for internal functions, String for setupBridge functions.
  // @protected
  // Function? getNativeCallback(dynamic callbackId, [bool remove = true]) {
  //   return _getNativeCallback(instanceId, callbackId, remove);
  // }

  // @protected
  // void setupChannelFunction();
}