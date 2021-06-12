import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:fjs/vm.dart';

import '../error.dart';
import '../promise.dart';
import 'qjs_ffi.dart';
import '../lifetime.dart';

/**
 * From https://www.figma.com/blog/how-we-built-the-figma-plugin-system/
 */
class VmPropertyDescriptor<VmHandle> {
  JSValuePointer? value;
  bool? configurable;
  bool? enumerable;
  bool? writable;
  JSToDartFunction? get;
  JSToDartFunction? set;

  VmPropertyDescriptor({
    this.value,
    this.configurable,
    this.enumerable,
    this.writable,
    this.get,
    this.set,
  });
}

/// @returns 1/0
typedef CToHostInterruptImplementation = int Function(JSRuntimePointer rt);

/**
 * Callback called regularly while the VM executes code.
 * Determines if a VM's execution should be interrupted.
 *
 * @returns `true` to interrupt JS execution inside the VM.
 * @returns `false` or `undefined` to continue JS execution inside the VM.
 */
typedef InterruptHandler = bool? Function(QuickJSVm vm);

class QuickJSVm extends Vm implements Disposable {
  static final _vmMap = Map<JSContextPointer, QuickJSVm>();
  static final _rtMap = Map<JSRuntimePointer, QuickJSVm>();
  static bool _initialized = false;

  late final JSRuntimePointer rt;
  late final JSContextPointer ctx;

  JSValuePointer? _undefined;
  JSValuePointer? _null;
  JSValuePointer? _false;
  JSValuePointer? _true;
  JSValuePointer? _global;
  final Scope _scope = new Scope();
  /// heap values created by this vm, and should be freed when this vm is disposed.
  final Set<JSValuePointer> _heapValues = Set();

  QuickJSVm({
    bool? reserveUndefined,
    bool? jsonSerializeObject,
    bool? constructDate,
    bool? disableConsoleInRelease,
    bool? arrayBufferCopy,
  }) : super(
    reserveUndefined: reserveUndefined,
    jsonSerializeObject: jsonSerializeObject,
    constructDate: constructDate,
    disableConsoleInRelease: disableConsoleInRelease,
    arrayBufferCopy: arrayBufferCopy,
  ) {
    if (!_initialized) {
      final QJS_C_To_HostCallbackFuncPointer funcCallbackFp =
          Pointer.fromFunction(
        _cToHostCallbackFunction,
        // functionCallbackWasmTypes.join('')
      );
      JS_SetHostCallback(funcCallbackFp);

      // final interruptCallbackWasmTypes = [
      //   intType, // return 0 no interrupt, !=0 interrrupt
      //   pointerType, // rt_ptr
      // ];
      final QJS_C_To_HostInterruptFuncPointer interruptCallbackFp =
          Pointer.fromFunction(
        _cToHostInterrupt,
        // failed
        0,
        // interruptCallbackWasmTypes.join('')
      );
      JS_SetInterruptCallback(interruptCallbackFp);
      _initialized = true;
    }

    rt = JS_NewRuntime();
    ctx = JS_NewContext(rt);
    _vmMap[ctx] = this;
    _rtMap[rt] = this;
    _setupConsole();
    _setupSetTimeout();
    postConstruct();
  }

  void _setupConsole() {
    final JSValuePointer console = newObject();
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
    final JSValuePointer log = newFunction('log', logFn);
    setProperty(console, 'log', log);
    _freeJSValue(log);
  }

  int _timeoutNextId = 1;
  Map<int, Future> _timeoutMap = {};
  void _setupSetTimeout() {
    JSToDartFunction setTimeout = (List<JSValuePointer> args, {JSValuePointer? thisObj}) {
      int id = _timeoutNextId++;
      JSValuePointer fn = JS_DupValuePointer(ctx, args[0]);
      int ms = getInt(args[1])!;
      _timeoutMap[id] = Future.delayed(Duration(milliseconds: ms), () {
        // cancelled
        if(_timeoutMap.containsKey(id)) {
          _timeoutMap.remove(id);
          JS_CallVoid(ctx, fn, $undefined, 0, nullptr);
        }
        JS_FreeValuePointer(ctx, fn);
      });
      return newNumber(id);
    };
    final setTimeoutFn = newFunction('setTimeout', setTimeout);
    setProperty(global, 'setTimeout', setTimeoutFn);
    _freeJSValue(setTimeoutFn);
    JSToDartFunction clearTimeout = (List<JSValuePointer> args, {JSValuePointer? thisObj}) {
      int id = getInt(args[0])!;
      _timeoutMap.remove(id);
    };
    final clearTimeoutFn = newFunction('clearTimeout', clearTimeout);
    setProperty(global, 'clearTimeout', clearTimeoutFn);
    _freeJSValue(clearTimeoutFn);
  }

  /**
   * [`undefined`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/undefined).
   */
  JSValuePointer get $undefined {
    if (_undefined != null) {
      return _undefined!;
    }

    // Undefined is a constant, immutable value in QuickJS.
    final ptr = JS_GetUndefined();
    return (this._undefined = ptr);
  }

  /**
   * [`null`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null).
   */
  JSValuePointer get $null {
    if (this._null != null) {
      return this._null!;
    }

    // Null is a constant, immutable value in QuickJS.
    final ptr = JS_GetNull();
    return (this._null = ptr);
  }

  /**
   * [`true`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/true).
   */
  JSValuePointer get $true {
    if (_true != null) {
      return _true!;
    }

    // True is a constant, immutable value in QuickJS.
    final ptr = JS_GetTrue();
    return (this._true = ptr);
  }

  /**
   * [`false`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/false).
   */
  JSValuePointer get $false {
    if (_false != null) {
      return _false!;
    }

    // False is a constant, immutable value in QuickJS.
    final ptr = JS_GetFalse();
    return (this._false = ptr);
  }

  /**
   * [`global`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects).
   * A handle to the global object inside the interpreter.
   * You can set properties to create global variables.
   */
  JSValuePointer get global {
    if (_global != null) {
      return _global!;
    }

    // Automatically clean up this reference when we dispose
    _global = _heapValueHandle(JS_GetGlobalObject(ctx));
    return _global!;
  }

  JSValuePointer get nullThis => $undefined;

  /**
   * `typeof` operator. **Not** [standards compliant](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/typeof).
   *
   * @remarks
   * Does not support BigInt values correctly.
   */
  String typeof(JSValuePointer value) {
    return JS_Typeof(ctx, value).toDartString();
  }

  /**
   * Converts a Dart number into a QuickJS value.
   */
  JSValuePointer newNumber(num value) {
    return _heapValueHandle(JS_NewFloat64(ctx, value.toDouble()));
  }

  /**
   * Converts `value` into a Dart number.
   * @returns `NaN` on error, otherwise a `number`.
   */
  double? getNumber(JSValuePointer value) {
    return JS_GetFloat64(ctx, value);
  }

  int? getInt(JSValuePointer value) {
    double? result = getNumber(value);
    return result?.toInt();
  }

  double? getDouble(JSValuePointer value) {
    return getNumber(value);
  }

  String getString(JSValuePointer value) {
    return JS_GetString(ctx, value).toDartString();
    // Pointer<Utf8> ptr =  jsToCString(context, value);
    // final str = ptr.toDartString();
    // JS_JSFreeCString(context, ptr);
    // return str;
  }

  JSValuePointer newString(String value) {
    final utf8str = value.toNativeUtf8();
    final ptr = JS_NewString(ctx, utf8str);
    calloc.free(utf8str);
    return this._heapValueHandle(ptr);
  }

  JSValuePointer newDate(int timestamp) {
    return _heapValueHandle(JS_NewDate(ctx, timestamp));
  }

  /**
   * `{}`.
   * Create a new QuickJS [object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Object_initializer).
   *
   * @param prototype - Like [`Object.create`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/create).
   */
  JSValuePointer newObject([Map? value]) {
    final ptr = JS_NewObject(ctx);
    if(value != null) {
      value.forEach((key, value) {
        consumeAndFree(dartToJS(value), (_) => defineProperty(ptr, key, VmPropertyDescriptor(value: _, enumerable: true, configurable: true, writable: true)));
      });
    }
    return _heapValueHandle(ptr);
  }

  JSValuePointer newObjectWithPrototype(JSValuePointer prototype, [Map? value]) {
    final ptr = JS_NewObjectProto(ctx, prototype);
    if(value != null) {
      value.forEach((key, value) {
        consumeAndFree(dartToJS(value), (_) => defineProperty(ptr, key, VmPropertyDescriptor(value: _, enumerable: true, configurable: true, writable: true)));
      });
    }
    return _heapValueHandle(ptr);
  }

  /**
   * `[]`.
   * Create a new QuickJS [array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array).
   */
  JSValuePointer newArray([List<JSValuePointer>? args]) {
    final ptr = JS_NewArray(ctx);
    if(args != null) {
      for(int i = 0;i<args.length;i++) {
        defineProperty(ptr, i, VmPropertyDescriptor(value: args[i]));
      }
    }
    return _heapValueHandle(ptr);
  }

  JSValuePointer newArrayBufferCopy(Uint8List value) {
    final ptr = calloc<Uint8>(value.length);
    try {
      final byteList = ptr.asTypedList(value.length);
      byteList.setAll(0, value);
      final ret = JS_NewArrayBufferCopy(ctx, ptr, value.length);
      return _heapValueHandle(ret);
    } finally {
      calloc.free(ptr);
    }
  }

  JSValuePointer newArrayBuffer(Uint8List value) {
    final ptr = calloc<Uint8>(value.length);
    final byteList = ptr.asTypedList(value.length);
    byteList.setAll(0, value);
    final ret = JS_NewArrayBuffer(
        ctx, ptr, value.length, Pointer.fromFunction(_cToHostArrayBufferFreeCallback), nullptr, 0);
    return _heapValueHandle(ret);
  }

  JSValuePointer newError(dynamic error) {
    String? name;
    String? message;
    if (error is JSError) {
      message = error.message;
      name = error.name;
      // Disable stackTrace due to security leak concerns
    } else {
      message = error.toString();
    }
    final ptr = JS_NewError(ctx);
    if (name != null) {
      final _k = newString('name');
      final _v = newString(name);
      JS_SetProp(ctx, ptr, _k, _v);
      _freeJSValue(_k);
      _freeJSValue(_v);
    }
    final _k = newString('message');
    final _v = newString(message);
    JS_SetProp(ctx, ptr, _k, _v);
    _freeJSValue(_k);
    _freeJSValue(_v);
    return _heapValueHandle(ptr);
  }

  JSError extractError(JSValuePointer value, [bool free = true]) {
    setMemoryLimit(-1); // so we can dump
    final str = JS_Dump(ctx, value);
    if(free) {
      JS_FreeValuePointer(ctx, value);
    }
    dynamic e = jsonDecode(str.toDartString());
    if (e is Map && e['message'] is String) {
      JSError error = JSError(e['message'], e['stack'] == null ? StackTrace.current : StackTrace.fromString(e['stack']));
      if (e['name'] is String) {
        error.name = e['name'];
      }
      return error;
    }
    return JSError(e.toString());
  }

  /// try getting exception from [value], if exception exists, free [value] and return a `JSError`
  JSError? resolveError(JSValuePointer value) {
    JSValuePointer _ = value;
    final errorPtr = JS_ResolveException(ctx, value);
    if (errorPtr == nullptr) {
      return null;
    }
    JS_FreeValuePointer(ctx, value);
    return extractError(errorPtr);
  }

  JSDeferredPromise newPromise([Future? future]) {
    // Pointer for receiving resolve & reject
    Lifetime<JSValuePointerPointer> resolves = _newMutablePointerArray(2);
    try {
      final JSValuePointer promise = JS_NewPromiseCapability(
        ctx,
        resolves.value,
      );
      final promiseWrapper = _scope.manage(JSDeferredPromise(
        this,
        Lifetime(_heapValueHandle(promise)),
        Lifetime(_heapValueHandle(resolves.value[0])),
        Lifetime(_heapValueHandle(resolves.value[1])),
        future,
      ));
      if(future != null) {
        future.then((_) => consumeAndFree(dartToJS(_), (ptr) => promiseWrapper.resolve(ptr)))
            .catchError((_) => consumeAndFree(dartToJS(_), (ptr) => promiseWrapper.reject(ptr)));
      }
      return promiseWrapper;
    } finally {
      resolves.dispose();
    }
  }

  /**
   * Convert a Javascript function into a QuickJS function value.
   * See [[JSToDartFunction]] for more details.
   *
   * A [[JSToDartFunction]] should not free its arguments or its retun
   * value. A JSToDartFunction should also not retain any references to
   * its return value.
   *
   * To implement an async function, create a promise with [[newPromise]], then
   * return the deferred promise handle from `deferred.handle` from your
   * function implementation:
   *
   * ```
   * const deferred = vm.newPromise()
   * someNativeAsyncFunction().then(deferred.resolve)
   * return deferred.handle
   * ```
   *
   */
  JSValuePointer newFunction(String? name, JSToDartFunction fn) {
    final fnId = ++_fnNextId;
    _fnMap[fnId] = fn;

    final fnIdHandle = newNumber(fnId.toDouble());
    HeapCharPointer namePtr = name == null ? nullptr : name.toNativeUtf8();
    final funcHandle = this._heapValueHandle(
        JS_NewFunction(ctx, fnIdHandle, namePtr));
    if(name != null) {
      calloc.free(namePtr);
    }
    return funcHandle;
  }

  JSValuePointer newConstructor(JSToDartFunction fn) {
    JSValuePointer c = newFunction(null, fn);
    JS_ToConstructor(ctx, c);
    return c;
  }

  /// Mark a JS [function] as a constructor so that it can be called via `new func()`
  ///
  /// It is required by QuickJS.
  void toConstructor(JSValuePointer func) {
    JS_ToConstructor(ctx, func);
  }

  /**
   * `handle[key] = value`.
   * Set a property on a JSValue.
   *
   * @remarks
   * Note that the QuickJS authors recommend using [[defineProp]] to define new
   * properties.
   *
   * @param key - The property may be specified as a JSValuePointer.
   */
  void setProp(
      JSValuePointer obj, JSValueConstPointer key, JSValuePointer value) {
    JS_SetProp(ctx, obj, key, value);
  }
  /// [key] is one of String, num or JSValuePointer
  void setProperty(JSValuePointer obj, dynamic key, JSValuePointer value) {
    if(key is String) {
      consumeAndFree(newString(key), (k) => setProp(obj, k, value));
      return;
    }
    if(key is num) {
      consumeAndFree(newNumber(key), (k) => setProp(obj, k, value));
      return;
    }
    if(!(key is JSValuePointer)) {
      throw JSError('Wrong type for key: ${key.runtimeType}');
    }
    setProp(obj, key, value);
  }

  /**
   * `handle[key]`.
   * Get a property from a JSValue.
   *
   * @param key - The property may be specified as a JSValuePointer.
   */
  JSValuePointer getProp(JSValuePointer obj, JSValueConstPointer key) {
    return _heapValueHandle(JS_GetProp(ctx, obj, key));
  }
  /// [key] is one of String, num or JSValuePointer
  JSValuePointer getProperty(JSValuePointer obj, dynamic key) {
    if(key is String) {
      return consumeAndFree(newString(key), (k) => getProp(obj, k));
    }
    if(key is num) {
      return consumeAndFree(newNumber(key), (k) => getProp(obj, k));
    }
    if(!(key is JSValuePointer)) {
      throw JSError('Wrong type for key: ${key.runtimeType}');
    }
    return getProp(obj, key);
  }

  bool hasProp(JSValuePointer obj, JSValueConstPointer key) {
    return JS_HasProp(ctx, obj, key) == 1;
  }

  bool hasProperty(JSValuePointer obj, dynamic key) {
    if(key is String) {
      return consumeAndFree(newString(key), (k) => hasProp(obj, k));
    }
    if(key is num) {
      return consumeAndFree(newNumber(key), (k) => hasProp(obj, k));
    }
    if(!(key is JSValuePointer)) {
      throw JSError('Wrong type for key: ${key.runtimeType}');
    }
    return hasProp(obj, key);
  }

  /**
   * [`Object.defineProperty(handle, key, descriptor)`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/defineProperty).
   *
   * @param key - The property may be specified as a JSValuePointer.
   */
  void defineProp(
    JSValuePointer obj,
    JSValueConstPointer key,
    VmPropertyDescriptor<JSValuePointer> descriptor,
  ) {
    final value = descriptor.value ?? $undefined;
    final configurable = descriptor.configurable == true ? 1 : 0;
    final enumerable = descriptor.enumerable == true ? 1 : 0;
    final writable = descriptor.writable == true ? 1 : 0;
    final hasValue = descriptor.value != null ? 1 : 0;
    final get = descriptor.get != null
        ? newFunction('getter', descriptor.get!) : $undefined;
    final set = descriptor.set != null
        ? newFunction('setter', descriptor.set!) : $undefined;

    JS_DefineProp(
      ctx,
      obj,
      key,
      value,
      get,
      set,
      configurable,
      enumerable,
      writable,
      hasValue,
    );
  }
  /// [key] is one of String, num or JSValuePointer
  void defineProperty(JSValuePointer obj, dynamic key, VmPropertyDescriptor<JSValuePointer> descriptor) {
    if(key is String) {
      consumeAndFree(newString(key), (k) => defineProp(obj, k, descriptor));
      return;
    }
    if(key is num) {
      consumeAndFree(newNumber(key), (k) => defineProp(obj, k, descriptor));
      return;
    }
    if(!(key is JSValuePointer)) {
      throw JSError('Wrong type for key: ${key.runtimeType}');
    }
    defineProp(obj, key, descriptor);
  }

  /// [`func.call(thisVal, ...args)`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/call).
  /// Call a JSValue as a function.
  ///
  /// See [[unwrapResult]], which will throw if the function returned an error, or
  /// return the result handle directly.
  ///
  /// @returns A result of JSValuePointer|JSValueConstPointer|void. If the function threw, result `error` be a handle to the exception.
  JSValuePointer callFunction(
    JSValuePointer func,
    [JSValuePointer? thisVal,
      List<JSValuePointer>? args]
  ) {
    Lifetime<JSValueConstPointerPointer>? argv;
    int argc;
    if(args?.isNotEmpty != true) {
      argc = 0;
    } else {
      argc = args!.length;
      argv = _toPointerArray(args);
    }
    final resultPtr;
    try {
      resultPtr = JS_Call(ctx, func, thisVal??$undefined, argc, argv?.value??nullptr);
    } finally {
      argv?.dispose();
    }

    JSError? error = resolveError(resultPtr);
    if(error != null) {
      throw error;
    }
    return _heapValueHandle(resultPtr);
  }

  void callVoidFunction(JSValuePointer func,
      [JSValuePointer? thisVal,
        List<JSValuePointer>? args]) {
    _freeJSValue(callFunction(func, thisVal, args));
  }

  JSValuePointer callConstructor(JSValuePointer constructor, [List<JSValuePointer>? args]) {
    Lifetime<JSValueConstPointerPointer>? argv;
    int argc;
    if(args?.isNotEmpty != true) {
      argc = 0;
    } else {
      argc = args!.length;
      argv = _toPointerArray(args);
    }
    final resultPtr;
    try {
      resultPtr = JS_CallConstructor(ctx, constructor, argc, argv?.value??nullptr);
    } finally {
      argv?.dispose();
    }

    JSError? error = resolveError(resultPtr);
    if(error != null) {
      throw error;
    }
    return _heapValueHandle(resultPtr);
  }

  /**
   * Like [`eval(code)`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval#Description).
   * Evaluates the Javascript source `code` in the global scope of this VM.
   * When working with async code, you many need to call [[executePendingJobs]]
   * to execute callbacks pending after synchronous evaluation returns.
   *
   * See [[unwrapResult]], which will throw if the function returned an error, or
   * return the result handle directly.
   *
   * *Note*: to protect against infinite loops, provide an interrupt handler to
   * [[setInterruptHandler]]. You can use [[shouldInterruptAfterDeadline]] to
   * create a time-based deadline.
   *
   *
   * @returns The last statement's value. If the code threw, result `error` will be
   * a handle to the exception. If execution was interrupted, the error will
   * have name `InternalError` and message `interrupted`.
   */
  JSValuePointer evalCode(String code, {String? filename}) {
    HeapCharPointer codeHandle = code.toNativeUtf8();
    HeapCharPointer filenameHandle = (filename??'<eval.js>').toNativeUtf8();
    late final resultPtr;
    try {
      resultPtr = JS_Eval(ctx, codeHandle, codeHandle.length, filenameHandle, JSEvalFlag.GLOBAL);
    } finally {
      malloc.free(codeHandle);
      malloc.free(filenameHandle);
    }

    JSError? error = resolveError(resultPtr);
    if(error != null) {
      throw error;
    }
    return _heapValueHandle(resultPtr);
  }

  T evalAndConsume<T>(String code, T map(JSValuePointer ptr)) {
    return consumeAndFree(evalCode(code), map);
  }

  /**
   * Execute pendingJobs on the VM until `maxJobsToExecute` jobs are executed
   * (default all pendingJobs), the queue is exhausted, or the runtime
   * encounters an exception.
   *
   * In QuickJS, promises and async functions create pendingJobs. These do not execute
   * immediately and need to triggered to run.
   *
   * @param maxJobsToExecute - When negative, run all pending jobs. Otherwise execute
   * at most `maxJobsToExecute` before returning.
   *
   * @return On success, the number of executed jobs. On error, the exception
   * that stopped execution.
   */
  int executePendingJobs([int maxJobsToExecute = -1]) {
    final resultValue = JS_ExecutePendingJob(rt, maxJobsToExecute);
    final typeOfRet = this.typeof(resultValue);
    if (typeOfRet == 'number') {
      final executedJobs = this.getNumber(resultValue)!.toInt();
      JS_FreeValuePointer(ctx, resultValue);
      return executedJobs;
    } else {
      throw extractError(resultValue);
    }
  }

  /**
   * In QuickJS, promises and async functions create pendingJobs. These do not execute
   * immediately and need to be run by calling [[executePendingJobs]].
   *
   * @return true if there is at least one pendingJob queued up.
   */
  bool hasPendingJob() {
    return JS_IsJobPending(rt) > 0;
  }

  /**
   * Dump a JSValue to Javascript in a best-effort fashion.
   * Returns `handle.toString()` if it cannot be serialized to JSON.
   */
  dynamic dump(JSValuePointer value) {
    final type = this.typeof(value);
    if (type == 'string') {
      return this.getString(value);
    } else if (type == 'number') {
      return this.getNumber(value);
    } else if (type == 'undefined') {
      return null /*undefined*/;
    }

    final str = JS_Dump(ctx, value);
    try {
      return jsonDecode(str.toDartString());
    } catch (err) {
      return str;
    }
  }

  /// Convert JS [value] to Dart value.
  ///
  /// **Note:** For `ArrayBuffer` value, the return value is just pointed to the uint8_t* data hold by the js value.
  /// The returned value need to be copied(`Uint8List.fromList(..)`) to be available after this js value is freed.
  dynamic jsToDart(JSValuePointer value) {
    if(value == $undefined) {
      return reserveUndefined ? DART_UNDEFINED : null;
    }
    if(value == $null) {
      return null;
    }
    if(value == $true) {
      return true;
    }
    if(value == $false) {
      return false;
    }
    final String type = JS_HandyTypeof(ctx, value).toDartString();
    if (type == JSHandyType.js_Error) {
      return extractError(value, false);
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
    if (type == JSHandyType.js_undefined || type == JSHandyType.js_uninitialized) {
      return reserveUndefined ? DART_UNDEFINED : null;
    }
    if (type == JSHandyType.js_null) {
      return null;
    }
    if(type == JSHandyType.js_boolean || type == JSHandyType.js_Boolean) {
      return JS_ToBool(ctx, value) == 1;
    }
    if(type == JSHandyType.js_function) {
      return (List<JSValuePointer> args, {JSValuePointer? thisObj}) {
        return callFunction(value, thisObj??nullptr, args)/*.consume((_) => jsToDart(_.value))*/;
      };
    }
    if(type == JSHandyType.js_Date) {
      int timestamp = getInt(value)!;
      return constructDate ? DateTime.fromMillisecondsSinceEpoch(timestamp) : timestamp;
    }
    if(type == JSHandyType.js_ArrayBuffer || type == JSHandyType.js_SharedArrayBuffer) {
      final psize = calloc<IntPtr>();
      final buff = JS_GetArrayBuffer(ctx, psize, value);
      Uint8List result = buff.asTypedList(psize.value);
      calloc.free(psize);
      // Note: this value will be unavailable when the binding ArrayBuffer is freed.
      return result;
    }
    if(type == JSHandyType.js_Array) {
      int length = consumeAndFree(getProperty(value, 'length'), (_) => getNumber(_)!.toInt());
      List result = [];
      for (int i = 0; i < length; i++) {
        result.add(consumeAndFree(getProperty(value, i), (_) => jsToDart(_)));
      }
      return result;
    }
    if(type == JSHandyType.js_Promise) {
      Completer completer = Completer();
      final thenPtr = getProperty(value, 'then');
      final onFulfilled = newFunction('promise_onFulfilled', (args, {thisObj}) {
        completer.complete(args.isEmpty ? null : jsToDart(args[0]));
      });
      final onError = newFunction('promise_onError', (args, {thisObj}) {
        var error = jsToDart(args[0]);
        completer.completeError(error is JSError ? error : JSError(error.toString()));
      });
      try {
        callFunction(thenPtr, value, [onFulfilled, onError]);
        // complete when the promise is resolved/rejected.
        return completer.future;
      } finally {
        _freeJSValue(onFulfilled);
        _freeJSValue(onError);
      }
    }
    // call toString to Symbol value returns undefined.
    if(type == JSHandyType.js_Symbol) {
      return null;
    }
    // if (type == JSHandyType.kObject) {
    //   final ptab = malloc<IntPtr>();
    //   final plen = malloc<Uint32>();
    //   if(JS_GetOwnPropertyNames(ctx, ptab, plen, value, JS_GPN_COPYABLE) != 0) {
    //     malloc.free(ptab);
    //     malloc.free(plen);
    //     throw JSError('"Could not get object properties');
    //   }
    //   int length = plen.value;
    //   malloc.free(plen);
    //   final Map<String, dynamic> result = {};
    //   Pointer<JSPropertyEnum> propertyEnums = Pointer<JSPropertyEnum>.fromAddress(ptab.elementAt(0).value);
    //   for(int i = 0;i < length;i++) {
    //     final JSPropertyEnum propEnum = propertyEnums[i]/*Pointer<JSPropertyEnum>.fromAddress(ptab.elementAt(0).value + sizeOf<JSPropertyEnum>() * i).ref*/;
    //     if(propEnum.is_enumerable == 1) {
    //       final atomStr = JS_AtomToString(ctx, propEnum.atom);
    //       String key = getString(atomStr);
    //       _freeJSValue(atomStr);
    //       final propValue = JS_GetProperty(ctx, value, propEnum.atom);
    //       result[key] = jsToDart(propValue);
    //       _freeJSValue(propValue);
    //     }
    //   }
    //   JS_FreePropEnum(ctx, ptab, length);
    //   malloc.free(ptab);
    //   return result;
    // }
    if (type == JSHandyType.js_object && !jsonSerializeObject) {
      final atomsPtrRec = calloc<IntPtr>();
      final length = JS_GetOwnPropertyNameAtoms(ctx, atomsPtrRec, value, JS_GPN_COPYABLE);
      if(length <= 0) {
        calloc.free(atomsPtrRec);
        if(length < 0) {
          throw JSError('"Could not get object properties');
        }
        return {};
      }
      final Map<String, dynamic> result = {};
      Pointer<Uint32> atomsPtr = Pointer<Uint32>.fromAddress(atomsPtrRec.value);
      calloc.free(atomsPtrRec);
      final atoms = atomsPtr.asTypedList(length);
      for(int i = 0;i < length;i++) {
        int atom = atoms[i];
        final atomStr = JS_AtomToString(ctx, atom);
        String key = getString(atomStr);
        JS_FreeValuePointer(ctx, atomStr);
        final propValue = JS_GetProperty(ctx, value, atom);
        result[key] = jsToDart(propValue);
        JS_FreeValuePointer(ctx, propValue);
      }
      calloc.free(atomsPtr);
      return result;
    }
    // fallback
    final str = JS_Dump(ctx, value);
    try {
      return jsonDecode(str.toDartString());
    } catch (err) {
      return str;
    }
  }

  /// If [value] is dart function, it must be able to cast to [JSToDartFunction].
  ///
  /// [value] must be able to be serialize to JSON through `jsonEncode` if it is not one of the supported types.
  JSValuePointer dartToJS(dynamic value) {
    if(value is JSValuePointer) {
      // return _heapValueHandle(value as JSValuePointer);
      return value;
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
      Uint8List list = value is Uint8List ? value : value.buffer.asUint8List();
      return arrayBufferCopy ? newArrayBufferCopy(list) : newArrayBuffer(list);
    }
    if(value is List) {
      List<JSValuePointer> elements = value.map((e) => dartToJS(e)).toList();
      final result = newArray(elements);
      elements.forEach((element) => _freeJSValue(element));
      return result;
    }
    if(value is Future) {
      return newPromise(value).promise.value;
    }
    if(value is Map) {
      return newObject(value);
    }
    // fallback
    String json = jsonEncode(value);
    return evalCode('($json)');
  }

  InterruptHandler? _interruptHandler;

  /**
   * Set a callback which is regularly called by the QuickJS engine when it is
   * executing code. This callback can be used to implement an execution
   * timeout.
   *
   * The interrupt handler can be removed with [[removeInterruptHandler]].
   */
  void setInterruptHandler(InterruptHandler cb) {
    final prevInterruptHandler = _interruptHandler;
    _interruptHandler = cb;
    if (prevInterruptHandler == null) {
      JS_RuntimeEnableInterruptHandler(rt);
    }
  }

  /**
   * Set the max memory this runtime can allocate.
   * To remove the limit, set to `-1`.
   */
  void setMemoryLimit(int limitBytes) {
    if (limitBytes < 0 && limitBytes != -1) {
      throw new JSError(
          'Cannot set memory limit to negative number. To unset, pass -1');
    }

    JS_RuntimeSetMemoryLimit(rt, limitBytes);
  }

  /**
   * Compute memory usage for this runtime. Returns the result as a handle to a
   * JSValue object. Use [[dump]] to convert to a native object.
   * Calling this method will allocate more memory inside the runtime. The information
   * is accurate as of just before the call to `computeMemoryUsage`.
   * For a human-digestable representation, see [[dumpMemoryUsage]].
   */
  JSValuePointer computeMemoryUsage() {
    return this
        ._heapValueHandle(JS_RuntimeComputeMemoryUsage(rt, ctx));
  }

  /**
   * @returns a human-readable description of memory usage in this runtime.
   * For programatic access to this information, see [[computeMemoryUsage]].
   */
  String dumpMemoryUsage() {
    try {
      HeapCharPointer result = JS_RuntimeDumpMemoryUsage(rt, 1024);
      return utf8.decode(result.cast<Uint8>().asTypedList(result.length),
          allowMalformed: true);
    } catch (e) {
      return e.toString();
    }
  }

  /**
   * Remove the interrupt handler, if any.
   * See [[setInterruptHandler]].
   */
  removeInterruptHandler() {
    if (this._interruptHandler != null) {
      JS_RuntimeDisableInterruptHandler(rt);
      this._interruptHandler = null;
    }
  }

  bool get alive {
    return this._scope.alive;
  }

  /**
   * Dispose of this VM's underlying resources.
   *
   * @throws Calling this method without disposing of all created handles
   * will result in an error.
   */
  dispose() {
    super.dispose();
    _eventLoop?.cancel();
    this._heapValues.forEach((val) {
      // String dp = JS_Dump(ctx, val).toDartString();
      // print('Pointer:${val.address} $dp');
      // if(dp == '[unsupported type]') {
      //   print('unsupported type: ${JS_HandyTypeof(ctx, val)}');
      // }
      JS_FreeValuePointer(ctx, val);
    });
    this._scope.dispose();
    this._timeoutMap.clear();
    this._fnMap.clear();
    _vmMap.remove(ctx);
    JS_FreeContext(ctx);
    _rtMap.remove(rt);
    JS_FreeRuntime(rt);
    assert(() {
      print('vm disposed');
      return true;
    }());
  }

  Timer? _eventLoop;
  void startEventLoop([int ms = 50]) {
    if(_eventLoop == null) {
      _eventLoop = Timer.periodic(Duration(milliseconds: ms), (timer) => executePendingJobs());
    }
  }

  void stopEventLoop() {
    if(_eventLoop != null) {
      _eventLoop!.cancel();
      _eventLoop = null;
    }
  }

  var _fnNextId = 0;
  var _fnMap = new Map<int, JSToDartFunction>();

  /**
   * @hidden
   */

  /// CToHostCallbackFunctionImplementation
  JSValuePointer cToHostCallbackFunction(
    ctx,
    this_ptr,
    argc,
    argv,
    fn_data,
  ) {
    if (ctx != ctx) {
      throw new JSError(
          'QuickJSVm instance received C -> JS call with mismatched ctx');
    }

    final fnId = JS_GetFloat64(ctx, fn_data).toInt();
    final fn = _fnMap[fnId];
    if (fn == null) {
      throw new JSError('QuickJSVm had no callback with id $fnId');
    }

    final thisHandle = this_ptr;
    final List<JSValuePointer> argHandles = [];
    for (int i = 0; i < argc; i++) {
      final ptr = JS_ArgvGetJSValueConstPointer(argv, i);
      argHandles.add(ptr);
    }

    JSValuePointer ownedResultPtr = nullptr;
    try {
      var result = Function.apply(fn, [argHandles], {#thisObj: thisHandle}) as JSValuePointer?;
      if (result != null) {
        _heapValueHandle(result);
        ownedResultPtr = JS_DupValuePointer(ctx, result);
      }
    } catch (error) {
      ownedResultPtr = consumeAndFree(newError(error), (errorHandle) => JS_Throw(ctx, errorHandle));
    }/* finally {
      JS_FreeValuePointer(ctx, this_ptr);
      argHandles.forEach((_) => JS_FreeValuePointer(ctx, _));
    }*/
    return ownedResultPtr /* as JSValuePointer*/;
  }

  /** @hidden */

  /// CToHostInterruptImplementation
  int cToHostInterrupt(rt) {
    if (rt != rt) {
      throw new JSError(
          'QuickJSVm instance received C -> JS interrupt with mismatched rt');
    }

    final fn = _interruptHandler;
    if (fn == null) {
      throw new JSError('QuickJSVm had no interrupt handler');
    }

    return Function.apply(fn, [this]) == true ? 1 : 0;
  }

  /// increase ref_count
  ///
  /// When you want to pass a JSValue(which came from JS) back to JS, you need to duplicate its reference.
  JSValuePointer dupRef(
      JSValuePointer ptr) {
    return _heapValueHandle(JS_DupValuePointer(ctx, ptr));
  }

  void _freeJSValue(JSValuePointer ptr) {
    if(ptr == _undefined || ptr == _null || ptr == _true || ptr == _false) {
      return;
    }
    bool removed = _heapValues.remove(ptr);
    if(!removed) {
      throw 'freeing ptr not hold!';
    }
    JS_FreeValuePointer(ctx, ptr);
  }

  JSValuePointer _heapValueHandle(JSValuePointer ptr) {
    if(ptr == _undefined || ptr == _null || ptr == _true || ptr == _false) {
      return ptr;
    }
    _heapValues.add(ptr);
    return ptr;
  }

  T consumeAndFree<T>(JSValuePointer ptr, T map(JSValuePointer ptr)) {
    try {
      return map(ptr);
    } finally {
      _freeJSValue(ptr);
    }
  }

  Lifetime<JSValueConstPointerPointer> _toPointerArray(
      List<JSValuePointer> array) {
    final JSValueConstPointerPointer ptr =
    calloc.call<JSValueConstPointer>(array.length);
    for (int i = 0; i < array.length; i++) {
      ptr[i] = array[i];
    }
    return _scope.manage(Lifetime(ptr, (ptr) => calloc.free(ptr)));
  }

  Lifetime<JSValuePointerPointer> _newMutablePointerArray(int length) {
    final JSValuePointerPointer ptr = calloc.call<JSValuePointer>(length);
    return _scope.manage(Lifetime(ptr, (value) => calloc.free(value)));
  }

  /// We need to send this into C-land
  /// CToHostCallbackFunctionImplementation
  static JSValuePointer? _cToHostCallbackFunction(
      JSContextPointer ctx,
      JSValuePointer this_ptr,
      int argc,
      JSValuePointer argv,
      JSValuePointer fn_data_ptr) {
    try {
      final vm = _vmMap[ctx];
      if (vm == null) {
        throw new JSError(
            'QuickJSVm(ctx = ${ctx}) not found for C function call "${fn_data_ptr}"');
      }
      return vm.cToHostCallbackFunction(ctx, this_ptr, argc, argv, fn_data_ptr);
    } catch (error) {
      print('[C to host error: returning null]\n$error');
      return nullptr;
    }
  }

  /// CToHostInterruptImplementation
  static int _cToHostInterrupt(JSRuntimePointer rt) {
    try {
      final vm = _rtMap[rt];
      if (vm == null) {
        throw new JSError('QuickJSVm(rt = ${rt}) not found for C interrupt');
      }
      return vm.cToHostInterrupt(rt);
    } catch (error) {
      print('[C to host interrupt: returning error]\n$error');
      return 1;
    }
  }

  /**
   * Returns an interrupt handler that interrupts Javascript execution after a deadline time.
   *
   * @param deadline - Interrupt execution if it's still running after this time.
   *   Number values are compared against `Date.now()`
   */
  static InterruptHandler shouldInterruptAfterDeadline(int deadline) {
    return (vm) => DateTime.now().millisecondsSinceEpoch > deadline;
  }

  /// JSFreeArrayBufferDataFunc
  static void _cToHostArrayBufferFreeCallback(JSRuntimePointer rt, Pointer opaque, Pointer<Uint8> ptr) {
    malloc.free(ptr);
  }
}
