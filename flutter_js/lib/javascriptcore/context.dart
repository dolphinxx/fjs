import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import '../error.dart';
import '../lifetime.dart';
import './binding/js_base.dart';
import './binding/js_context_ref.dart';
import './binding/js_object_ref.dart';
import './binding/js_string_ref.dart';
import './binding/js_value_ref.dart';
import './binding/js_typed_array.dart';
import '../context.dart';
import 'binding/jsc_types.dart';
export 'binding/jsc_types.dart' show JSValueRef;

typedef bytes_deallocator = Void Function(
    JSValueRef, JSContextRef);

void _bytesDeallocator(JSValueRef bytes, JSContextRef context) {
  calloc.free(bytes);
}

typedef PromiseOnFulFilled = Void Function(JSValueRef value);
typedef PromiseOnError = Void Function(JSValueRef error);

String? _jsErrorToString(
    JSContextRef context, JSValueRefRef error) {
  if (jSValueIsObject(context, error[0]) == 1) {
    final ptr = jSValueToStringCopy(context, error[0], nullptr);
    final _ptr = jSStringGetCharactersPtr(ptr);
    if (_ptr == nullptr) {
      return null;
    }
    int length = jSStringGetLength(ptr);
    final e = String.fromCharCodes(Uint16List.view(
        _ptr.cast<Uint16>().asTypedList(length).buffer, 0, length));
    jSStringRelease(ptr);
    return e;
  }
  return null;
}

JSValueRefArray jsCreateArgumentArray(
    Iterable<JSValueRef> array) {
  final pointer = calloc<JSValueRef>(array.length);
  int i = 0;
  array.forEach((element) {
    pointer[i++] = element;
  });
  return pointer;
}

void jsThrowOnError(
    JSContextRef context, JSValueRefRef error) {
  String? e = _jsErrorToString(context, error);
  calloc.free(error);
  if (e != null) {
    throw JSError(e);
  }
}

String? jsGetString(JSStringRef stringRef) {
  Pointer<Utf16> cString = jSStringGetCharactersPtr(stringRef);
  if (cString == nullptr) {
    return null;
  }
  int length = jSStringGetLength(stringRef);
  return String.fromCharCodes(Uint16List.view(
      cString.cast<Uint16>().asTypedList(length).buffer, 0, length));
}

String? jsValueToString(JSContextRef context, JSValueRef value) {
  final exception = calloc<JSValueRef>();
  final cp = jSValueToStringCopy(context, value, exception);
  jsThrowOnError(context, exception);
  String? result = jsGetString(cp);
  jSStringRelease(cp);
  return result;
}

JSValueRef jsGetProperty(
    JSContextRef context, JSValueRef obj, String propertyName) {
  final propertyNamePtr = propertyName.toNativeUtf8();
  final exception = calloc<JSValueRef>();
  JSValueRef result = jSObjectGetProperty(
      context, obj, jSStringCreateWithUTF8CString(propertyNamePtr), exception);
  calloc.free(propertyNamePtr);
  String? error = _jsErrorToString(context, exception);
  calloc.free(exception);
  if (error != null) {
    throw error;
  }
  return result;
}

JSValuePointer _jsEval(JSContextRef context, String js,
    {String? name}) {
  // print('eval $name:\n$js');
  Pointer<Utf8> scriptCString = js.toNativeUtf8();
  Pointer<Utf8>? nameCString = name?.toNativeUtf8();

  final exception = calloc<JSValueRef>();
  var jsValueRef = jSEvaluateScript(
      context,
      jSStringCreateWithUTF8CString(scriptCString),
      nullptr,
      name == null ? nullptr : jSStringCreateWithUTF8CString(nameCString!),
      1,
      exception);
  calloc.free(scriptCString);
  if (nameCString != null) {
    calloc.free(nameCString);
  }
  String? error = _jsErrorToString(context, exception);
  calloc.free(exception);
  if (error != null) {
    throw error;
  }
  return jsValueRef;
}

class JavaScriptCoreContext extends JavaScriptContext {
  static Map<String, JavaScriptCoreContext> _contexts = {};

  static JavaScriptCoreContext getFromJS(JSContextRef context) {
    JSValueRef result = _jsEval(context, 'FlutterJS.instanceId');
    String instanceId = jsValueToString(context, result)!;
    return _contexts[instanceId]!;
  }

  late final JSContextGroupRef contextGroup;
  late final JSContextRef context;

  JavaScriptCoreContext() {
    contextGroup = jSContextGroupCreate();
    context = jSGlobalContextCreateInGroup(contextGroup, nullptr);
    _contexts[instanceId] = this;
    postCreate();
  }

  void dispose() {
    super.dispose();
    _contexts.remove(instanceId);
    jSContextGroupRelease(contextGroup);
  }

  Lifetime<JSValuePointer> jsEval(String js, {String? name}) {
    // no need to dispose
    return StaticLifetime(_jsEval(context, js, name: name));
  }

  /// Call a JS function from dart.
  ///
  /// Use [jsEval] to obtain a JS function reference and pass it as [fn] parameter, the same way for [thisObject] reference if needed.
  ///
  /// The values in [args] are automatically converted to JsValue.
  ///
  /// example:
  ///
  /// Define `plus` in JS:
  /// ```js
  /// const a = {
  ///   b: {
  ///     c: [
  ///       {
  ///         plus(left, right){
  ///           return (left + right) * this.d;
  ///         }
  ///       }
  ///     ],
  ///     d: 10
  ///   }
  /// };
  /// ```
  ///
  /// Call `plus` from dart:
  /// ```dart
  /// var fn = jsEval(context, 'a.b.c[0].plus');
  /// var thisObj = jsEval(context, 'a.b');
  /// double result = jsCallFunction(fn, thisObject:thisObj, args: [1, 2]);
  /// expect(result, 30);
  /// ```
  ///
  /// See `javascriptcore_test.dart` for more information.
  Lifetime<JSValueRef> jsCallFunction(JSValueRef fn,
      {List? args, JSValueRef? thisObject}) {
    var arguments;
    if (args?.isNotEmpty == true) {
      arguments = jsCreateArgumentArray(args!.map((_) => dartToJs(_)));
    } else {
      arguments = nullptr;
    }
    final exception = calloc<JSValueRef>();
    final result = jSObjectCallAsFunction(context, fn, thisObject ?? nullptr,
        args?.length ?? 0, arguments, exception);
    jsThrowOnError(context, exception);
    // no need to dispose
    return StaticLifetime(result);
  }

  dynamic jsToDart(JSValueRef jsValueRef) {
    int type = jSValueGetType(context, jsValueRef);
    if (type == JSType.kJSTypeUndefined || type == JSType.kJSTypeNull) {
      return null;
    }
    if (type == JSType.kJSTypeBoolean) {
      return jSValueToBoolean(context, jsValueRef) == 1;
    }
    if (type == JSType.kJSTypeNumber) {
      return jSValueToNumber(context, jsValueRef, nullptr);
    }
    if (type == JSType.kJSTypeString ||
        type == JSType.kJSTypeSymbol /*TODO:*/) {
      // final cp = jSValueToStringCopy(context, jsValueRef, nullptr);
      // Pointer<Utf16> cString = jSStringGetCharactersPtr(cp);
      // if(cString == nullptr) {
      //   return null;
      // }
      // int length = jSStringGetLength(cp);
      // final result = String.fromCharCodes(Uint16List.view(cString.cast<Uint16>().asTypedList(length).buffer, 0, length));
      // jSStringRelease(cp);
      return jsValueToString(context, jsValueRef);
    }
    if (type == JSType.kJSTypeObject) {
      if (jSValueIsArray(context, jsValueRef) == 1) {
        final lengthPtr = jsGetProperty(context, jsValueRef, 'length');
        int length = jSValueToNumber(context, lengthPtr, nullptr).toInt();
        List result = [];
        for (int i = 0; i < length; i++) {
          result.add(jsToDart(
              jSObjectGetPropertyAtIndex(context, jsValueRef, i, nullptr)));
        }
        return result;
      }
      final _typeOf = jsEval('FlutterJS.typeOf').value;
      var exception = calloc<JSValueRef>();
      final typeOfPtr = jSObjectCallAsFunction(context, _typeOf, nullptr, 1,
          jsCreateArgumentArray([jsValueRef]), exception);
      jsThrowOnError(context, exception);
      String strType = jsValueToString(context, typeOfPtr)!;
      // Limitation: The returned Function only accept a single parameter of List type.
      if (strType == 'function') {
        return (List? args) {
          final result = jsCallFunction(jsValueRef, args: args).value;
          return jsToDart(result);
        };
      }
      JSValueRef thenPtr = jsGetProperty(context, jsValueRef, 'then');
      if (jSValueIsObject(context, thenPtr) == 1 &&
          jSValueIsObject(
                  context, jsGetProperty(context, jsValueRef, 'catch')) ==
              1) {
        // Treat as a Promise instance
        Completer completer = Completer();
        int callbackId = addNativeCallback((success, value) {
          if (success) {
            completer.complete(value);
          } else {
            completer.completeError(value);
          }
        });
        final onFulFilled = jsEval(
            '(value)=>FlutterJS.sendMessage("internal::native_callback",{id:$callbackId,instanceId:"$instanceId",args:[true,value]})',
            name: 'promise onFulFilled setup').value;
        final onError = jsEval(
            '(error)=>FlutterJS.sendMessage("internal::native_callback",{id:$callbackId,instanceId:"$instanceId",args:[false,error]})',
            name: 'promise onError setup').value;
        exception = calloc<JSValueRef>();
        jSObjectCallAsFunction(context, thenPtr, jsValueRef, 1,
            jsCreateArgumentArray([onFulFilled, onError]), exception);
        jsThrowOnError(context, exception);
        return completer.future;
      }
      final propNamesPtr = jSObjectCopyPropertyNames(context, jsValueRef);
      int propNameLength = jSPropertyNameArrayGetCount(propNamesPtr);
      final result = {};
      for (int i = 0; i < propNameLength; i++) {
        final propNamePtr = jSPropertyNameArrayGetNameAtIndex(propNamesPtr, i);
        String propName = jsGetString(propNamePtr)!;
        result[propName] = jsToDart(
            jSObjectGetProperty(context, jsValueRef, propNamePtr, nullptr));
      }
      jSPropertyNameArrayRelease(propNamesPtr);
      return result;
    }
    final exception = calloc<JSValueRef>();
    String? jsonStr =
        jsGetString(jSValueCreateJSONString(context, jsValueRef, 0, exception));
    jsThrowOnError(context, exception);
    return jsonStr == null ? null : jsonDecode(jsonStr);
  }

  JSValueRef dartToJs(dynamic val) {
    if (val == null) {
      return jSValueMakeUndefined(context);
    }
    if (val is Error || val is Exception) {
      final exception = calloc<JSValueRef>();
      final result = jSObjectMakeError(
          context,
          2,
          dartArrayToJs(context, [val.toString()/*, val.stackTrace.toString()*/]),
          exception);
      String? error = _jsErrorToString(context, exception);
      calloc.free(exception);
      if (error != null) {
        throw error;
      }
      return result;
    }
    if (val is Exception) {
      return jSObjectMakeError(
          context, 1, dartArrayToJs(context, [val.toString()]), nullptr);
    }
    if (val is Future) {
      final resolve = calloc<JSValueRef>();
      final reject = calloc<JSValueRef>();
      val.then((value) {
        final exception = calloc<JSValueRef>();
        jSObjectCallAsFunction(context, resolve[0], nullptr, 1,
            jsCreateArgumentArray([dartToJs(value)]), exception);
        String? error = _jsErrorToString(context, exception);
        calloc.free(exception);
        if (error != null) {
          throw error;
        }
      }).catchError((err) {
        final exception = calloc<JSValueRef>();
        jSObjectCallAsFunction(context, reject[0], nullptr, 1,
            jsCreateArgumentArray([dartToJs(err)]), exception);
        String? error = _jsErrorToString(context, exception);
        calloc.free(exception);
        if (error != null) {
          throw error;
        }
      }).whenComplete(() {
        calloc.free(resolve);
        calloc.free(reject);
      });
      final exception = calloc<JSValueRef>();
      final result =
          jSObjectMakeDeferredPromise(context, resolve, reject, exception);
      jsThrowOnError(context, exception);
      return result;
      // final callbackId = ..;
      // final result = jsEval(context, '''new Promise(function(resolve,reject){FlutterJS.nativeCallbacks["$callbackId"]=function(result,error){delete FlutterJS.nativeCallbacks["$callbackId"];error?reject(result):resolve(result)}})''', name: 'dart2js future hook');
      // val.then((value) {
      //   final cb = jsEval(context, 'FlutterJS.nativeCallbacks["$callbackId"]');
      //   jSObjectCallAsFunction(context, cb, nullptr, 2, jsCreateArgumentArray([dartToJs(context, value),jSValueMakeBoolean(context, 1)]), nullptr);
      // }).catchError((error) {
      //   final cb = jsEval(context, 'FlutterJS.nativeCallbacks["$callbackId"]');
      //   jSObjectCallAsFunction(context, cb, nullptr, 2, jsCreateArgumentArray([dartToJs(context, error), jSValueMakeBoolean(context, 0)]), nullptr);
      // });
      // return result;
    }
    if (val is bool) {
      return jSValueMakeBoolean(context, val ? 1 : 0);
    }
    if (val is int || val is double) {
      return jSValueMakeNumber(context, val is int ? val.toDouble() : val);
    }
    if (val is String) {
      Pointer<Utf8> ptr = val.toNativeUtf8();
      final strVal = jSStringCreateWithUTF8CString(ptr);
      final result = jSValueMakeString(context, strVal);
      calloc.free(ptr);
      return result;
    }
    if (val is Uint8List) {
      final ptr = malloc<Uint8>(val.length);
      final byteList = ptr.asTypedList(val.length);
      byteList.setAll(0, val);
      final Pointer<NativeFunction<bytes_deallocator>> deallocator =
          Pointer.fromFunction(_bytesDeallocator);
      final exception = calloc<JSValueRef>();
      final result = jSObjectMakeArrayBufferWithBytesNoCopy(
          context, ptr, val.length, deallocator, nullptr, exception);
      String? error = _jsErrorToString(context, exception);
      calloc.free(exception);
      if (error != null) {
        throw error;
      }
      return result;
    }
    if (val is List) {
      final result = jSObjectMakeArray(context, 0, nullptr, nullptr);
      for (int i = 0; i < val.length; i++) {
        final exception = calloc<JSValueRef>();
        jSObjectSetPropertyAtIndex(
            context, result, i, dartToJs(val[i]), nullptr);
        String? error = _jsErrorToString(context, exception);
        calloc.free(exception);
        if (error != null) {
          throw error;
        }
      }
      return result;
    }
    if (val is Map) {
      final result = jSObjectMake(context, nullptr, nullptr);
      val.forEach((key, value) {
        final exception = calloc<JSValueRef>();
        jSObjectSetPropertyForKey(
            context, result, dartToJs(key), dartToJs(value), 0, nullptr);
        String? error = _jsErrorToString(context, exception);
        calloc.free(exception);
        if (error != null) {
          throw error;
        }
      });
      return result;
    }
    if (val is Function) {
      final callbackId = addNativeCallback(val);
      return jsEval(
          '(function() {return FlutterJS.sendMessage("internal::native_callback",{id:$callbackId, args:[...arguments]})})').value;
    }
    throw UnsupportedError(
        'Convert dart type[${val.runtimeType}] to JS type is not yet supported!');
  }

  Pointer<JSValueRef> dartArrayToJs(
      JSContextRef context, List array) {
    final pointer = calloc<JSValueRef>(array.length);
    for (int i = 0; i < array.length; i++) {
      pointer[i] = dartToJs(array[i]);
    }
    return pointer;
  }

  /// Static function for handling FlutterJS.sendMessage call.
  static Pointer sendMessageBridgeFunction(
      JSContextRef ctx,
      JSObjectRef function,
      JSObjectRef thisObject,
      int argumentCount,
      JSValueRefArray arguments,
      JSValueRefRef exception) {
    JavaScriptContext context = JavaScriptCoreContext.getFromJS(ctx);

    String channelName = context.jsToDart(arguments[0]);

    dynamic message = context.jsToDart(arguments[1]);
    // Channel names for internal usage. See [JavaScriptContext.addNativeCallback].
    if(channelName == 'internal::native_callback') {
      final callback = context.getNativeCallback((message['id'] as double).toInt());
      if(callback != null) {
        // The thisObject here is always `FlutterJS` when calling `FlutterJS.sendMessage(...)`, so we don't support thisObject to prevent side effects.
        //
        // final globalThis = jSContextGetGlobalObject(ctx);
        // dynamic thisObj = globalThis.address == thisObject.address ? null : jsToDart(ctx, thisObject);
        // return Function.apply(callback, message['args']??[], {if(thisObj != null) #thisObject: thisObject});
        final result = Function.apply(callback, message['args']??[]);
        if(result != null) {
          return context.dartToJs(result);
        }
      }
      return nullptr;
    }

    final callback = context.getNativeCallback(channelName, false);
    if(callback == null) {
      print('No channel $channelName registered');
      return nullptr;
    }
    return context.dartToJs(Function.apply(callback, message??[]));
  }

  void setupChannelFunction() {
    // Define FlutterJS.sendMessage.
    Pointer<Utf8> funcNameCString = 'sendMessage'.toNativeUtf8();
    var functionObject = jSObjectMakeFunctionWithCallback(
        context,
        jSStringCreateWithUTF8CString(funcNameCString),
        Pointer.fromFunction(sendMessageBridgeFunction));
    jSObjectSetProperty(
        context,
        channelInstance,
        jSStringCreateWithUTF8CString(funcNameCString),
        functionObject,
        JSPropertyAttributes.kJSPropertyAttributeNone,
        nullptr);
    calloc.free(funcNameCString);
  }

  void setupBridge(String channelName, FutureOr Function(List args) fn) {
    // TODO:
  }
}
