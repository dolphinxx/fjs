import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import '../error.dart';
import '../lifetime.dart';
import './binding/js_base.dart';
import './binding/js_context_ref.dart';
import './binding/js_object_ref.dart';
import './binding/js_string_ref.dart';
import './binding/js_value_ref.dart';
import './binding/js_typed_array.dart';
import 'binding/jsc_types.dart';
export 'binding/jsc_types.dart' show JSValueRef;
export '../types.dart' show DART_UNDEFINED, JSToDartFunction;

typedef bytes_deallocator = Void Function(
    JSValueRef, JSContextRef);

void _bytesDeallocator(JSValueRef bytes, JSContextRef context) {
  calloc.free(bytes);
}

class JavaScriptCoreDeferredPromise implements Disposable {
  final JavaScriptCoreVm owner;
  final Lifetime<JSValuePointer> _promise;
  final Lifetime<JSValuePointer> _resolve;
  final Lifetime<JSValuePointer> _reject;

  /**
   * A native promise that will resolve once this deferred is settled.
   */
  late Future<void> settled;
  late void Function() onSettled;

  Lifetime<JSValuePointer> get promise => _promise;

  JavaScriptCoreDeferredPromise(
      this.owner, this._promise, this._resolve, this._reject) {
    Completer completer = Completer();
    this.settled = completer.future;
    this.onSettled = () => completer.complete();
  }

  /**
   * Resolve [[resolve]] with the given value, if any.
   * Calling this method after calling [[dispose]] is a no-op.
   *
   * Note that after resolving a promise, you may need to call
   * [[executePendingJobs]] to propagate the result to the promise's
   * callbacks.
   */
  void resolve(JSValuePointer? value) {
    if (!_resolve.alive) {
      return;
    }
    final JSValueRefArray args = owner.createValueRefArray([value??owner.$undefined]);
    owner.runWithExceptionHandle((exception) => jSObjectCallAsFunction(owner.ctx, _resolve.value, owner.$undefined, 1,
        args, exception), () => calloc.free(args));
    this._disposeResolvers();
    this.onSettled();
  }

  /**
   * Reject [[reject]] with the given value, if any.
   * Calling this method after calling [[dispose]] is a no-op.
   *
   * Note that after rejecting a promise, you may need to call
   * [[executePendingJobs]] to propagate the result to the promise's
   * callbacks.
   */
  reject(JSValuePointer? value) {
    if (!_reject.alive) {
      return;
    }
    final JSValueRefArray args = owner.createValueRefArray([value??owner.$undefined]);
    owner.runWithExceptionHandle((exception) => jSObjectCallAsFunction(owner.ctx, _reject.value, owner.$undefined, 1,
        args, exception), () => calloc.free(args));
    this._disposeResolvers();
    this.onSettled();
  }

  get alive {
    return _promise.alive || _resolve.alive || _reject.alive;
  }

  dispose() {
    if (_promise.alive) {
      _promise.dispose();
    }
    this._disposeResolvers();
  }

  _disposeResolvers() {
    if (_resolve.alive) {
      _resolve.dispose();
    }
    if (_reject.alive) {
      _reject.dispose();
    }
  }
}

abstract class JSHandyType {
  static const int js_unknown = 0;
  static const int js_undefined = 1;
  static const int js_null = 2;
  static const int js_boolean = 3;
  static const int js_string = 4;
  static const int js_Symbol = 5;
  static const int js_function = 6;
  static const int js_int = 7;
  static const int js_float = 8;
  static const int js_BigInt = 9;
  static const int js_Promise = 12;
  static const int js_ArrayBuffer = 13;
  static const int js_SharedArrayBuffer = 14;
  static const int js_Date = 15;
  static const int js_String = 16;
  static const int js_Number = 17;
  static const int js_Boolean = 18;
  static const int js_Error = 19;
  static const int js_RegExp = 20;
  static const int js_Array = 21;
  static const int js_object = 22;

  /// True if a dart `int` is enough to present [type].
  static bool isIntLike(int type) {
    return type == js_int || type == js_BigInt;
  }
  /// True if a dart `double` is required to present [type].
  static bool isDoubleLike(int type) {
    return type == js_float/* || type == js_BigFloat || type == js_BigDecimal*/;
  }
  static bool isObject(int type) {
    return type == js_Promise
        || type == js_ArrayBuffer
        || type == js_SharedArrayBuffer
        || type == js_Date
        || type == js_String
        || type == js_Number
        || type == js_Boolean
        || type == js_Error
        || type == js_RegExp
        || type == js_Array
        || type == js_object;
  }
}

class JavaScriptCoreVm extends Disposable {
  static final _vmMap = Map<JSContextPointer, JavaScriptCoreVm>();

  // late final JSContextGroupRef contextGroup;
  late final JSContextRef ctx;

  JSValueRef? _undefined;
  JSValueRef? _null;
  JSValueRef? _false;
  JSValueRef? _true;
  JSObjectRef? _global;

  late JSObjectRef _handyTypeof;

  final Scope _scope = new Scope();

  /// Whether to reserve JS undefined using [DART_UNDEFINED].
  bool reserveUndefined = false;
  /// Whether to JSON serialize/deserialize JS object values.
  bool jsonSerializeObject = false;
  /// Whether to auto construct DateTime for JS Date values.
  bool constructDate = true;

  /// Disable Console.log when `kRelease == true`
  bool disableConsoleInRelease = true;

  JavaScriptCoreVm() {
    ctx = jSGlobalContextCreate(nullptr);
    _scope.manage(Lifetime<JSContextRef>(ctx, (_) {
      jSGlobalContextRelease(_);
    }));
    _vmMap[ctx] = this;
    _init();
    _setupConsole();
    _setupSetTimeout();
  }

  void _init() {
    JSStringRef nameRef = newStringRef('\$\$jsc_cToHostFunction');
    // create the C to host function
    var functionObject = jSObjectMakeFunctionWithCallback(
        ctx,
        nullptr,
        Pointer.fromFunction(_cToHostCallbackFunction),
    );
    // apply the function to globalThis
    runWithExceptionHandle((exception) => jSObjectSetProperty(
        ctx,
        jSContextGetGlobalObject(ctx),
        nameRef,
        functionObject,
        JSPropertyAttributes.kJSPropertyAttributeNone,
        exception,
    ));
    jSStringRelease(nameRef);
    JSStringRef argRef = newStringRef('v');
    JSStringRefArray argsRef = createStringRefArray([argRef]);
    JSStringRef bodyRef = newStringRef('''
if(v===undefined)return 1;
if(v===null)return 2;
var t=typeof v;
if(t==='boolean')return 3;
if(t==='string')return 4;
if(t==='symbol')return 5;
if(t==='function')return 6;
if(t==='number')return Number.prototype.toString.call(v).indexOf('.')===-1?7:8;
if(t==='bigint')return 9;
if(t==='object'){
if(v instanceof Promise)return 12;
if(globalThis.ArrayBuffer&&v instanceof ArrayBuffer)return 13;
if(globalThis.SharedArrayBuffer&&v instanceof SharedArrayBuffer)return 14;
if(v instanceof Date)return 15;
if(v instanceof String)return 16;
if(v instanceof Number)return 17;
if(v instanceof Boolean)return 18;
if(v instanceof Error)return 19;
if(v instanceof RegExp)return 20;
if(v instanceof Array)return 21;
return 22;
}
return 0
''');
    _handyTypeof = runWithExceptionHandle((exception) => jSObjectMakeFunction(ctx, nullptr, 1, argsRef, bodyRef, nullptr, 0, exception), () {
      calloc.free(argsRef);
      jSStringRelease(argRef);
      jSStringRelease(bodyRef);
    });
  }

  int handyTypeof(JSValueRef val) {
    JSValueRefArray argv = createValueRefArray([val]);
    return runWithExceptionHandle((exception) {
      JSValueRef result = jSObjectCallAsFunction(ctx, _handyTypeof, nullptr, 1, argv,exception);
      return jSValueToNumber(ctx, result, nullptr)!.toInt();
    }, () => calloc.free(argv));
  }

  void _setupConsole() {
    final JSValueRef console = newObject();
    setProperty(global, 'console', console);
    JSToDartFunction logFn = (List<JSValuePointer> args, {JSValuePointer? thisObj}) {
      if(disableConsoleInRelease && kReleaseMode) {
        return;
      }
      String msg = args.map((_) {
        try {
          return jsToDart(_);
        } catch(e) {
          return '<toString failed>';
        }
      }).join(' ');
      print(msg);
    };
    final JSValueRef log = newFunction(null, logFn);
    setProperty(console, 'log', log);
  }

  int _timeoutNextId = 1;
  Map<int, Future> _timeoutMap = {};
  void _setupSetTimeout() {
    JSToDartFunction setTimeout = (List<JSValueRef> args, {JSValueRef? thisObj}) {
      int id = _timeoutNextId++;
      JSValueRef fn = args[0];
      // prevent GC
      jSValueProtect(ctx, fn);
      int ms = getInt(args[1])!;
      _timeoutMap[id] = Future.delayed(Duration(milliseconds: ms), () {
        if(_timeoutMap.containsKey(id)) {
          _timeoutMap.remove(id);
          // Note: Prefer try/catch exception inside setTimeout callback function.
          // Here we just ignore the exception.
          jSObjectCallAsFunction(ctx, fn, nullptr, 0, nullptr, nullptr);
        }
        jSValueUnprotect(ctx, fn);
      });
      return newNumber(id);
    };
    JSValuePointer setTimeoutRef = newFunction(null, setTimeout);
    setProperty(global, 'setTimeout', setTimeoutRef);
    JSToDartFunction clearTimeout = (List<JSValuePointer> args, {JSValuePointer? thisObj}) {
      int id = getInt(args[0])!;
      _timeoutMap.remove(id);
    };
    setProperty(global, 'clearTimeout', newFunction(null, clearTimeout));
  }

  /**
   * [`undefined`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/undefined).
   */
  JSValueRef get $undefined {
    if (_undefined != null) {
      return _undefined!;
    }

    // Undefined is a constant, immutable value.
    return (this._undefined = jSValueMakeUndefined(ctx));
  }

  /**
   * [`null`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null).
   */
  JSValueRef get $null {
    if (this._null != null) {
      return this._null!;
    }

    // Null is a constant, immutable value.
    return (this._null = jSValueMakeNull(ctx));
  }

  /**
   * [`true`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/true).
   */
  JSValueRef get $true {
    if (_true != null) {
      return _true!;
    }

    // True is a constant, immutable value.
    return (this._true = jSValueMakeBoolean(ctx, 1));
  }

  /**
   * [`false`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/false).
   */
  JSValueRef get $false {
    if (_false != null) {
      return _false!;
    }
    // False is a constant, immutable value.
    return (this._false = jSValueMakeBoolean(ctx, 0));
  }

  /**
   * [`global`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects).
   * A handle to the global object inside the interpreter.
   * You can set properties to create global variables.
   */
  JSObjectRef get global {
    if (_global != null) {
      return _global!;
    }
    return (_global = jSContextGetGlobalObject(ctx));
  }

  /**
   * Converts [value] into a JS value.
   */
  JSValueRef newNumber(num value) {
    return jSValueMakeNumber(ctx, value.toDouble());
  }

  /**
   * Converts [value] into a Dart number.
   * @returns `NaN` on error, otherwise a `number`.
   */
  double? getNumber(JSValuePointer value) {
    return runWithExceptionHandle((exception) => jSValueToNumber(ctx, value, exception));
  }

  int? getInt(JSValuePointer value) {
    double? result = getNumber(value);
    return result?.toInt();
  }

  double? getDouble(JSValuePointer value) {
    return getNumber(value);
  }

  /// Converts [value] into a Dart String.
  ///
  /// return a toString copy of the JSValue
  String getString(JSValuePointer value) {
    JSStringRef valRef = runWithExceptionHandle((exception) {
      return jSValueToStringCopy(ctx, value, exception);
    });
    String? result = stringRefGetString(valRef);
    jSStringRelease(valRef);
    return result;
  }

  /// Converts [value] into JS String.
  ///
  /// jSStringRelease
  JSStringRef newStringRef(String value) {
    Pointer<Utf8> ptr = value.toNativeUtf8();
    final strVal = jSStringCreateWithUTF8CString(ptr);
    calloc.free(ptr);
    return strVal;
  }

  /// Converts [value] into JS String.
  ///
  /// jSStringRelease
  JSValueRef newString(String value) {
    JSStringRef strRef = newStringRef(value);
    final result = jSValueMakeString(ctx, strRef);
    jSStringRelease(strRef);
    return result;
  }

  /// Converts a dart [timestamp] into JS Date.
  JSObjectRef newDate(int timestamp) {
    JSValueRefArray args = createValueRefArray([newNumber(timestamp)]);
    return runWithExceptionHandle((exception) => jSObjectMakeDate(ctx, 1, args, exception), () => calloc.free(args));
  }

  /**
   * `{}`.
   * Create a new JavaScript [object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Object_initializer).
   *
   * @param prototype - Like [`Object.create`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/create).
   */
  JSObjectRef newObject({Pointer? jsClass, Pointer? data}) {
    return jSObjectMake(ctx, jsClass??nullptr, data??nullptr);
  }

  /**
   * `[]`.
   * Create a new JavaScript [array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array).
   */
  JSObjectRef newArray([List<JSValueRef>? args]) {
    JSValueRefArray argv = args?.isEmpty == true ? nullptr : createValueRefArray(args!);
    return runWithExceptionHandle((exception) => jSObjectMakeArray(ctx, args?.length??0, argv, exception), () {if(args != null) calloc.free(argv);});
  }

  JSObjectRef newArrayBufferNoCopy(Uint8List val) {
    final ptr = calloc<Uint8>(val.length);
    final byteList = ptr.asTypedList(val.length);
    byteList.setAll(0, val);
    final Pointer<NativeFunction<bytes_deallocator>> deallocator =
    Pointer.fromFunction(_bytesDeallocator);
    return runWithExceptionHandle((exception) => jSObjectMakeArrayBufferWithBytesNoCopy(
        ctx, ptr, val.length, deallocator, nullptr, exception));
  }

  /// Convert dart [error] into a JS `Error`.
  JSObjectRef newError(dynamic error) {
    String? name;
    String? message;
    if (error is JSError) {
      message = error.message;
      name = error.name;
    } else {
      message = error.toString();
    }

    JSValueRef messageRef = newString(message);
    final JSValueRefArray args = createValueRefArray([messageRef]);
    final ptr = runWithExceptionHandle((exception) => jSObjectMakeError(ctx, 1, args, exception), () => calloc.free(args));

    if (name != null) {
      final _k = newStringRef('name');
      final _v = newString(name);
      runWithExceptionHandle(
        (exception) => jSObjectSetProperty(ctx, ptr, _k, _v,
            JSPropertyAttributes.kJSPropertyAttributeNone, exception),
        () {
          jSStringRelease(_k);
        },
      );
    }
    return ptr;
  }

  JavaScriptCoreDeferredPromise newPromise() {
    final resolve = calloc<JSValueRef>();
    final reject = calloc<JSValueRef>();
    final exception = calloc<JSValueRef>();
    final JSValuePointer promise = jSObjectMakeDeferredPromise(
      ctx,
      resolve,
      reject,
      exception,
    );
    JSError? error = resolveException(exception);
    if(error != null) {
      calloc.free(resolve);
      calloc.free(reject);
      throw error;
    }
    // in case promise is not resolved/rejected, and not disposed.
    return _scope.manage(JavaScriptCoreDeferredPromise(
      this,
      Lifetime(promise),
      Lifetime(resolve[0], (_) =>calloc.free(resolve)),
      Lifetime(reject[0], (_) => calloc.free(reject)),
    ));
  }

  JSObjectRef newFunction(String? name, JSToDartFunction fn) {
    final fnId = ++_fnNextId;
    _fnMap[fnId] = fn;
    JSStringRef nameRef = name == null ? nullptr : newStringRef(name);
    JSStringRef bodyRef = newStringRef('return \$\$jsc_cToHostFunction($fnId,...arguments)');
    return runWithExceptionHandle((exception) => jSObjectMakeFunction(ctx, nameRef, 0, nullptr, bodyRef, nullptr, 0, exception));
  }

  void setProp(
      JSValueRef obj, JSValueRef key, JSValueRef value) {
    runWithExceptionHandle((exception) => jSObjectSetPropertyForKey(ctx, obj, key, value, JSPropertyAttributes.kJSPropertyAttributeNone, exception));
  }

  /// [key] is one of String, num or JSValueRef
  void setProperty(JSValuePointer obj, dynamic key, JSValuePointer value) {
    if(key is String) {
      setProp(obj, newString(key), value);
      return;
    }
    if(key is num) {
      setProp(obj, newNumber(key), value);
      return;
    }
    if(!(key is JSValuePointer)) {
      throw JSError('Wrong type for key: ${key.runtimeType}');
    }
    setProp(obj, key, value);
  }

  JSValueRef getProp(JSValuePointer obj, JSValueRef key) {
    return runWithExceptionHandle((exception) => jSObjectGetPropertyForKey(ctx, obj, key, exception));
  }

  /// [key] is one of String, num or JSValuePointer
  JSValueRef getProperty(JSValuePointer obj, dynamic key) {
    if(key is String) {
      return getProp(obj, newString(key));
    }
    if(key is num) {
      return getProp(obj, newNumber(key));
    }
    if(!(key is JSValuePointer)) {
      throw JSError('Wrong type for key: ${key.runtimeType}');
    }
    return getProp(obj, key);
  }

  JSValueRef callFunction(
      JSObjectRef func,
      JSObjectRef? thisVal,
      List<JSValueRef> args,
      ) {
    JSValueRefArray argsRef = createValueRefArray(args);
    return runWithExceptionHandle((exception) => jSObjectCallAsFunction(ctx, func, thisVal??nullptr, args.length, argsRef, exception), () => calloc.free(argsRef));
  }

  JSValueRef evalCode(String code, {String? filename}) {
    JSStringRef codeRef = newStringRef(code);
    JSStringRef filenameRef = filename == null ? nullptr : newStringRef(filename);
    return runWithExceptionHandle((exception) => jSEvaluateScript(ctx, codeRef, nullptr, filenameRef, 0, exception)??$undefined);
  }

  bool get alive {
    return this._scope.alive;
  }

  /// Dispose of this VM's underlying resources.
  dispose() {
    this._scope.dispose();
  }

  dynamic jsToDart(JSValueRef jsValueRef) {
    if(jsValueRef == $undefined) {
      return reserveUndefined ? DART_UNDEFINED : null;
    }
    if(jsValueRef == $null) {
      return null;
    }
    if(jsValueRef == $true) {
      return true;
    }
    if(jsValueRef == $false) {
      return false;
    }

    final int type = handyTypeof(jsValueRef);
    JSValueRef value = jsValueRef;
    if (type == JSHandyType.js_Error) {
      String message = getString(getProperty(jsValueRef, 'message'));
      String name = getString(getProperty(jsValueRef, 'name'));
      return JSError(message)..name = name;
    }
    if (type == JSHandyType.js_string || type == JSHandyType.js_String) {
      return getString(value);
    }
    if(JSHandyType.isIntLike(type)) {
      return getInt(value);
    }
    if(JSHandyType.isDoubleLike(type)) {
      return getDouble(value);
    }
    if (type == JSHandyType.js_undefined/* || type == JSHandyType.js_uninitialized*/) {
      return reserveUndefined ? DART_UNDEFINED : null;
    }
    if (type == JSHandyType.js_null) {
      return null;
    }
    if(type == JSHandyType.js_boolean || type == JSHandyType.js_Boolean) {
      return jSValueToBoolean(ctx, value) == 1;
    }
    if(type == JSHandyType.js_function) {
      return (List<JSValuePointer> args, {JSValuePointer? thisObj}) {
        return callFunction(value, thisObj??nullptr, args);
      };
    }
    if(type == JSHandyType.js_Date) {
      int timestamp = getInt(value)!;
      return constructDate ? DateTime.fromMillisecondsSinceEpoch(timestamp) : timestamp;
    }
    if(type == JSHandyType.js_ArrayBuffer || type == JSHandyType.js_SharedArrayBuffer) {
      Pointer<Uint8> buff = runWithExceptionHandle((exception) => jSObjectGetArrayBufferBytesPtr(ctx, value, exception));
      if(buff == nullptr) {
        return null;
      }
      int size = runWithExceptionHandle((exception) => jSObjectGetArrayBufferByteLength(ctx, value, exception));
      Uint8List result = buff.asTypedList(size);
      // Note: this value will be unavailable when the binding ArrayBuffer is freed.
      return result;
    }
    if (type == JSHandyType.js_Array) {
      final lengthPtr = getProperty(jsValueRef, 'length');
      int length = jSValueToNumber(ctx, lengthPtr, nullptr)!.toInt();
      List result = [];
      for (int i = 0; i < length; i++) {
        result.add(
            jsToDart(jSObjectGetPropertyAtIndex(ctx, jsValueRef, i, nullptr)));
      }
      return result;
    }
    if (type == JSHandyType.js_Promise) {
      Completer completer = Completer();
      final thenPtr = getProperty(value, 'then');
      final onFulfilled = newFunction(null, (args, {thisObj}) {
        completer.complete(args.isEmpty ? null : jsToDart(args[0]));
      });
      final onError = newFunction(null, (args, {thisObj}) {
        var error = jsToDart(args[0]);
        completer.completeError(
            error is JSError ? error : JSError(error.toString()));
      });
      callFunction(thenPtr, value, [onFulfilled, onError]);
      // complete when the promise is resolved/rejected.
      return completer.future;
    }
    // call toString to Symbol value returns undefined.
    if(type == JSHandyType.js_Symbol) {
      return null;
    }
    if (type == JSHandyType.js_object && !jsonSerializeObject) {
        final propNamesPtr = jSObjectCopyPropertyNames(ctx, jsValueRef);
        int propNameLength = jSPropertyNameArrayGetCount(propNamesPtr);
        final result = {};
        for (int i = 0; i < propNameLength; i++) {
          final propNamePtr = jSPropertyNameArrayGetNameAtIndex(propNamesPtr, i);
          String propName = stringRefGetString(propNamePtr);
          result[propName] = jsToDart(
              jSObjectGetProperty(ctx, jsValueRef, propNamePtr, nullptr));
        }
        jSPropertyNameArrayRelease(propNamesPtr);
        return result;
    }
    // fallback
    final strRef = runWithExceptionHandle((exception) => jSValueCreateJSONString(ctx, jsValueRef, 0, exception));
    // JSON.stringify of Some JS values returns undefined.(e.g.: Symbol)
    if(strRef == nullptr) {
      return null;
    }
    final str = stringRefGetString(strRef);
    try {
      return jsonDecode(str);
    } catch (err) {
      return str;
    }

    // int type = jSValueGetType(ctx, jsValueRef);
    // if (type == JSType.kJSTypeUndefined || type == JSType.kJSTypeNull) {
    //   return null;
    // }
    // if (type == JSType.kJSTypeBoolean) {
    //   return jSValueToBoolean(ctx, jsValueRef) == 1;
    // }
    // if (type == JSType.kJSTypeNumber) {
    //   return jSValueToNumber(ctx, jsValueRef, nullptr);
    // }
    // if (type == JSType.kJSTypeString ||
    //     type == JSType.kJSTypeSymbol /*TODO:*/) {
    //   // final cp = jSValueToStringCopy(context, jsValueRef, nullptr);
    //   // Pointer<Utf16> cString = jSStringGetCharactersPtr(cp);
    //   // if(cString == nullptr) {
    //   //   return null;
    //   // }
    //   // int length = jSStringGetLength(cp);
    //   // final result = String.fromCharCodes(Uint16List.view(cString.cast<Uint16>().asTypedList(length).buffer, 0, length));
    //   // jSStringRelease(cp);
    //   return getString(jsValueRef);
    // }
    // if (type == JSType.kJSTypeObject) {
    //   if (jSValueIsArray(ctx, jsValueRef) == 1) {
    //     final lengthPtr = jsGetProperty(ctx, jsValueRef, 'length');
    //     int length = jSValueToNumber(ctx, lengthPtr, nullptr).toInt();
    //     List result = [];
    //     for (int i = 0; i < length; i++) {
    //       result.add(jsToDart(
    //           jSObjectGetPropertyAtIndex(ctx, jsValueRef, i, nullptr)));
    //     }
    //     return result;
    //   }
    //   final _typeOf = eval('FlutterJS.typeOf').value;
    //   var exception = calloc<JSValueRef>();
    //   final typeOfPtr = jSObjectCallAsFunction(ctx, _typeOf, nullptr, 1,
    //       jsCreateArgumentArray([jsValueRef]), exception);
    //   jsThrowOnError(ctx, exception);
    //   String strType = jsValueToString(ctx, typeOfPtr)!;
    //   // Limitation: The returned Function only accept a single parameter of List type.
    //   if (strType == 'function') {
    //     return (List? args) {
    //       final result = callFunction(jsValueRef, args: args).value;
    //       return jsToDart(result);
    //     };
    //   }
    //   JSValueRef thenPtr = jsGetProperty(ctx, jsValueRef, 'then');
    //   if (jSValueIsObject(ctx, thenPtr) == 1 &&
    //       jSValueIsObject(
    //           ctx, jsGetProperty(ctx, jsValueRef, 'catch')) ==
    //           1) {
    //     // Treat as a Promise instance
    //     Completer completer = Completer();
    //     int callbackId = addNativeCallback((success, value) {
    //       if (success) {
    //         completer.complete(value);
    //       } else {
    //         completer.completeError(value);
    //       }
    //     });
    //     final onFulFilled = eval(
    //         '(value)=>FlutterJS.sendMessage("internal::native_callback",{id:$callbackId,instanceId:"$instanceId",args:[true,value]})',
    //         name: 'promise onFulFilled setup').value;
    //     final onError = eval(
    //         '(error)=>FlutterJS.sendMessage("internal::native_callback",{id:$callbackId,instanceId:"$instanceId",args:[false,error]})',
    //         name: 'promise onError setup').value;
    //     exception = calloc<JSValueRef>();
    //     jSObjectCallAsFunction(ctx, thenPtr, jsValueRef, 1,
    //         jsCreateArgumentArray([onFulFilled, onError]), exception);
    //     jsThrowOnError(ctx, exception);
    //     return completer.future;
    //   }
    //   final propNamesPtr = jSObjectCopyPropertyNames(ctx, jsValueRef);
    //   int propNameLength = jSPropertyNameArrayGetCount(propNamesPtr);
    //   final result = {};
    //   for (int i = 0; i < propNameLength; i++) {
    //     final propNamePtr = jSPropertyNameArrayGetNameAtIndex(propNamesPtr, i);
    //     String propName = jsGetString(propNamePtr)!;
    //     result[propName] = jsToDart(
    //         jSObjectGetProperty(ctx, jsValueRef, propNamePtr, nullptr));
    //   }
    //   jSPropertyNameArrayRelease(propNamesPtr);
    //   return result;
    // }
    // final exception = calloc<JSValueRef>();
    // String? jsonStr =
    // jsGetString(jSValueCreateJSONString(ctx, jsValueRef, 0, exception));
    // jsThrowOnError(ctx, exception);
    // return jsonStr == null ? null : jsonDecode(jsonStr);
  }

  JSValueRef dartToJS(dynamic value) {
    if(value is Pointer) {
      return value as JSValueRef;
    }
    if(value == null) {
      return $null;
    }
    if(value == DART_UNDEFINED) {
      return $undefined;
    }
    if(value == true) {
      return $true;
    }
    if(value == false) {
      return $false;
    }
    if(value is Error || value is Exception) {
      return newError(value);
    }
    if(value is String) {
      return newString(value);
    }
    if(value is num) {
      return newNumber(value);
    }
    if(value is Function) {
      return newFunction(null, value as JSToDartFunction);
    }
    if(value is DateTime) {
      if(constructDate) {
        return newDate(value.millisecondsSinceEpoch);
      }
      return newNumber(value.millisecondsSinceEpoch);
    }
    if(value is TypedData && value is List<int>) {
      return newArrayBufferNoCopy(value is Uint8List ? value : value.buffer.asUint8List());
    }
    if(value is List) {
      return newArray(value.map((e) => dartToJS(e)).toList());
    }
    if(value is Future) {
      final promise = newPromise();
      value.then((_) => promise.resolve(dartToJS(_)))
          .catchError((_) => promise.reject(dartToJS(_)));
      return promise.promise.value;
    }
    if(value is Map) {
        final result = newObject();
        value.forEach((key, value) => setProperty(result, key, dartToJS(value)));
        return result;
    }
    // fallback to json serialize/deserialize
    String json = jsonEncode(value);
    JSStringRef jsonRef = newStringRef(json);
    JSValueRef result = jSValueMakeFromJSONString(ctx, jsonRef);
    jSStringRelease(jsonRef);
    return result;
    // if (val == null) {
    //   return jSValueMakeUndefined(ctx);
    // }
    // if (val is Error || val is Exception) {
    //   return newError(val);
    // }
    // if (val is Exception) {
    //   return jSObjectMakeError(
    //       ctx, 1, dartArrayToJs(context, [val.toString()]), nullptr);
    // }
    // if (val is Future) {
    //   final promise = newPromise();
    //   val.then((value) => promise.resolve(dartToJS(value)))
    //       .catchError((error) => promise.reject(dartToJS(error)));
    //   return promise.promise.value;
    //   // final resolve = calloc<JSValueRef>();
    //   // final reject = calloc<JSValueRef>();
    //   // val.then((value) {
    //   //   final exception = calloc<JSValueRef>();
    //   //   jSObjectCallAsFunction(ctx, resolve[0], nullptr, 1,
    //   //       jsCreateArgumentArray([_dartToJS(value)]), exception);
    //   //   String? error = _jsErrorToString(ctx, exception);
    //   //   calloc.free(exception);
    //   //   if (error != null) {
    //   //     throw error;
    //   //   }
    //   // }).catchError((err) {
    //   //   final exception = calloc<JSValueRef>();
    //   //   jSObjectCallAsFunction(ctx, reject[0], nullptr, 1,
    //   //       jsCreateArgumentArray([_dartToJS(err)]), exception);
    //   //   String? error = _jsErrorToString(ctx, exception);
    //   //   calloc.free(exception);
    //   //   if (error != null) {
    //   //     throw error;
    //   //   }
    //   // }).whenComplete(() {
    //   //   calloc.free(resolve);
    //   //   calloc.free(reject);
    //   // });
    //   // final exception = calloc<JSValueRef>();
    //   // final result =
    //   // jSObjectMakeDeferredPromise(ctx, resolve, reject, exception);
    //   // jsThrowOnError(ctx, exception);
    //   // return result;
    // }
    // if (val is bool) {
    //   return jSValueMakeBoolean(ctx, val ? 1 : 0);
    // }
    // if (val is int || val is double) {
    //   return jSValueMakeNumber(ctx, val is int ? val.toDouble() : val);
    // }
    // if (val is String) {
    //   Pointer<Utf8> ptr = val.toNativeUtf8();
    //   final strVal = jSStringCreateWithUTF8CString(ptr);
    //   final result = jSValueMakeString(ctx, strVal);
    //   calloc.free(ptr);
    //   return result;
    // }
    // if (val is Uint8List) {
    //   final ptr = calloc<Uint8>(val.length);
    //   final byteList = ptr.asTypedList(val.length);
    //   byteList.setAll(0, val);
    //   final Pointer<NativeFunction<bytes_deallocator>> deallocator =
    //   Pointer.fromFunction(_bytesDeallocator);
    //   final exception = calloc<JSValueRef>();
    //   final result = jSObjectMakeArrayBufferWithBytesNoCopy(
    //       ctx, ptr, val.length, deallocator, nullptr, exception);
    //   String? error = _jsErrorToString(ctx, exception);
    //   calloc.free(exception);
    //   if (error != null) {
    //     throw error;
    //   }
    //   return result;
    // }
    // if (val is List) {
    //   final result = newArray();
    //   for (int i = 0; i < val.length; i++) {
    //     final exception = calloc<JSValueRef>();
    //     jSObjectSetPropertyAtIndex(
    //         ctx, result, i, _dartToJS(val[i]), nullptr);
    //     String? error = _jsErrorToString(ctx, exception);
    //     calloc.free(exception);
    //     if (error != null) {
    //       throw error;
    //     }
    //   }
    //   return result;
    // }
    // if (val is Map) {
    //   final result = newObject();
    //   val.forEach((key, value) {
    //     final exception = calloc<JSValueRef>();
    //     jSObjectSetPropertyForKey(
    //         ctx, result, _dartToJS(key), _dartToJS(value), 0, nullptr);
    //     String? error = _jsErrorToString(ctx, exception);
    //     calloc.free(exception);
    //     if (error != null) {
    //       throw error;
    //     }
    //   });
    //   return result;
    // }
    // if (val is Function) {
    //   final callbackId = addNativeCallback(val);
    //   return eval(
    //       '(function() {return FlutterJS.sendMessage("internal::native_callback",{id:$callbackId, args:[...arguments]})})').value;
    // }
    // throw UnsupportedError(
    //     'Convert dart type[${val.runtimeType}] to JS type is not yet supported!');
  }

  JSError? resolveException(JSValueRefRef exception) {
    if(exception[0] != nullptr/* && jSValueIsObject(ctx, exception[0]) == 1*/) {
      final ptr = jSValueToStringCopy(ctx, exception[0], nullptr);
      calloc.free(exception);
      final _ptr = jSStringGetCharactersPtr(ptr);
      if (_ptr == nullptr) {
        return null;
      }
      int length = jSStringGetLength(ptr);
      final e = String.fromCharCodes(Uint16List.view(
          _ptr.cast<Uint16>().asTypedList(length).buffer, 0, length));
      jSStringRelease(ptr);
      return JSError(e);
    }
    calloc.free(exception);
    return null;
  }

  dynamic runWithExceptionHandle(dynamic map(JSValueRefRef exception), [Function? finalize]) {
    JSValueRefRef exception = newValueRefRef();
    try {
      dynamic result;
      try {
        result = map(exception);
      } catch(e) {
        calloc.free(exception);
        rethrow;
      }
      JSError? error = resolveException(exception);
      if(error != null) {
        throw error;
      }
      return result;
    } finally {
      if(finalize != null) {
        finalize();
      }
    }
  }

  String stringRefGetString(JSStringRef stringRef) {
    Pointer<Utf16> cString = jSStringGetCharactersPtr(stringRef);
    if (cString == nullptr) {
      return throw JSError('failed to get String to JSStringRef.');
    }
    int length = jSStringGetLength(stringRef);
    return cString.toDartString(length: length);
  }

  /// must free
  JSValueRefRef newValueRefRef() {
    return calloc<JSValueRef>();
  }

  /// create a JSValueRef[], JSStringRef[]
  ///
  /// must free
  JSValueRefArray createValueRefArray(Iterable<JSValueRef> array) {
    final pointer = calloc<JSValueRef>(array.length);
    int i = 0;
    array.forEach((element) {
      pointer[i++] = element;
    });
    return pointer;
  }

  JSStringRefArray createStringRefArray(Iterable<JSStringRef> array) {
    final pointer = calloc<JSStringRef>(array.length);
    int i = 0;
    array.forEach((element) {
      pointer[i++] = element;
    });
    return pointer;
  }

  Lifetime<JSValueRefArray> newRefArray(int length) {
    final JSValuePointerPointer ptr = calloc.call<JSValuePointer>(length);
    return new Lifetime(ptr, (value) => calloc.free(value));
  }

  var _fnNextId = 0;
  var _fnMap = new Map<int, JSToDartFunction>();

  JSValuePointer? cToHostCallbackFunction(JSContextRef ctx, JSObjectRef thisObj, int argc, JSValueRefArray argv, JSValueRefRef exception) {
    try {
      if(argc == 0) {
        throw 'cToHostCallbackFunction call missing fnId';
      }
      final fnId = getInt(argv[0]);
      final fn = _fnMap[fnId];
      if(fn == null) {
        throw 'JavaScriptCoreVm had no callback with id $fnId';
      }
      List<JSValueRef> args = [];
      for(int i = 1;i < argc;i++) {
        args.add(argv[i]);
      }
      return Function.apply(fn, [args], {#thisObj: thisObj});
    } catch(e) {
      exception[0] = newError(e);
      return $undefined;
    }
  }

  static JSValueRef? _cToHostCallbackFunction(
      JSContextRef ctx,
      JSObjectRef function,
      JSObjectRef thisObject,
      int argumentCount,
      JSValueRefArray arguments,
      JSValueRefRef exception) {
    final vm = _vmMap[ctx];
    if(vm == null) {
      throw new JSError(
          'QuickJSVm(ctx = ${ctx}) not found for C function call "${function}"');
    }
    return vm.cToHostCallbackFunction(ctx, thisObject, argumentCount, arguments, exception);
  }
}