import 'dart:async';
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

/// Used for `newFunction`
///
/// Implementations should not free its arguments or its return value.
/// It should not retain a reference to its return value or thrown error.
typedef JSToDartFunction = JSValuePointer? Function(List<JSValuePointer> args, {JSValuePointer? thisObj});

/// Return the source code as if in an imported file, or null if the [module] is not found
typedef ES6ModuleLoader = String? Function(String module);

const DART_UNDEFINED = #Undefined;