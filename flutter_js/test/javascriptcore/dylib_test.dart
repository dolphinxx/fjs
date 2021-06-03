import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_js/javascriptcore/binding/js_context_ref.dart';
import 'package:flutter_js/javascriptcore/binding/js_object_ref.dart';
import 'package:flutter_js/javascriptcore/binding/js_string_ref.dart';
import 'package:flutter_js/javascriptcore/binding/js_value_ref.dart';
import 'package:flutter_js/javascriptcore/binding/jsc_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hello_world', () {
    JSContextRef ctx = jSGlobalContextCreate(nullptr);
    JSValueRef value = jSValueMakeNumber(ctx, 1024);
    double? actual = jSValueToNumber(ctx, value, nullptr);
    jSGlobalContextRelease(ctx);
    expect(actual, 1024);
  });
  test('globalThis set property', () {
    JSContextRef ctx = jSGlobalContextCreate(nullptr);
    JSObjectRef globalThis = jSContextGetGlobalObject(ctx);
    // Set
    Pointer<Utf8> propNamePtr = 'greeting'.toNativeUtf8();
    JSStringRef propNameRef = jSStringCreateWithUTF8CString(propNamePtr);
    malloc.free(propNamePtr);
    Pointer<Utf8> propPtr = 'Hello World!'.toNativeUtf8();
    JSStringRef propRef = jSStringCreateWithUTF8CString(propPtr);
    malloc.free(propPtr);
    JSValueRef prop = jSValueMakeString(ctx, propRef);
    jSStringRelease(propRef);
    JSValueRefRef exception = calloc<JSValueRef>();
    jSObjectSetProperty(ctx, globalThis, propNameRef, prop, JSPropertyAttributes.kJSPropertyAttributeNone, exception);
    if(exception.value != 0) {
      // exception occur
    }
    malloc.free(exception);
    jSStringRelease(propNameRef);

    // Get
    propNamePtr = 'greeting'.toNativeUtf8();
    propNameRef = jSStringCreateWithUTF8CString(propNamePtr);
    malloc.free(propNamePtr);
    JSValueRef result = jSObjectGetProperty(ctx, globalThis, propNameRef, nullptr);
    jSStringRelease(propNameRef);
    JSStringRef resultRef = jSValueToStringCopy(ctx, result, nullptr);

    Pointer<Utf16> cString = jSStringGetCharactersPtr(resultRef);
    int length = jSStringGetLength(resultRef);
    String actual = String.fromCharCodes(Uint16List.view(cString.cast<Uint16>().asTypedList(length).buffer, 0, length));
    jSStringRelease(resultRef);
    jSGlobalContextRelease(ctx);
    print('actual: $actual');
    expect(actual, 'Hello World!');
  });
  test('globalThis set function property', () {
    JSContextRef ctx = jSGlobalContextCreate(nullptr);
    JSObjectRef globalThis = jSContextGetGlobalObject(ctx);
    // Set
    Pointer<Utf8> propNamePtr = 'greeting'.toNativeUtf8();
    JSStringRef propNameRef = jSStringCreateWithUTF8CString(propNamePtr);
    malloc.free(propNamePtr);
    JSObjectRef prop = jSObjectMakeFunctionWithCallback(ctx, nullptr, Pointer.fromFunction(_cToHostCallback));
    jSObjectSetProperty(ctx, globalThis, propNameRef, prop, JSPropertyAttributes.kJSPropertyAttributeNone, nullptr);
    jSStringRelease(propNameRef);

    // invoke
    propNamePtr = 'greeting'.toNativeUtf8();
    propNameRef = jSStringCreateWithUTF8CString(propNamePtr);
    malloc.free(propNamePtr);
    JSValueRef fn = jSObjectGetProperty(ctx, globalThis, propNameRef, nullptr);
    jSStringRelease(propNameRef);
    JSValueRef result = jSObjectCallAsFunction(ctx, fn, nullptr, 0, nullptr, nullptr);

    JSStringRef resultRef = jSValueToStringCopy(ctx, result, nullptr);
    Pointer<Utf16> cString = jSStringGetCharactersPtr(resultRef);
    int length = jSStringGetLength(resultRef);
    String actual = String.fromCharCodes(Uint16List.view(cString.cast<Uint16>().asTypedList(length).buffer, 0, length));
    jSStringRelease(resultRef);
    jSGlobalContextRelease(ctx);
    print('actual: $actual');
    expect(actual, 'Hello World!');
  });
}
JSValueRef _cToHostCallback(
    JSContextRef ctx,
    JSObjectRef function,
    JSObjectRef thisObject,
    int argumentCount,
    JSValueRefArray arguments,
    JSValueRefRef exception,
    ) {
  print('cToHostCallback invoked.');
  Pointer<Utf8> resultPtr = 'Hello World!'.toNativeUtf8();
  JSStringRef resultRef = jSStringCreateWithUTF8CString(resultPtr);
  malloc.free(resultPtr);
  JSValueRef result = jSValueMakeString(ctx, resultRef);
  jSStringRelease(resultRef);
  return result;
}