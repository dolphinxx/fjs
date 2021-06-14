import 'dart:ffi';

import 'dart:io';

import 'package:ffi/ffi.dart';

import '../types.dart';
export '../types.dart';

DynamicLibrary? _qjsLib;

const _dylibFilename = 'libquickjs';
String? getDylibPath() {
  if(Platform.environment.containsKey('FLUTTER_TEST')) {
    if(Platform.isWindows) {
      return Platform.environment['QUICKJS_TEST_PATH'] ?? '$_dylibFilename.dll';
    }
    if(Platform.isLinux) {
      return Platform.environment['QUICKJS_TEST_PATH'] ?? '$_dylibFilename.so';
    }
    // Only support windows and linux in test mode
    return null;
  }
  if(Platform.isWindows) {
    return '$_dylibFilename.dll';
  }
  if(Platform.isLinux || Platform.isAndroid) {
    return '$_dylibFilename.so';
  }
  return null;
}

DynamicLibrary get dylib {
  if (_qjsLib != null) {
    return _qjsLib!;
  }
  String? dylibPath = getDylibPath();
  _qjsLib = dylibPath == null ? DynamicLibrary.process() : DynamicLibrary.open(dylibPath);
  return _qjsLib!;
}

abstract class JSRuntimeOpaque extends Opaque {}

typedef JSAtom = Uint32;

/**
 * `JSRuntime*`.
 */
typedef JSRuntimePointer = Pointer<JSRuntimeOpaque>;

typedef C_To_HostCallbackFunc = JSValuePointer? Function(JSContextPointer ctx, JSValuePointer this_ptr, Uint32 argc, JSValuePointer argv,
    JSValuePointer fn_data_ptr);

/**
 * Used internally for C-to-Javascript function calls.
 */
typedef QJS_C_To_HostCallbackFuncPointer = Pointer<
    NativeFunction<C_To_HostCallbackFunc> /*'C_To_HostCallbackFunc'*/ >;

/**
 * Used internally for C-to-Javascript interrupt handlers.
 */
typedef QJS_C_To_HostInterruptFuncPointer = Pointer<
    NativeFunction<
        Uint32 Function(JSRuntimePointer)> /*'C_To_HostInterruptFunc'*/ >;

/// void JSFreeArrayBufferDataFunc(JSRuntime *rt, void *opaque, void *ptr)
typedef JSFreeArrayBufferDataFunc = Void Function(JSRuntimePointer rt, Pointer opaque, Pointer<Uint8> ptr);

abstract class JSEvalFlag {
  static const GLOBAL = 0 << 0;/* global code (default) */
  static const MODULE = 1 << 0;/* module code */
}

abstract class JSProp {
  static const CONFIGURABLE = (1 << 0);
  static const WRITABLE = (1 << 1);
  static const ENUMERABLE = (1 << 2);
  static const C_W_E = (CONFIGURABLE | WRITABLE | ENUMERABLE);
}

abstract class JSTag {
  static const FIRST = -11; /* first negative tag */
  static const BIG_DECIMAL = -11;
  static const BIG_INT = -10;
  static const BIG_FLOAT = -9;
  static const SYMBOL = -8;
  static const STRING = -7;
  static const MODULE = -3; /* used internally */
  static const FUNCTION_BYTECODE = -2; /* used internally */
  static const OBJECT = -1;

  static const INT = 0;
  static const BOOL = 1;
  static const NULL = 2;
  static const UNDEFINED = 3;
  static const UNINITIALIZED = 4;
  static const CATCH_OFFSET = 5;
  static const EXCEPTION = 6;
  static const FLOAT64 = 7;
}

/// const char* hello_world()
final hello_world = dylib.lookupFunction<
    HeapCharPointer Function(),
    HeapCharPointer Function()>("hello_world");

final JS_SetHostCallback = dylib.lookupFunction<
    Void Function(QJS_C_To_HostCallbackFuncPointer),
    void Function(
        QJS_C_To_HostCallbackFuncPointer fp)>("QJS_SetHostCallback");

final JS_ArgvGetJSValueConstPointer = dylib.lookupFunction<
    JSValueConstPointer Function(Pointer, Uint32),
    JSValueConstPointer Function(
        JSValuePointer/* | JSValueConstPointer*/ argv,
        int index)>("QJS_ArgvGetJSValueConstPointer");

final JS_NewFunction = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, Pointer, HeapCharPointer),
    JSValuePointer Function(
        JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ func_data,
        HeapCharPointer)>("QJS_NewFunction");

final JS_Throw = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, Pointer),
    JSValuePointer Function(JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ error)>(
    "QJS_Throw");

final JS_NewError = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer),
    JSValuePointer Function(JSContextPointer ctx)>("QJS_NewError");

final JS_SetInterruptCallback = dylib.lookupFunction<
    Void Function(QJS_C_To_HostInterruptFuncPointer),
    void Function(
        QJS_C_To_HostInterruptFuncPointer cb)>("QJS_SetInterruptCallback");

final JS_RuntimeEnableInterruptHandler = dylib.lookupFunction<
    Void Function(JSRuntimePointer),
    void Function(JSRuntimePointer rt)>("QJS_RuntimeEnableInterruptHandler");

final JS_RuntimeDisableInterruptHandler = dylib.lookupFunction<
    Void Function(JSRuntimePointer),
    void Function(
        JSRuntimePointer rt)>("QJS_RuntimeDisableInterruptHandler");

final JS_RuntimeSetMemoryLimit = dylib.lookupFunction<
    Void Function(JSRuntimePointer, Uint32),
    void Function(
        JSRuntimePointer rt, int limit)>("QJS_RuntimeSetMemoryLimit");

final JS_RuntimeComputeMemoryUsage = dylib.lookupFunction<
    JSValuePointer Function(JSRuntimePointer, JSContextPointer),
    JSValuePointer Function(JSRuntimePointer rt,
        JSContextPointer ctx)>("QJS_RuntimeComputeMemoryUsage");

final JS_RuntimeDumpMemoryUsage = dylib.lookupFunction<
    HeapCharPointer Function(JSRuntimePointer, Uint32),
    HeapCharPointer Function(
        JSRuntimePointer rt, int size)>("QJS_RuntimeDumpMemoryUsage");

final JS_GetUndefined = dylib.lookupFunction<JSValueConstPointer Function(),
    JSValueConstPointer Function()>("QJS_GetUndefined");

final JS_GetNull = dylib.lookupFunction<JSValueConstPointer Function(),
    JSValueConstPointer Function()>("QJS_GetNull");

final JS_GetFalse = dylib.lookupFunction<JSValueConstPointer Function(),
    JSValueConstPointer Function()>("QJS_GetFalse");

final JS_GetTrue = dylib.lookupFunction<JSValueConstPointer Function(),
    JSValueConstPointer Function()>("QJS_GetTrue");

/// JSValue *QJS_NewBool(JSContext *ctx, int32_t val)
final JS_NewBool = dylib.lookupFunction<
  JSValuePointer Function(JSContextPointer, Int32),
  JSValuePointer Function(JSContextPointer, int)
>('QJS_NewBool');

final JS_NewRuntime = dylib.lookupFunction<JSRuntimePointer Function(),
    JSRuntimePointer Function()>("QJS_NewRuntime");

final JS_FreeRuntime = dylib.lookupFunction<Void Function(JSRuntimePointer),
    void Function(JSRuntimePointer rt)>("QJS_FreeRuntime");

final JS_NewContext = dylib.lookupFunction<
    JSContextPointer Function(JSRuntimePointer),
    JSContextPointer Function(JSRuntimePointer rt)>("QJS_NewContext");

final JS_FreeContext = dylib.lookupFunction<Void Function(JSContextPointer),
    void Function(JSContextPointer ctx)>("QJS_FreeContext");

final JS_FreeValuePointer = dylib.lookupFunction<
    Void Function(JSContextPointer, JSValuePointer),
    void Function(
        JSContextPointer ctx, JSValuePointer value)>("QJS_FreeValuePointer");

/// This operation just increase the `ref_count` to the [val], thus feel free to call it anytime.
final JS_DupValuePointer = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, Pointer),
    JSValuePointer Function(JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ val)>(
    "QJS_DupValuePointer");

final JS_NewObject = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer),
    JSValuePointer Function(JSContextPointer ctx)>("QJS_NewObject");

final JS_NewObjectProto = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, Pointer),
    JSValuePointer Function(JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ proto)>(
    "QJS_NewObjectProto");

final JS_NewArray = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer),
    JSValuePointer Function(JSContextPointer ctx)>("QJS_NewArray");

final JS_NewFloat64 = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, Double),
    JSValuePointer Function(
        JSContextPointer ctx, double num)>("QJS_NewFloat64");

final JS_GetFloat64 = dylib.lookupFunction<
    Double Function(JSContextPointer, Pointer),
    double Function(JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ value)>(
    "QJS_GetFloat64");

final JS_NewString = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, HeapCharPointer),
    JSValuePointer Function(
        JSContextPointer ctx, HeapCharPointer string)>("QJS_NewString");

final JS_GetString = dylib.lookupFunction<
    HeapCharPointer Function(JSContextPointer, Pointer),
    HeapCharPointer Function(JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ value)>(
    "QJS_GetString");

final JS_IsJobPending = dylib.lookupFunction<
    Uint32 Function(JSRuntimePointer),
    int Function(JSRuntimePointer rt)>("QJS_IsJobPending");

final JS_ExecutePendingJob = dylib.lookupFunction<
    JSValuePointer Function(JSRuntimePointer rt, Uint32 maxJobsToExecute),
    JSValuePointer Function(
        JSRuntimePointer rt, int maxJobsToExecute)>("QJS_ExecutePendingJob");

final JS_GetProp = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, Pointer, Pointer),
    JSValuePointer Function(
        JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ this_val,
        /*JSValuePointer | */JSValueConstPointer prop_name)>(
    "QJS_GetProp");

final JS_SetProp = dylib.lookupFunction<
    Void Function(JSContextPointer, Pointer, Pointer, Pointer),
    void Function(
        JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ this_val,
        /*JSValuePointer | */JSValueConstPointer prop_name,
        JSValuePointer/* | JSValueConstPointer*/ prop_value)>(
    "QJS_SetProp");

/// void QJS_DefineProp(JSContext *ctx, JSValueConst *this_val, JSValueConst *prop_name, JSValueConst *prop_value, JSValueConst *get, JSValueConst *set, bool configurable, bool enumerable, bool writable, bool has_value)
final JS_DefineProp = dylib.lookupFunction<
    Void Function(JSContextPointer, Pointer, Pointer, Pointer, Pointer,
        Pointer, Int32 configurable, Int32 enumerable, Int32 writable, Int32 has_value),
    void Function(
        JSContextPointer ctx,
        JSValuePointer this_val,
        JSValueConstPointer prop_name,
        JSValuePointer prop_value,
        JSValuePointer get,
        JSValuePointer set,
        int configurable,
        int enumerable,
        int writable,
        int has_value)>("QJS_DefineProp");

/// JSValue *QJS_Call(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj, int argc, JSValueConst **argv_ptrs)
final JS_Call = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, Pointer, Pointer, Int32 argc,
        JSValueConstPointerPointer argv_ptrs),
    JSValuePointer Function(
        JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ func_obj,
        JSValuePointer/* | JSValueConstPointer*/ this_obj,
        int argc,
        JSValueConstPointerPointer argv_ptrs)>("QJS_Call");
/// void QJS_Call(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj, int argc, JSValueConst **argv_ptrs)
final JS_CallVoid = dylib.lookupFunction<
    Void Function(JSContextPointer, Pointer, Pointer, Int32 argc,
        JSValueConstPointerPointer argv_ptrs),
    void Function(
        JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ func_obj,
        JSValuePointer/* | JSValueConstPointer*/ this_obj,
        int argc,
        JSValueConstPointerPointer argv_ptrs)>("QJS_CallVoid");

final JS_ResolveException = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, JSValuePointer),
    JSValuePointer Function(JSContextPointer ctx,
        JSValuePointer maybe_exception)>("QJS_ResolveException");

final JS_Dump = dylib.lookupFunction<
    HeapCharPointer Function(JSContextPointer, Pointer),
    HeapCharPointer Function(JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ obj)>("QJS_Dump");

/// JSValue *QJS_Eval(JSContext *ctx, HeapChar *js_code, size_t js_code_len, HeapChar *filename, int eval_flags)
final JS_Eval = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, HeapCharPointer, IntPtr, HeapCharPointer, Int8),
    JSValuePointer Function(
        JSContextPointer ctx, HeapCharPointer js_code, int js_code_len, HeapCharPointer filename, int eval_flags)>("QJS_Eval");

final JS_Typeof = dylib.lookupFunction<
    HeapCharPointer Function(JSContextPointer, Pointer),
    HeapCharPointer Function(JSContextPointer ctx,
        JSValuePointer/* | JSValueConstPointer*/ value)>(
    "QJS_Typeof");

final JS_GetGlobalObject = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer),
    JSValuePointer Function(JSContextPointer ctx)>("QJS_GetGlobalObject");

final JS_NewPromiseCapability = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer, JSValuePointerPointer),
    JSValuePointer Function(
        JSContextPointer ctx, JSValuePointerPointer resolve_funcs_out)>(
    "QJS_NewPromiseCapability");

/// JSValue *QJS_NewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len)
final JS_NewArrayBufferCopy = dylib.lookupFunction<
  JSValuePointer Function(JSContextPointer, Pointer<Uint8>, IntPtr),
  JSValuePointer Function(JSContextPointer ctx, Pointer<Uint8> buf, int len)
  >("QJS_NewArrayBufferCopy");

///
/// JSValue *QJS_NewArrayBuffer(JSContext *ctx, uint8_t *buf, size_t len, JSFreeArrayBufferDataFunc *free_func, void *opaque, int is_shared)
final JS_NewArrayBuffer = dylib.lookupFunction<
  JSValuePointer Function(JSContextPointer, Pointer<Uint8>, IntPtr, Pointer<NativeFunction<JSFreeArrayBufferDataFunc>>, Pointer, Uint32),
  JSValuePointer Function(JSContextPointer ctx, Pointer<Uint8> buf, int len, Pointer<NativeFunction<JSFreeArrayBufferDataFunc>> free_func, Pointer opaque, int is_shared)
>("QJS_NewArrayBuffer");

/// Get a Pointer to the underlying C `uint8_t*` backed by the ArrayBuffer, return NULL if exception.
///
/// **WARNING:** any JS call can detach the buffer and render the returned pointer invalid
///
/// uint8_t* QJS_GetArrayBuffer(JSContext* ctx, size_t* psize, JSValueConst* obj)
final JS_GetArrayBuffer = dylib.lookupFunction<
  Pointer<Uint8> Function(JSContextPointer, Pointer<IntPtr>, JSValuePointer),
  Pointer<Uint8> Function(JSContextPointer ctx, Pointer<IntPtr> psize, JSValuePointer obj)
>('QJS_GetArrayBuffer');

/// int QJS_ToBool(JSContext *ctx, JSValueConst *val)
final JS_ToBool = dylib.lookupFunction<
  Uint32 Function(JSContextPointer, JSValueConstPointer),
  int Function(JSContextPointer ctx, JSValueConstPointer val)
>('QJS_ToBool');

/// return -1 if exception (proxy case) or TRUE/FALSE
///
///   int QJS_IsArray(JSContext *ctx, JSValueConst *val)
final JS_IsArray = dylib.lookupFunction<
    Uint32 Function(JSContextPointer, JSValueConstPointer),
    int Function(JSContextPointer ctx, JSValueConstPointer val)
>('QJS_IsArray');

class JSPropertyEnum extends Struct {
  @Uint32()
  external int is_enumerable;
  @Uint32()
  external int atom;
}

const int JS_GPN_STRING_MASK = 1 << 0;
const int JS_GPN_SYMBOL_MASK = 1 << 1;
/// Only include the enumerable properties
const int JS_GPN_ENUM_ONLY = 1 << 4;
/// Only include copyable properties
const int JS_GPN_COPYABLE = JS_GPN_STRING_MASK | JS_GPN_SYMBOL_MASK | JS_GPN_ENUM_ONLY;

/// `int QJS_GetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab, uint32_t *plen, JSValueConst obj, int flags)`
///
/// Address of `JSPropertyEnum *tab_atom` is stored in [ptab].
///
/// [flags] filters the propertyName included. see [JS_GPN_STRING_MASK], [JS_GPN_SYMBOL_MASK], [JS_GPN_ENUM_ONLY].
///
/// **Note:** Remember to free atoms in [ptab](`JS_FreeAtom(ctx, ptab[i].atom`)) and [ptab](`js_free(ctx, ptab)`).
final JS_GetOwnPropertyNames = dylib.lookupFunction<
  Uint32 Function(JSContextPointer, Pointer<IntPtr> ptab, Pointer<Uint32> plen, JSValueConstPointer obj, Uint32 flags),
  int Function(JSContextPointer ctx, Pointer<IntPtr> ptab, Pointer<Uint32> plen, JSValueConstPointer obj, int flags)
>('QJS_GetOwnPropertyNames');

/// `int QJS_GetOwnPropertyNameAtoms(JSContext *ctx, intptr_t* patoms, JSValueConst *obj, int flags)`
///
/// [patoms]
///
/// [flags] filters the propertyName included. see [JS_GPN_STRING_MASK], [JS_GPN_SYMBOL_MASK], [JS_GPN_ENUM_ONLY].
///
/// If error occurred -1 is returned. Otherwise the size of atoms is returned.
final JS_GetOwnPropertyNameAtoms = dylib.lookupFunction<
    Uint32 Function(JSContextPointer, Pointer<IntPtr>, JSValueConstPointer, Uint32),
    int Function(JSContextPointer ctx, Pointer<IntPtr> patoms, JSValueConstPointer obj, int flags)
>('QJS_GetOwnPropertyNameAtoms');

/// void QJS_FreePropEnum(JSContext *ctx, JSPropertyEnum *tab, uint32_t len)
final JS_FreePropEnum = dylib.lookupFunction<
  Void Function(JSContextPointer, Pointer tab, Uint32 len),
  void Function(JSContextPointer, Pointer tab, int len)
>('QJS_FreePropEnum');

/// JSValue *QJS_AtomToString(JSContext *ctx, JSAtom atom)
final JS_AtomToString = dylib.lookupFunction<
  JSValuePointer Function(JSContextPointer, JSAtom),
  JSValuePointer Function(JSContextPointer, int)
>('QJS_AtomToString');

/// JSValue *QJS_GetProperty(JSContext *ctx, JSValueConst *this_obj, JSAtom prop)
final JS_GetProperty = dylib.lookupFunction<
  JSValuePointer Function(JSContextPointer, JSValueConstPointer, JSAtom),
  JSValuePointer Function(JSContextPointer, JSValueConstPointer, int)
>('QJS_GetProperty');

/// int QJS_HasProp(JSContext* ctx, JSValueConst* this_obj, JSValueConst *prop_name)
final JS_HasProp = dylib.lookupFunction<
  Int8 Function(JSContextPointer, JSValueConstPointer, JSValueConstPointer),
  int Function(JSContextPointer ctx, JSValueConstPointer this_obj, JSValueConstPointer prop)
>('QJS_HasProp');

/// int QJS_HasProperty(JSContext* ctx, JSValueConst *this_obj, JSAtom prop)
final JS_HasProperty = dylib.lookupFunction<
  Int8 Function(JSContextPointer, JSValueConstPointer, JSAtom),
  int Function(JSContextPointer ctx, JSValueConstPointer this_obj, int prop)
>('QJS_HasProperty');

abstract class JSHandyType {
  static const int js_unknown = 0/*'unknown'*/;
  static const int js_uninitialized = -1/*'uninitialized'*/;
  static const int js_undefined = 1/*'undefined'*/;
  static const int js_null = 2/*'null'*/;
  /// primitive bool
  static const int js_boolean = 3/*'boolean'*/;
  /// primitive string
  static const int js_string = 4/*'string'*/;
  static const int js_Symbol = 5/*'Symbol'*/;
  static const int js_function = 6/*'function'*/;
  static const int js_int = 7/*'int'*/;
  /// **Note:** `1.0` is treated int in QuickJS.
  static const int js_float = 8/*'float'*/;
  static const int js_BigInt = 9/*'BigInt'*/;
  static const int js_BigFloat = 10/*'BigFloat'*/;
  static const int js_BigDecimal = 11/*'BigDecimal'*/;
  static const int js_Promise = 12/*'Promise'*/;
  static const int js_ArrayBuffer = 13/*'ArrayBuffer'*/;
  static const int js_SharedArrayBuffer = 14/*'SharedArrayBuffer'*/;
  static const int js_Date = 15/*'Date'*/;
  /// object instanceof String
  static const int js_String = 16/*'String'*/;
  /// object instanceof Number
  static const int js_Number = 17/*'Number'*/;
  /// object instanceof Boolean
  static const int js_Boolean = 18/*'Boolean'*/;
  static const int js_Error = 19/*'Error'*/;
  static const int js_RegExp = 20/*'RegExp'*/;
  static const int js_Array = 21/*'Array'*/;
  /// all other object values not listed above.
  static const int js_object = 22/*'object'*/;
  /// True if a dart `int` is enough to present [type].
  static bool isIntLike(int type) {
    return type == js_int || type == js_BigInt;
  }
  /// True if a dart `double` is required to present [type].
  static bool isDoubleLike(int type) {
    return type == js_float || type == js_BigFloat || type == js_BigDecimal;
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

/// int8_t QJS_HandyTypeof(JSContext *ctx, JSValueConst *value)
final JS_HandyTypeof = dylib.lookupFunction<
  Int8 Function(JSContextPointer, JSValueConstPointer),
  int Function(JSContextPointer ctx, JSValueConstPointer obj)
>('QJS_HandyTypeof');

/// JSValue* QJS_NewDate(JSContext* ctx, int64_t timestamp)
final JS_NewDate = dylib.lookupFunction<
  JSValuePointer Function(JSContextPointer, Int64),
  JSValuePointer Function(JSContextPointer ctx, int timestamp)
>('QJS_NewDate');

/// void QJS_ToConstructor(JSContext* ctx, JSValueConst *func_obj)
final JS_ToConstructor = dylib.lookupFunction<
  Void Function(JSContextPointer, JSValuePointer),
  void Function(JSContextPointer, JSValuePointer)
>('QJS_ToConstructor');

/// JSValue* QJS_CallConstructor(JSContext* ctx, JSValueConst *func_obj, int argc, JSValueConst** argv_ptrs)
final JS_CallConstructor = dylib.lookupFunction<
  JSValuePointer Function(JSContextPointer, JSValuePointer, Int32, JSValuePointerPointer),
  JSValuePointer Function(JSContextPointer ctx, JSValuePointer func_obj, int argc, JSValuePointerPointer argv_ptrs)
>('QJS_CallConstructor');

/// Get the pending exception.
///
/// Call it only when you pretty sure there is an exception.
///
/// JSValue* QJS_GetException(JSContext *ctx)
final JS_GetException = dylib.lookupFunction<
    JSValuePointer Function(JSContextPointer),
    JSValuePointer Function(JSContextPointer ctx)
>('QJS_GetException');

/// typedef uint8_t QJS_Module_Loader(JSContext* ctx, char** buff, size_t *len, const char* module_name)
typedef QJS_Module_Loader = Uint8 Function(JSContextPointer ctx, Pointer<Pointer<Utf8>> buffPointer, Pointer<IntPtr> lenPointer, Pointer<Utf8> module_name);
typedef QJS_Module_Loader_Dart = int Function(JSContextPointer ctx, Pointer<Pointer<Utf8>> buffPointer, Pointer<IntPtr> lenPointer, Pointer<Utf8> module_name);

/// Set a global module handler.
///
/// **Note:** The eval flag must include JS_EVAL_TYPE_MODULE to support JS `import` syntax,
/// and in this mode the return value is always `undefined`
///
/// void QJS_SetModuleLoaderFunc(JSRuntime* rt, QJS_Module_Loader *handler)
final JS_SetModuleLoaderFunc = dylib.lookupFunction<
  Void Function(JSRuntimePointer, Pointer<NativeFunction<QJS_Module_Loader>>),
  void Function(JSRuntimePointer rt, Pointer<NativeFunction<QJS_Module_Loader>> loader)
>('QJS_SetModuleLoaderFunc');