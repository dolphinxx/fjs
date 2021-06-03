import 'dart:ffi';

import 'package:ffi/ffi.dart';

abstract class JSValueOpaque extends Opaque {}

typedef JSValueConstOpaque = JSValueOpaque;
// abstract class JSValueConstOpaque extends Opaque {}

abstract class JSCFunctionOpaque extends Opaque {}

abstract class JSContextOpaque extends Opaque {}

/**
 * Used internally for C-to-Javascript function calls.
 */
typedef JSCFunctionPointer = Pointer<JSCFunctionOpaque>;

/**
 * `JSContext*`.
 */
typedef JSContextPointer = Pointer<JSContextOpaque>;

/**
 * `JSValue*`.
 * See [[JSValue]].
 *
 * **Note**: Call `JS_FreeValuePointer` to free.
 */
typedef JSValuePointer = Pointer<JSValueOpaque>;

/**
 * `JSValueConst*
 * See [[JSValueConst]] and [[StaticJSValue]].
 */
typedef JSValueConstPointer = Pointer<JSValueConstOpaque>;

/**
 * Used internally for Javascript-to-C function calls.
 */
typedef JSValuePointerPointer = Pointer<Pointer<JSValueOpaque>>;

/**
 * Used internally for Javascript-to-C function calls.
 *
 * **Note**: Call `malloc.free` to free.
 */
typedef JSValueConstPointerPointer = Pointer<Pointer<JSValueConstOpaque>>;

/**
 * Used internally for Javascript-to-C calls that may contain strings too large
 * for the Emscripten stack.
 */
typedef HeapCharPointer = Pointer<Utf8> /*Pointer<'char'>*/;

typedef HeapUnicodeCharPointer = Pointer<Utf16>;

/// The type representing JS function values transferred to Dart value.
///
/// result type: JSValueRef | void
typedef JSToDartFunction = JSValuePointer? Function(List<JSValuePointer> args, {JSValuePointer? thisObj});

const DART_UNDEFINED = #Undefined;