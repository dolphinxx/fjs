import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_js/javascriptcore/binding/js_base.dart';
import 'package:flutter_js/javascriptcore/binding/js_object_ref.dart';
import 'package:flutter_js/javascriptcore/binding/js_string_ref.dart';
import 'package:flutter_js/javascriptcore/binding/js_typed_array.dart';
import 'package:flutter_js/javascriptcore/binding/js_value_ref.dart';
import 'package:flutter_js/javascriptcore/binding/jsc_types.dart';
import 'package:flutter_js/javascriptcore/vm.dart';
import 'package:test/test.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

void main() {
  group('low_level_api_test', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('startup', () {
      print('started');
    });
    test('constant', () {
      expect(jSValueMakeUndefined(vm.ctx), jSValueMakeUndefined(vm.ctx), reason: 'undefined should be constant');
      expect(jSValueMakeNull(vm.ctx), jSValueMakeNull(vm.ctx), reason: 'null should be constant');
      expect(jSValueMakeBoolean(vm.ctx, 1), jSValueMakeBoolean(vm.ctx, 1), reason: 'true should be constant');
      expect(jSValueMakeBoolean(vm.ctx, 0), jSValueMakeBoolean(vm.ctx, 0), reason: 'false should be constant');
    });
    test('jSStringGetUTF8CString', () {
      String raw = 'Hello World!世界你好！';
      Pointer<Utf8> strPtr = raw.toNativeUtf8();
      JSStringRef strRef = jSStringCreateWithUTF8CString(strPtr);
      malloc.free(strPtr);
      /// containing terminating '\0'
      int length = jSStringGetMaximumUTF8CStringSize(strRef);
      Pointer<Utf8> buff = malloc<Uint8>(length).cast();
      // int len = jSStringGetUTF8CString(strRef, buff, length);
      malloc.free(buff);
      jSStringRelease(strRef);
      // remove terminating '\0'
      String actual = buff.toDartString(/*length: len - 1*/);
      expect(actual, raw);
    });
    test('jSStringGetCharactersPtr', () {
      String raw = 'Hello World!世界你好！';
      Pointer<Utf8> strPtr = raw.toNativeUtf8();
      JSStringRef strRef = jSStringCreateWithUTF8CString(strPtr);
      malloc.free(strPtr);
      int len = jSStringGetLength(strRef);
      Pointer<Utf16> buff = jSStringGetCharactersPtr(strRef);
      String actual = buff.toDartString(length: len);
      jSStringRelease(strRef);
      expect(actual, raw);
    });
    test('newString', () {
      String expected = "Hello World!";
      final ptr = vm.newString(expected);
      final actual = vm.getString(ptr);
      expect(actual, expected);
    });
    test('error', () {
      JSValueRefRef exception = calloc<JSValueRef>();
      final utf8str = 'throw new Error("An Error!")'.toNativeUtf8();
      final JSStringRef codeRef = jSStringCreateWithUTF8CString(utf8str);
      calloc.free(utf8str);
      jSEvaluateScript(vm.ctx, codeRef, nullptr, nullptr, 0, exception);
      jSStringRelease(codeRef);
      JSValueRef e = exception[0];
      calloc.free(exception);
      expect(e, isNot(nullptr));
      expect(jSValueIsObject(vm.ctx, e), 1);
      JSStringRef str = jSValueToStringCopy(vm.ctx, e, nullptr);
      Pointer<Utf16> strPtr = jSStringGetCharactersPtr(str);
      int length = jSStringGetLength(str);
      String actual = String.fromCharCodes(Uint16List.view(
          strPtr.cast<Uint16>().asTypedList(length).buffer, 0, length));
      jSStringRelease(str);
      expect(actual, 'Error: An Error!');
    });
    test('newArrayBufferCopy', () {
      List<int> expected = utf8.encode('Hello World!');
      final handle = vm.newArrayBuffer(Uint8List.fromList(expected));
      final utf8str = 'byteLength'.toNativeUtf8();
      final JSStringRef lengthStr = jSStringCreateWithUTF8CString(utf8str);
      malloc.free(utf8str);
      final JSValueRef lengthPtr = jSObjectGetProperty(vm.ctx, handle, lengthStr, nullptr);
      jSStringRelease(lengthStr);
      int length = jSValueToNumber(vm.ctx, lengthPtr, nullptr)!.toInt();
      expect(length, expected.length);
      final int psize = jSObjectGetArrayBufferByteLength(vm.ctx, handle, nullptr);
      final Pointer<Uint8> buff = jSObjectGetArrayBufferBytesPtr(vm.ctx, handle, nullptr);
      Uint8List actual = Uint8List.fromList(buff.asTypedList(psize));
      print(expected);
      print(actual);
      expect(actual, expected);
    });
    test('hasProp created by JS', () {
      final obj = vm.evalCode('({a: 1024})');
      expect(vm.hasProperty(obj, 'a'), isTrue);
      expect(vm.hasProperty(obj, 'b'), isFalse);
    });
    test('hasProp created by Dart', () {
      final obj = vm.newObject({'a': 1024});
      expect(vm.hasProperty(obj, 'a'), isTrue);
      expect(vm.hasProperty(obj, 'b'), isFalse);
    });
  });
}