import 'dart:ffi';

import 'jsc_ffi.dart';

/// enum JSType
/// A constant identifying the type of a JSValue.
class JSType {
  /// The unique undefined value.
  static const int kJSTypeUndefined = 0;

  /// The unique null value.
  static const int kJSTypeNull = 1;

  /// A primitive boolean value, one of true or false.
  static const int kJSTypeBoolean = 2;

  /// A primitive number value.
  static const int kJSTypeNumber = 3;

  /// A primitive string value.
  static const int kJSTypeString = 4;

  /// An object value (meaning that this JSValueRef is a JSObjectRef).
  static const int kJSTypeObject = 5;

  /// A primitive symbol value.
  static const int kJSTypeSymbol = 6;
}

/// enum JSTypedArrayType
/// A constant identifying the Typed Array type of a JSObjectRef.
class JSTypedArrayType {
  /// Int8Array
  static const int kJSTypedArrayTypeInt8Array = 0;

  /// Int16Array
  static const int kJSTypedArrayTypeInt16Array = 1;

  /// Int32Array
  static const int kJSTypedArrayTypeInt32Array = 2;

  /// Uint8Array
  static const int kJSTypedArrayTypeUint8Array = 3;

  /// Uint8ClampedArray
  static const int kJSTypedArrayTypeUint8ClampedArray = 4;

  /// Uint16Array
  static const int kJSTypedArrayTypeUint16Array = 5;

  /// Uint32Array
  static const int kJSTypedArrayTypeUint32Array = 6;

  /// Float32Array
  static const int kJSTypedArrayTypeFloat32Array = 7;

  /// Float64Array
  static const int kJSTypedArrayTypeFloat64Array = 8;

  /// ArrayBuffer
  static const int kJSTypedArrayTypeArrayBuffer = 9;

  /// Not a Typed Array
  static const int kJSTypedArrayTypeNone = 10;
}

/// Returns a JavaScript value's type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue whose type you want to obtain.
/// [@result] (JSType) A value of type JSType that identifies value's type.
final int Function(JSContextRef ctx, JSValueRef value) jSValueGetType = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueGetType')
    .asFunction();

/// Tests whether a JavaScript value's type is the undefined type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the undefined type, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value) jSValueIsUndefined = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>(
        'JSValueIsUndefined')
    .asFunction();

/// Tests whether a JavaScript value's type is the null type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the null type, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value) jSValueIsNull = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueIsNull')
    .asFunction();

/// Tests whether a JavaScript value's type is the boolean type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the boolean type, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value) jSValueIsBoolean = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueIsBoolean')
    .asFunction();

/// Tests whether a JavaScript value's type is the number type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the number type, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value) jSValueIsNumber = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueIsNumber')
    .asFunction();

/// Tests whether a JavaScript value's type is the string type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the string type, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value) jSValueIsString = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueIsString')
    .asFunction();

/// Tests whether a JavaScript value's type is the symbol type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the symbol type, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value) jSValueIsSymbol = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueIsSymbol')
    .asFunction();

/// Tests whether a JavaScript value's type is the object type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the object type, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value) jSValueIsObject = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueIsObject')
    .asFunction();

/// Tests whether a JavaScript value is an object with a given class in its class chain.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [jsClass] (JSClassRef) The JSClass to test against.
/// [@result] (bool) true if value is an object and has jsClass in its class chain, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value, Pointer jsClass)
    jSValueIsObjectOfClass = jscLib!
        .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef, Pointer)>>(
            'JSValueIsObjectOfClass')
        .asFunction();

/// Tests whether a JavaScript value is an array.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value is an array, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value) jSValueIsArray = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueIsArray')
    .asFunction();

/// Tests whether a JavaScript value is a date.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value is a date, otherwise false.
final int Function(JSContextRef ctx, JSValueRef value) jSValueIsDate = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueIsDate')
    .asFunction();

/// Returns a JavaScript value's Typed Array type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue whose Typed Array type to return.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSTypedArrayType) A value of type JSTypedArrayType that identifies value's Typed Array type, or kJSTypedArrayTypeNone if the value is not a Typed Array object.
final int Function(JSContextRef ctx, JSValueRef value, JSValueRefRef exception)
    jSValueGetTypedArrayType = jscLib!
        .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef, JSValueRefRef)>>(
            'JSValueGetTypedArrayType')
        .asFunction();

/// Tests whether two JavaScript values are equal, as compared by the JS == operator.
/// [ctx] (JSContextRef) The execution context to use.
/// [a] (JSValueRef) The first value to test.
/// [b] (JSValueRef) The second value to test.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (bool) true if the two values are equal, false if they are not equal or an exception is thrown.
final int Function(
    JSContextRef ctx,
    JSValueRef a,
    JSValueRef b,
    JSValueRefRef
        exception) jSValueIsEqual = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef, JSValueRef, JSValueRefRef)>>(
        'JSValueIsEqual')
    .asFunction();

/// Tests whether two JavaScript values are strict equal, as compared by the JS === operator.
/// [ctx] (JSContextRef) The execution context to use.
/// [a] (JSValueRef) The first value to test.
/// [b] (JSValueRef) The second value to test.
/// [@result] (bool) true if the two values are strict equal, otherwise false.
final int Function(JSContextRef ctx, JSValueRef a, JSValueRef b) jSValueIsStrictEqual =
    jscLib!
        .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef, JSValueRef)>>(
            'JSValueIsStrictEqual')
        .asFunction();

/// Tests whether a JavaScript value is an object constructed by a given constructor, as compared by the JS instanceof operator.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [constructor] (JSObjectRef) The constructor to test against.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (bool) true if value is an object constructed by constructor, as compared by the JS instanceof operator, otherwise false.
final int Function(
    JSContextRef ctx,
    JSValueRef value,
    JSObjectRef constructor,
    JSValueRefRef
        exception) jSValueIsInstanceOfConstructor = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef, JSObjectRef, JSValueRefRef)>>(
        'JSValueIsInstanceOfConstructor')
    .asFunction();

/// Creates a JavaScript value of the undefined type.
/// [ctx] (JSContextRef) The execution context to use.
/// [@result] (JSValueRef) The unique undefined value.
final JSValueRef Function(JSContextRef ctx) jSValueMakeUndefined = jscLib!
    .lookup<NativeFunction<JSValueRef Function(JSContextRef)>>('JSValueMakeUndefined')
    .asFunction();

/// Creates a JavaScript value of the null type.
/// [ctx] (JSContextRef) The execution context to use.
/// [@result] (JSValueRef) The unique null value.
final JSValueRef Function(JSContextRef ctx) jSValueMakeNull = jscLib!
    .lookup<NativeFunction<JSValueRef Function(JSContextRef)>>('JSValueMakeNull')
    .asFunction();

/// Creates a JavaScript value of the boolean type.
/// [ctx] (JSContextRef) The execution context to use.
/// [boolean] (bool) The bool to assign to the newly created JSValue.
/// [@result] (JSValueRef) A JSValue of the boolean type, representing the value of boolean.
final JSValueRef Function(JSContextRef ctx, int boolean) jSValueMakeBoolean = jscLib!
    .lookup<NativeFunction<JSValueRef Function(JSContextRef, Int8)>>(
        'JSValueMakeBoolean')
    .asFunction();

/// Creates a JavaScript value of the number type.
/// [ctx] (JSContextRef) The execution context to use.
/// [number] (double) The double to assign to the newly created JSValue.
/// [@result] (JSValueRef) A JSValue of the number type, representing the value of number.
final JSValueRef Function(JSContextRef ctx, double number) jSValueMakeNumber = jscLib!
    .lookup<NativeFunction<JSValueRef Function(JSContextRef, Double)>>(
        'JSValueMakeNumber')
    .asFunction();

/// Creates a JavaScript value of the string type.
/// [ctx] (JSContextRef) The execution context to use.
/// [string] (JSStringRef) The JSString to assign to the newly created JSValue. The newly created JSValue retains string, and releases it upon garbage collection.
/// [@result] (JSValueRef) A JSValue of the string type, representing the value of string.
final JSValueRef Function(JSContextRef ctx, JSStringRef string) jSValueMakeString = jscLib!
    .lookup<NativeFunction<JSValueRef Function(JSContextRef, JSStringRef)>>(
        'JSValueMakeString')
    .asFunction();

/// Creates a JavaScript value of the symbol type.
/// [ctx] (JSContextRef) The execution context to use.
/// [description] (JSStringRef) A description of the newly created symbol value.
/// [@result] (JSValueRef) A unique JSValue of the symbol type, whose description matches the one provided.
final JSValueRef Function(JSContextRef ctx, JSStringRef description) jSValueMakeSymbol =
    jscLib!
        .lookup<NativeFunction<JSValueRef Function(JSContextRef, JSStringRef)>>(
            'JSValueMakeSymbol')
        .asFunction();

/// Creates a JavaScript value from a JSON formatted string.
/// [ctx] (JSContextRef) The execution context to use.
/// [string] (JSStringRef) The JSString containing the JSON string to be parsed.
/// [@result] (JSValueRef) A JSValue containing the parsed value, or NULL if the input is invalid.
final JSValueRef Function(JSContextRef ctx, JSStringRef string) jSValueMakeFromJSONString =
    jscLib!
        .lookup<NativeFunction<JSValueRef Function(JSContextRef, JSStringRef)>>(
            'JSValueMakeFromJSONString')
        .asFunction();

/// Creates a JavaScript string containing the JSON serialized representation of a JS value.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The value to serialize.
/// [indent] (unsigned) The number of spaces to indent when nesting.  If 0, the resulting JSON will not contains newlines.  The size of the indent is clamped to 10 spaces.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSStringRef) A JSString with the result of serialization, or NULL if an exception is thrown.
final JSStringRef Function(
    JSContextRef ctx,
    JSValueRef value,
    int indent,
    JSValueRefRef
        exception) jSValueCreateJSONString = jscLib!
    .lookup<NativeFunction<JSStringRef Function(JSContextRef, JSValueRef, Int32, JSValueRefRef)>>(
        'JSValueCreateJSONString')
    .asFunction();

/// Converts a JavaScript value to boolean and returns the resulting boolean.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to convert.
/// [@result] (bool) The boolean result of conversion.
final int Function(JSContextRef ctx, JSValueRef value) jSValueToBoolean = jscLib!
    .lookup<NativeFunction<Int8 Function(JSContextRef, JSValueRef)>>('JSValueToBoolean')
    .asFunction();

/// Converts a JavaScript value to number and returns the resulting number.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to convert.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (double) The numeric result of conversion, or NaN if an exception is thrown.
final double Function(JSContextRef ctx, JSValueRef value, JSValueRefRef exception)
    jSValueToNumber = jscLib!
        .lookup<NativeFunction<Double Function(JSContextRef, JSValueRef, JSValueRefRef)>>(
            'JSValueToNumber')
        .asFunction();

/// Converts a JavaScript value to string and copies the result into a JavaScript string.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to convert.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSStringRef) A JSString with the result of conversion, or NULL if an exception is thrown. Ownership follows the Create Rule.
final JSStringRef Function(JSContextRef ctx, JSValueRef value, JSValueRefRef exception)
    jSValueToStringCopy = jscLib!
        .lookup<NativeFunction<JSStringRef Function(JSContextRef, JSValueRef, JSValueRefRef)>>(
            'JSValueToStringCopy')
        .asFunction();

/// Converts a JavaScript value to object and returns the resulting object.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to convert.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) The JSObject result of conversion, or NULL if an exception is thrown.
final JSObjectRef Function(JSContextRef ctx, JSValueRef value, JSValueRefRef exception)
    jSValueToObject = jscLib!
        .lookup<NativeFunction<JSObjectRef Function(JSContextRef, JSValueRef, JSValueRefRef)>>(
            'JSValueToObject')
        .asFunction();

/// Protects a JavaScript value from garbage collection.
/// Use this method when you want to store a JSValue in a global or on the heap, where the garbage collector will not be able to discover your reference to it.
///
/// A value may be protected multiple times and must be unprotected an equal number of times before becoming eligible for garbage collection.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to protect.
final void Function(JSContextRef ctx, JSValueRef value) jSValueProtect = jscLib!
    .lookup<NativeFunction<Void Function(JSContextRef, JSValueRef)>>('JSValueProtect')
    .asFunction();

/// Unprotects a JavaScript value from garbage collection.
/// A value may be protected multiple times and must be unprotected an
/// equal number of times before becoming eligible for garbage collection.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to unprotect.
final void Function(JSContextRef ctx, JSValueRef value) jSValueUnprotect = jscLib!
    .lookup<NativeFunction<Void Function(JSContextRef, JSValueRef)>>('JSValueUnprotect')
    .asFunction();
