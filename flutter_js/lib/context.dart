import 'dart:ffi';

import 'package:flutter/foundation.dart';

import 'lifetime.dart';
import 'types.dart';

typedef PromiseCallback = void Function(bool success, dynamic value);

int _jsToNativeCallbackIdIncrement = 1;

Map<dynamic, Map<dynamic, Function>> _jsToNativeCallbacks = {};

void __addNativeCallback(String instanceId, dynamic callbackId, Function fn) {
  Map<dynamic, Function> store =
      _jsToNativeCallbacks.putIfAbsent(instanceId, () => ({}));
  store[callbackId] = fn;
}

int _addNativeCallback(dynamic instanceId, Function fn) {
  int id = _jsToNativeCallbackIdIncrement++;
  __addNativeCallback(instanceId, id, fn);
  return id;
}

Function? _getNativeCallback(dynamic instanceId, int callbackId,
    [bool remove = true]) {
  Map<dynamic, Function>? store = _jsToNativeCallbacks[instanceId];
  if (store == null) {
    return null;
  }
  Function? fn = store[callbackId];
  if (fn != null && remove) {
    store.remove(callbackId);
  }
  return fn;
}

/// Used for test.
void clearAllNativeCallbacks() {
  _jsToNativeCallbacks.clear();
}

abstract class JavaScriptContext {
  static int _instanceIdIncrement = 1;
  final String instanceId = '${_instanceIdIncrement++}';

  late JSValuePointer channelInstance;

  @protected
  void postCreate() {
    channelInstance = jsEval(
      'const FlutterJS={instanceId:"$instanceId",typeOf:function(obj){return typeof obj}};FlutterJS',
      name: 'FlutterJS setup',
    ).value;
    setupChannelFunction();
  }

  Lifetime<JSValuePointer> jsEval(String js, {String? name});

  Lifetime<JSValuePointer> jsCallFunction(JSValuePointer fn,
      {List<JSValuePointer>? args, JSValuePointer? thisObject});

  /// convert js value to dart value.
  ///
  /// ```
  /// null->null
  /// undefined->null
  /// Number->double
  /// String->String
  /// ArrayBuffer->TODO
  /// Array->List
  /// Promise->Future
  /// Function->Function
  /// Object->Map<String,dynamic>
  /// ```
  dynamic jsToDart(JSValuePointer jsValueRef);

  Pointer dartToJs(dynamic val);

  /// Add a callback for internal usage.
  ///
  /// Current usage:
  ///
  /// 1. Convert dart function to JS function.
  ///
  /// Since `Pointer.fromFunction` in ffi doesn't support dynamic functions,
  /// we reuse the sendMessage mechanism to provide a proxy function for JS.
  /// When that function is invoked, it simply call `FlutterJS.sendMessage` to
  /// transfer the calling, and returns result from native.
  ///
  /// 2. Convert JS promise to dart Future.
  ///
  /// It's similar to the previous one. While converting JS promise to dart Future,
  /// the promise's then function is invoked with an onFulfilled callback and an onError callback,
  /// each one send result to dart through `FlutterJS.sendMessage`.
  ///
  /// Note: parameters defined in [fn] should follow the result types of [jsToDart], especially for numbers.
  /// Use double to receive numbers and convert them to int in the function body.
  @protected
  int addNativeCallback(Function fn) {
    return _addNativeCallback(instanceId, fn);
  }

  /// Add a bridge callback. It is invoked when calling following JS code
  ///
  /// ```javascript
  /// FlutterJS.sendMessage("$channelName", args);
  /// ```
  ///
  /// [fn] receives a single parameter of type [List] and might return any data that can be converted to JS value through [dartToJs].
  @protected
  void addBridgeCallback(String channelName, Function fn) {
    __addNativeCallback(instanceId, channelName, fn);
  }

  /// Int [callbackId] for internal functions, String for setupBridge functions.
  @protected
  Function? getNativeCallback(dynamic callbackId, [bool remove = true]) {
    return _getNativeCallback(instanceId, callbackId, remove);
  }

  @protected
  void setupChannelFunction();

  @mustCallSuper
  void dispose() {
    _jsToNativeCallbacks.remove(instanceId);
  }
}
