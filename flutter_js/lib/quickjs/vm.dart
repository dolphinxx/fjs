import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../error.dart';
import 'qjs_ffi.dart';
import '../lifetime.dart';
export '../types.dart' show DART_UNDEFINED, JSToDartFunction;

class SuccessOrFail<S, F> {
  S? value;
  F? error;

  SuccessOrFail.value(this.value);

  SuccessOrFail.error(this.error);
}

/**
 * Used as an optional for results of a Vm call.
 * `{ value: VmHandle } | { error: VmHandle }`.
 */
typedef VmCallResult<VmHandle> = SuccessOrFail<VmHandle, VmHandle>;

/**
 * From https://www.figma.com/blog/how-we-built-the-figma-plugin-system/
 */
class VmPropertyDescriptor<VmHandle> {
  VmHandle? value;
  bool? configurable;
  bool? enumerable;
  VmFunctionImplementation? get;
  VmFunctionImplementation? set;

  VmPropertyDescriptor({
    this.value,
    this.configurable,
    this.enumerable,
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

/**
 * QuickJSDeferredPromise wraps a QuickJS promise and allows
 * [[resolve]]ing or [[reject]]ing that promise. Use it to bridge asynchronous
 * code on the host to APIs inside a QuickJSVm.
 *
 * Managing the lifetime of promises is tricky. There are three
 * [[QuickJSHandle]]s inside of each deferred promise object: (1) the promise
 * itself, (2) the `resolve` callback, and (3) the `reject` callback.
 *
 * - If the promise will be fufilled before the end of it's [[owner]]'s lifetime,
 *   the only cleanup necessary is `deferred.handle.dispose()`, because
 *   calling [[resolve]] or [[reject]] will dispose of both callbacks automatically.
 *
 * - As the return value of a [[VmFunctionImplementation]], return [[handle]],
 *   and ensure that either [[resolve]] or [[reject]] will be called. No other
 *   clean-up is necessary.
 *
 * - In other cases, call [[dispose]], which will dispose [[handle]] as well as the
 *   QuickJS handles that back [[resolve]] and [[reject]]. For this object,
 *   [[dispose]] is idempotent.
 */
class QuickJSDeferredPromise implements Disposable {
  final QuickJSVm owner;
  final Lifetime<JSValuePointer> _promise;
  final Lifetime<JSValuePointer> _resolve;
  final Lifetime<JSValuePointer> _reject;

  /**
   * A native promise that will resolve once this deferred is settled.
   */
  late Future<void> settled;
  late void Function() onSettled;

  Lifetime<JSValuePointer> get promise => _promise;

  QuickJSDeferredPromise(
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
    owner
        .unwrapResult(owner.callFunction(this._resolve.value,
            owner.$undefined.value, [value ?? owner.$undefined.value]))
        .dispose();
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
    owner
        .unwrapResult(owner.callFunction(this._reject.value,
            owner.$undefined.value, [value ?? owner.$undefined.value]))
        .dispose();
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

typedef QuickJSHandle = Lifetime<JSValuePointer>;

/**
 * A VmFunctionImplementation takes handles as arguments.
 * It should return a handle, or be void.
 *
 * To indicate an exception, a VMs can throw either a handle (transferred
 * directly) or any other Javascript value (only the poperties `name` and
 * `message` will be transferred). Or, the VmFunctionImplementation may return
 * a VmCallResult's `{ error: handle }` error variant.
 *
 * VmFunctionImplementation should not free its arguments or its return value.
 * It should not retain a reference to its return value or thrown error.
 */
typedef VmFunctionImplementation
    = /*VmHandle | VmCallResult<VmHandle> | void*/ dynamic
        Function(List<JSValuePointer> args, {JSValuePointer? thisObj});

/**
 * Used as an optional for the results of executing pendingJobs.
 * On success, `value` contains the number of async jobs executed
 * by the runtime.
 * `{ value: number } | { error: QuickJSHandle }`.
 */
typedef ExecutePendingJobsResult = SuccessOrFail<int, QuickJSHandle>;

/// TODO: module, console.log, setTimeout
class QuickJSVm implements Disposable {
  static final _vmMap = Map<JSContextPointer, QuickJSVm>();
  static final _rtMap = Map<JSRuntimePointer, QuickJSVm>();
  static bool _initialized = false;

  late final Lifetime<JSRuntimePointer> _rt;
  late final Lifetime<JSContextPointer> _ctx;

  JSRuntimePointer get rt => _rt.value;

  JSContextPointer get ctx => _ctx.value;

  QuickJSHandle? _undefined;
  QuickJSHandle? _null;
  QuickJSHandle? _false;
  QuickJSHandle? _true;
  QuickJSHandle? _global;
  final Scope _scope = new Scope();

  /// Whether to reserve JS undefined using [DART_UNDEFINED].
  bool reserveUndefined = false;
  /// Whether to JSON serialize/deserialize JS object values.
  bool jsonSerializeObject = false;
  /// Whether to auto construct DateTime for JS Date values.
  bool constructDate = true;

  /// Disable Console.log when `kRelease == true`
  bool disableConsoleInRelease = true;

  QuickJSVm() {
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

    _rt = _scope.manage(Lifetime(JS_NewRuntime(), (rt_ptr) {
      _rtMap.remove(rt_ptr);
      JS_FreeRuntime(rt_ptr);
    }));
    _ctx = _scope.manage(Lifetime(JS_NewContext(_rt.value), (ctx_ptr) {
      _vmMap.remove(ctx_ptr);
      JS_FreeContext(ctx_ptr);
    }));
    _vmMap[_ctx.value] = this;
    _rtMap[_rt.value] = this;

    _setupConsole();
  }

  void _setupConsole() {
    Scope.withScope((scope) {
      final QuickJSHandle console = scope.manage(newObject());
      setProperty(global.value, 'console', console.value);
      VmFunctionImplementation logFn = (List<JSValuePointer> args, {JSValuePointer? thisObj}) {
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
      final QuickJSHandle log = scope.manage(newFunction(null, logFn));
      setProperty(console.value, 'log', log.value);
    });
  }

  /**
   * [`undefined`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/undefined).
   */
  QuickJSHandle get $undefined {
    if (_undefined != null) {
      return _undefined!;
    }

    // Undefined is a constant, immutable value in QuickJS.
    final ptr = JS_GetUndefined();
    return (this._undefined = StaticLifetime(ptr));
  }

  /**
   * [`null`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null).
   */
  QuickJSHandle get $null {
    if (this._null != null) {
      return this._null!;
    }

    // Null is a constant, immutable value in QuickJS.
    final ptr = JS_GetNull();
    return (this._null = StaticLifetime(ptr));
  }

  /**
   * [`true`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/true).
   */
  QuickJSHandle get $true {
    if (_true != null) {
      return _true!;
    }

    // True is a constant, immutable value in QuickJS.
    final ptr = JS_GetTrue();
    return (this._true = StaticLifetime(ptr));
  }

  /**
   * [`false`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/false).
   */
  QuickJSHandle get $false {
    if (_false != null) {
      return _false!;
    }

    // False is a constant, immutable value in QuickJS.
    final ptr = JS_GetFalse();
    return (this._false = StaticLifetime(ptr));
  }

  /**
   * [`global`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects).
   * A handle to the global object inside the interpreter.
   * You can set properties to create global variables.
   */
  QuickJSHandle get global {
    if (_global != null) {
      return _global!;
    }

    // The global is a JSValue, but since it's lifetime is as long as the VM's,
    // we should manage it.
    final ptr = JS_GetGlobalObject(ctx);

    // Automatically clean up this reference when we dispose(
    _scope.manage(this._heapValueHandle(ptr));

    // This isn't technically a static lifetime, but since it has the same
    // lifetime as the VM, it's okay to fake one since when the VM is
    // disposed, no other functions will accept the value.
    _global = new StaticLifetime(ptr);
    return _global!;
  }

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
  QuickJSHandle newNumber(num value) {
    return _heapValueHandle(JS_NewFloat64(ctx, value.toDouble()));
  }

  /**
   * Converts `value` into a Dart number.
   * @returns `NaN` on error, otherwise a `number`.
   */
  double? getNumber(JSValuePointer value) {
    return JS_GetFloat64(_ctx.value, value);
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

  QuickJSHandle newString(String value) {
    final utf8str = value.toNativeUtf8();
    final ptr = JS_NewString(ctx, utf8str);
    calloc.free(utf8str);
    return this._heapValueHandle(ptr);
  }

  QuickJSHandle newDate(int timestamp) {
    return _heapValueHandle(JS_NewDate(ctx, timestamp));
  }

  /**
   * `{}`.
   * Create a new QuickJS [object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Object_initializer).
   *
   * @param prototype - Like [`Object.create`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/create).
   */
  QuickJSHandle newObject([JSValuePointer? prototype]) {
    final ptr = prototype != null
        ? JS_NewObjectProto(_ctx.value, prototype)
        : JS_NewObject(_ctx.value);
    return _heapValueHandle(ptr);
  }

  /**
   * `[]`.
   * Create a new QuickJS [array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array).
   */
  QuickJSHandle newArray([List<JSValuePointer>? args]) {
    final ptr = JS_NewArray(_ctx.value);
    if(args != null) {
      for(int i = 0;i<args.length;i++) {
        defineProperty(ptr, i, VmPropertyDescriptor(value: args[i]));
      }
    }
    return _heapValueHandle(ptr);
  }

  QuickJSHandle newArrayBufferCopy(Uint8List value) {
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

  QuickJSHandle newArrayBuffer(Uint8List value,
      [Pointer<NativeFunction<JSFreeArrayBufferDataFunc>>? freeFunc]) {
    final ptr = calloc<Uint8>(value.length);
    final byteList = ptr.asTypedList(value.length);
    byteList.setAll(0, value);
    final ret = JS_NewArrayBuffer(
        ctx, ptr, value.length, freeFunc ?? nullptr, nullptr, 0);
    return Lifetime(ret, (_) {
      // ptr should not be freed until ret disposed since JS_NewArrayBufferNoCopy share the same data.
      calloc.free(ptr);
      _freeJSValue(_);
    });
  }

  QuickJSHandle newError(dynamic error) {
    String? name;
    String? message;
    if (error is JSError) {
      message = error.message;
      name = error.name;
    } else {
      message = error.toString();
    }
    final ptr = JS_NewError(ctx);
    if (name != null) {
      final _k = newString('name');
      final _v = newString(name);
      JS_SetProp(ctx, ptr, _k.value, _v.value);
      _k.dispose();
      _v.dispose();
    }
    final _k = newString('message');
    final _v = newString(message);
    JS_SetProp(ctx, ptr, _k.value, _v.value);
    _k.dispose();
    _v.dispose();
    // final ret = JS_Throw(ctx, ptr);
    // JS_FreeValuePointer(ctx, ptr);
    return _heapValueHandle(ptr);
  }

  JSError? resolveError(Pointer value, [bool sure = false]) {
    JSValuePointer _ = value.cast<JSValueOpaque>();
    if(!sure) {
      final errorPtr = JS_ResolveException(ctx, _);
      if (errorPtr == nullptr) {
        return null;
      }
      _ = errorPtr;
    }
    final str = JS_Dump(ctx, _);
    if(_ != value) {
      JS_FreeValuePointer(ctx, _);
    }
    dynamic e = jsonDecode(str.toDartString());
    if (e is Map && e['message'] is String) {
      JSError error = JSError(e['message']);
      if (e['name'] is String) {
        error.name = e['name'];
      }
      return error;
    }
    return JSError(e.toString());
  }

  QuickJSDeferredPromise newPromise() {
    return Scope.withScope((scope) {
      // Pointer for receiving resolve & reject
      Lifetime<JSValuePointerPointer> resolves =
          scope.manage(_newMutablePointerArray(2));
      final JSValuePointer promise = JS_NewPromiseCapability(
        ctx,
        resolves.value,
      );
      return QuickJSDeferredPromise(
        this,
        _heapValueHandle(promise),
        _heapValueHandle(resolves.value[0]),
        _heapValueHandle(resolves.value[1]),
      );
    });
  }

  /**
   * Convert a Javascript function into a QuickJS function value.
   * See [[VmFunctionImplementation]] for more details.
   *
   * A [[VmFunctionImplementation]] should not free its arguments or its retun
   * value. A VmFunctionImplementation should also not retain any references to
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
   * TODO: remove fn from map which is called only once. ie: onFulfill/onError functions for a JS promise.
   */
  QuickJSHandle newFunction(String? name, VmFunctionImplementation fn) {
    final fnId = ++_fnNextId;
    _fnMap[fnId] = fn;

    final fnIdHandle = newNumber(fnId.toDouble());
    HeapCharPointer namePtr = name == null ? nullptr : name.toNativeUtf8();
    final funcHandle = this._heapValueHandle(
        JS_NewFunction(_ctx.value, fnIdHandle.value, namePtr));
    if(name != null) {
      calloc.free(namePtr);
    }

    // We need to free fnIdHandle's pointer, but not the JSValue, which is retained inside
    // QuickJS for late.
    // malloc.free(fnIdHandle.value);

    return funcHandle;
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
      newString(key).consume((k) => setProp(obj, k.value, value));
      return;
    }
    if(key is num) {
      newNumber(key).consume((k) => setProp(obj, k.value, value));
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
  QuickJSHandle getProp(JSValuePointer obj, JSValueConstPointer key) {
    return _heapValueHandle(JS_GetProp(ctx, obj, key));
  }
  /// [key] is one of String, num or JSValuePointer
  QuickJSHandle getProperty(JSValuePointer obj, dynamic key) {
    if(key is String) {
      return newString(key).consume((k) => getProp(obj, k.value));
    }
    if(key is num) {
      return newNumber(key).consume((k) => getProp(obj, k.value));
    }
    if(!(key is JSValuePointer)) {
      throw JSError('Wrong type for key: ${key.runtimeType}');
    }
    return getProp(obj, key);
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
    Scope.withScope((scope) {
      final value = descriptor.value ?? $undefined.value;
      final configurable = descriptor.configurable == true ? 1 : 0;
      final enumerable = descriptor.enumerable == true ? 1 : 0;
      final hasValue = descriptor.value != null ? 1 : 0;
      final get = descriptor.get != null
          ? scope.manage(
              this.newFunction('' /*descriptor.get.name*/, descriptor.get!))
          : $undefined;
      final set = descriptor.set != null
          ? scope.manage(
              this.newFunction('' /*descriptor.set.name*/, descriptor.set!))
          : $undefined;

      JS_DefineProp(
        _ctx.value,
        obj,
        key,
        value,
        get.value,
        set.value,
        configurable,
        enumerable,
        hasValue,
      );
    });
  }
  /// [key] is one of String, num or JSValuePointer
  void defineProperty(JSValuePointer obj, dynamic key, VmPropertyDescriptor<JSValuePointer> descriptor) {
    if(key is String) {
      newString(key).consume((k) => defineProp(obj, k.value, descriptor));
      return;
    }
    if(key is num) {
      newNumber(key).consume((k) => defineProp(obj, k.value, descriptor));
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
  VmCallResult<QuickJSHandle> callFunction(
    JSValuePointer func,
    JSValuePointer? thisVal,
    List<JSValuePointer> args,
  ) {
    final resultPtr = _toPointerArray(args).consume((argsPtr) => JS_Call(
        ctx, func, thisVal?.cast<JSValueOpaque>()??nullptr, args.length, argsPtr.value));
    final errorPtr = JS_ResolveException(ctx, resultPtr);
    if (errorPtr != nullptr) {
      JS_FreeValuePointer(ctx, resultPtr);
      return VmCallResult.error(this._heapValueHandle(errorPtr));
    }
    return VmCallResult.value(this._heapValueHandle(resultPtr));
  }

  /**
   * Like [`eval(code)`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval#Description).
   * Evauatetes the Javascript source `code` in the global scope of this VM.
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
  VmCallResult<QuickJSHandle> evalCode(String code, {String? filename}) {
    Lifetime<HeapCharPointer> codeHandle = _newHeapCharPointer(code);
    Lifetime<HeapCharPointer>? filenameHandle = _newHeapCharPointer(filename??'<eval.js>');
    late final resultPtr;
    try {
      resultPtr = JS_Eval(_ctx.value, codeHandle.value, codeHandle.value.length, filenameHandle.value, JSEvalFlag.GLOBAL);
    } finally {
      codeHandle.dispose();
      filenameHandle.dispose();
    }
    final errorPtr = JS_ResolveException(_ctx.value, resultPtr);
    if (errorPtr != nullptr) {
      JS_FreeValuePointer(_ctx.value, resultPtr);
      return VmCallResult.error(this._heapValueHandle(errorPtr));
    }
    return VmCallResult.value(this._heapValueHandle(resultPtr));
  }

  /// Auto unwrap `VmCallResult`
  QuickJSHandle evalUnsafe(String code, {String? filename}) {
    return unwrapResult(evalCode(code, filename: filename));
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
  ExecutePendingJobsResult executePendingJobs([int maxJobsToExecute = -1]) {
    final resultValue = this
        ._heapValueHandle(JS_ExecutePendingJob(_rt.value, maxJobsToExecute));
    final typeOfRet = this.typeof(resultValue.value);
    if (typeOfRet == 'number') {
      final executedJobs = this.getNumber(resultValue.value)!.toInt();
      resultValue.dispose();
      return ExecutePendingJobsResult.value(executedJobs);
    } else {
      return ExecutePendingJobsResult.error(resultValue);
    }
  }

  /**
   * In QuickJS, promises and async functions create pendingJobs. These do not execute
   * immediately and need to be run by calling [[executePendingJobs]].
   *
   * @return true if there is at least one pendingJob queued up.
   */
  bool hasPendingJob() {
    return JS_IsJobPending(_rt.value) > 0;
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

    final str = JS_Dump(_ctx.value, value);
    try {
      return jsonDecode(str.toDartString());
    } catch (err) {
      return str;
    }
  }

  /// Convert JS [value] to Dart value.
  ///
  /// **Note:** For `ArrayBuffer` value, the return value is just pointed to the uint8_t* data hold by the js value.
  /// The returned value need to be duplicated(`Uint8List.fromList(..)`) to be available after this js value is freed.
  dynamic jsToDart(JSValuePointer value) {
    if(value == $undefined.value) {
      return reserveUndefined ? DART_UNDEFINED : null;
    }
    if(value == $null.value) {
      return null;
    }
    if(value == $true.value) {
      return true;
    }
    if(value == $false.value) {
      return false;
    }
    final String type = JS_HandyTypeof(ctx, value).toDartString();
    if (type == JSHandyType.js_Error) {
      return resolveError(value, true);
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
        return unwrapResult(callFunction(value, thisObj??nullptr, args)).value/*.consume((_) => jsToDart(_.value))*/;
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
      int length = getProperty(value, 'length')
          .consume((_) => getNumber(_.value)!.toInt());
      List result = [];
      for (int i = 0; i < length; i++) {
        result.add(getProperty(value, i).consume((_) => jsToDart(_.value)));
      }
      return result;
    }
    if(type == JSHandyType.js_Promise) {
      Completer completer = Completer();
      final thenPtr = getProperty(value, 'then');
      final onFulfilled = newFunction(null, (args, {thisObj}) {
        completer.complete(args.isEmpty ? null : jsToDart(args[0]));
      });
      final onError = newFunction(null, (args, {thisObj}) {
        var error = jsToDart(args[0]);
        completer.completeError(error is JSError ? error : JSError(error.toString()));
      });
      try {
        callFunction(thenPtr.value, value, [onFulfilled.value, onError.value]);
        executePendingJobs();
        // complete when the promise is resolved/rejected.
        return completer.future;
      } finally {
        onFulfilled.dispose();
        onError.dispose();
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
        _freeJSValue(atomStr);
        final propValue = JS_GetProperty(ctx, value, atom);
        result[key] = jsToDart(propValue);
        _freeJSValue(propValue);
      }
      calloc.free(atomsPtr);
      return result;
    }
    // fallback
    final str = JS_Dump(_ctx.value, value);
    try {
      return jsonDecode(str.toDartString());
    } catch (err) {
      return str;
    }
  }

  /// If [value] is dart function, it must be able to cast to [VmFunctionImplementation].
  ///
  /// [value] must be able to be serialize to JSON through `jsonEncode` if it is not one of the supported types.
  QuickJSHandle dartToJS(dynamic value) {
    if(value is QuickJSHandle) {
      return value;
    }
    if(value is Pointer) {
      return _heapValueHandle(value as JSValuePointer);
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
      return newFunction(null, value as VmFunctionImplementation);
    }
    if(value is DateTime) {
      if(constructDate) {
        return newDate(value.millisecondsSinceEpoch);
      }
      return newNumber(value.millisecondsSinceEpoch);
    }
    if(value is TypedData && value is List<int>) {
      return newArrayBuffer(value is Uint8List ? value : value.buffer.asUint8List());
    }
    if(value is List) {
      return Scope.withScope((scope) {
        final result = newArray(value.map((e) => scope.manage(dartToJS(e)).value).toList());
        // final array = result.value;
        // for(int i = 0;i<value.length;i++) {
        //   dartToJS(value[i]).consume((lifetime) => defineProperty(array, i, VmPropertyDescriptor(value: lifetime.value)));
        // }
        return result;
      });
    }
    if(value is Future) {
      final promise = newPromise();
      QuickJSHandle result = promise.promise;
      value.then((_) => dartToJS(_).consume((lifetime) => promise.resolve(lifetime.value)))
      .catchError((_) => dartToJS(_).consume((lifetime) => promise.reject(lifetime.value)));
      return result;
    }
    if(value is Map) {
      final result = newObject();
      JSValuePointer obj = result.value;
      value.forEach((key, value) {
        dartToJS(value).consume((lifetime) => defineProperty(obj, key, VmPropertyDescriptor(value: lifetime.value)));
      });
      return result;
    }
    // fallback
    String json = jsonEncode(value);
    return evalUnsafe('($json)');
  }

  /**
   * Unwrap a SuccessOrFail result such as a [[VmCallResult]] or a
   * [[ExecutePendingJobsResult]], where the fail branch contains a handle to a QuickJS error value.
   * If the result is a success, returns the value.
   * If the result is an error, converts the error to a native object and throws the error.
   */
  T unwrapResult<T>(SuccessOrFail<T, QuickJSHandle> result) {
    if (result.error != null) {
      final err = result.error!.consume((error) => resolveError(error.value, true));
      if (err != null) {
        throw err;
      }
    }
    return result.value!;
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
      JS_RuntimeEnableInterruptHandler(_rt.value);
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

    JS_RuntimeSetMemoryLimit(_rt.value, limitBytes);
  }

  /**
   * Compute memory usage for this runtime. Returns the result as a handle to a
   * JSValue object. Use [[dump]] to convert to a native object.
   * Calling this method will allocate more memory inside the runtime. The information
   * is accurate as of just before the call to `computeMemoryUsage`.
   * For a human-digestable representation, see [[dumpMemoryUsage]].
   */
  QuickJSHandle computeMemoryUsage() {
    return this
        ._heapValueHandle(JS_RuntimeComputeMemoryUsage(_rt.value, _ctx.value));
  }

  /**
   * @returns a human-readable description of memory usage in this runtime.
   * For programatic access to this information, see [[computeMemoryUsage]].
   */
  String dumpMemoryUsage() {
    try {
      HeapCharPointer result = JS_RuntimeDumpMemoryUsage(_rt.value, 1024);
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
      JS_RuntimeDisableInterruptHandler(_rt.value);
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
    this._scope.dispose();
  }

  var _fnNextId = 0;
  var _fnMap = new Map<int, VmFunctionImplementation>();

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
    if (ctx != _ctx.value) {
      throw new JSError(
          'QuickJSVm instance received C -> JS call with mismatched ctx');
    }

    final fnId = JS_GetFloat64(ctx, fn_data).toInt();
    final fn = _fnMap[fnId];
    if (fn == null) {
      throw new JSError('QuickJSVm had no callback with id $fnId');
    }

    return Scope.withScope((scope) {
      final thisHandle = scope.manage(
          WeakLifetime<JSValuePointer>(this_ptr, _freeJSValue)).value;
      final List<JSValuePointer> argHandles = [];
      for (int i = 0; i < argc; i++) {
        final ptr = JS_ArgvGetJSValueConstPointer(argv, i);
        argHandles.add(scope.manage(WeakLifetime(ptr, _freeJSValue)).value);
      }

      JSValuePointer ownedResultPtr = nullptr;
      try {
        // result type: VmHandle | VmCallResult<VmHandle> | void
        var result = Function.apply(fn, [argHandles], {#thisObj: thisHandle});
        if (result != null) {
          if (result is VmCallResult && result.error != null) {
            throw result.error;
          }
          final handle = scope.manage<Lifetime>(result is Lifetime
              ? result
              : (result as VmCallResult<Lifetime>).value as Lifetime);
          ownedResultPtr = JS_DupValuePointer(_ctx.value, handle.value);
        }
      } catch (error) {
        ownedResultPtr = _errorToHandle(error)
            .consume((errorHandle) => JS_Throw(_ctx.value, errorHandle.value));
      }
      return ownedResultPtr /* as JSValuePointer*/;
    });
  }

  /** @hidden */

  /// CToHostInterruptImplementation
  int cToHostInterrupt(rt) {
    if (rt != _rt.value) {
      throw new JSError(
          'QuickJSVm instance received C -> JS interrupt with mismatched rt');
    }

    final fn = _interruptHandler;
    if (fn == null) {
      throw new JSError('QuickJSVm had no interrupt handler');
    }

    return Function.apply(fn, [this]) == true ? 1 : 0;
  }

  Lifetime<JSValuePointer> copyJSValue(
      JSValuePointer/* | JSValueConstPointer*/ ptr) {
    return _heapValueHandle(JS_DupValuePointer(_ctx.value, ptr));
  }

  void _freeJSValue(JSValuePointer ptr) {
    JS_FreeValuePointer(_ctx.value, ptr);
  }

  Lifetime<JSValuePointer> _heapValueHandle(JSValuePointer ptr) {
    return _scope.manage(Lifetime(ptr, _freeJSValue));
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

  Lifetime<HeapCharPointer> _newHeapCharPointer(String string) {
    Pointer<Utf8> ptr = string.toNativeUtf8();
    return _scope.manage(Lifetime(ptr, (value) => calloc.free(value)));
  }

  Lifetime _errorToHandle(dynamic /*Error | QuickJSHandle*/ error) {
    if (error is Lifetime) {
      return error;
    }
    final err = newError(error);

    // // Disabled due to security leak concerns
    // if (error.stack != undefined) {
    //   //const handle = this.newString(error.stack)
    //   // Set to fullStack...? For debugging.
    //   //this.setProp(errorHandle, 'fullStack', handle)
    //   //handle.dispose()
    // }

    return err;
  }

  // InterruptHandler? _interruptHandler;
  //
  // /**
  //  * Set a callback which is regularly called by the QuickJS engine when it is
  //  * executing code. This callback can be used to implement an execution
  //  * timeout.
  //  *
  //  * The interrupt handler can be removed with [[removeInterruptHandler]].
  //  */
  // void setInterruptHandler(InterruptHandler cb) {
  //   final prevInterruptHandler = _interruptHandler;
  //   _interruptHandler = cb;
  //   if (prevInterruptHandler == null) {
  //     JS_RuntimeEnableInterruptHandler(this._rt.value);
  //   }
  // }
  //
  // var _fnNextId = 0;
  // var _fnMap = new Map<int, VmFunctionImplementation>();
  //
  // /**
  //  * @hidden
  //  */
  //
  // /// CToHostCallbackFunctionImplementation
  // JSValuePointer cToHostCallbackFunction(JSContextPointer ctx,
  //     JSValuePointer this_ptr, int argc, JSValuePointer argv, JSValuePointer fn_data_ptr) {
  //   if (ctx != _ctx.value) {
  //     throw new JSError(
  //         'QuickJSVm instance received C -> JS call with mismatched ctx');
  //   }
  //
  //   final fnId = JS_GetFloat64(ctx, fn_data_ptr);
  //   final fn = _fnMap[fnId];
  //   if (fn == null) {
  //     throw new JSError('QuickJSVm had no callback with id $fnId');
  //   }
  //
  //   return Scope.withScope((scope) {
  //     final QuickJSHandle thisHandle = scope
  //         .manage(new WeakLifetime(this_ptr, _freeJSValue, this));
  //     final List<QuickJSHandle> argHandles = [];
  //     for (int i = 0; i < argc; i++) {
  //       final ptr = JS_ArgvGetJSValueConstPointer(argv, i);
  //       argHandles.add(scope
  //           .manage(new WeakLifetime<JSValuePointer>(ptr.cast<JSValueOpaque>(), _freeJSValue, this)));
  //     }
  //
  //     JSValuePointer ownedResultPtr = nullptr;
  //     try {
  //       // result type: VmHandle | VmCallResult<VmHandle> | void
  //       var result = Function.apply(fn, [argHandles], {#thisObj: thisHandle});
  //       if (result != null) {
  //         if (result is VmCallResult && result.error != null) {
  //           throw result.error;
  //         }
  //         final handle = scope.manage<Lifetime>(result is Lifetime
  //             ? result
  //             : (result as VmCallResult<Lifetime>).value as Lifetime);
  //         ownedResultPtr = JS_DupValuePointer(_ctx.value, handle.value);
  //       }
  //     } catch (error) {
  //       ownedResultPtr = _errorToHandle(error).value;
  //     }
  //
  //     return ownedResultPtr /* as JSValuePointer*/;
  //   });
  // }
  //
  // /** @hidden */
  //
  // /// CToHostInterruptImplementation
  // int cToHostInterrupt(rt) {
  //   if (rt != this._rt.value) {
  //     throw new JSError(
  //         'QuickJSVm instance received C -> JS interrupt with mismatched rt');
  //   }
  //
  //   final fn = _interruptHandler;
  //   if (fn == null) {
  //     throw new JSError('QuickJSVm had no interrupt handler');
  //   }
  //
  //   return Function.apply(fn, [this]) == true ? 1 : 0;
  // }

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
}
