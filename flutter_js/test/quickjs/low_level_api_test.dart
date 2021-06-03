import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_js/error.dart';
import 'package:flutter_js/quickjs/qjs_ffi.dart';
import 'package:flutter_js/quickjs/vm.dart';
import 'package:test/test.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

void main() {
  group('low_level_api_test', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('newString', () {
      String expected = "Hello World!";
      final ptr = vm.newString(expected);
      final actual = JS_GetString(vm.ctx, ptr.value).toDartString();
      // JS_FreeValuePointer(vm.ctx, ptr.value);
      ptr.dispose();
      expect(actual, expected);
    });
    test('newError', () {
      final error = JSError('A test message.')..name = 'DARTJSError';
      final ptr = vm.newError(error);
      final errorPtr = JS_ResolveException(vm.ctx, ptr.value);
      try {
        expect(errorPtr, isNot(nullptr));
      } finally {
        ptr.dispose();
        // JS_FreeValuePointer(vm.ctx, ptr);
        JS_FreeValuePointer(vm.ctx, errorPtr);
      }
    });
    test('newArrayBufferCopy', () {
      List<int> expected = utf8.encode('Hello World!');
      final handle = vm.newArrayBufferCopy(Uint8List.fromList(expected));
      final utf8str = 'byteLength'.toNativeUtf8();
      final lengthStr = JS_NewString(vm.ctx, utf8str);
      malloc.free(utf8str);
      final lengthPtr = JS_GetProp(vm.ctx, handle.value, lengthStr.cast<JSValueConstOpaque>());
      JS_FreeValuePointer(vm.ctx, lengthStr);
      int length = JS_GetFloat64(vm.ctx, lengthPtr).toInt();
      expect(length, expected.length);
      final psize = malloc<IntPtr>();
      final buff = JS_GetArrayBuffer(vm.ctx, psize, handle.value);
      Uint8List actual = Uint8List.fromList(buff.asTypedList(psize.value));
      malloc.free(psize);
      print(expected);
      print(actual);
      try {
        expect(actual, expected);
      } finally {
        handle.dispose();
      }
    });
    test('newArrayBuffer_NoCopy', () {
      List<int> data = utf8.encode('Hello World!');
      Uint8List expected = Uint8List.fromList(data);
      final handle = vm.newArrayBuffer(expected);
      final utf8str = 'byteLength'.toNativeUtf8();
      final lengthStr = JS_NewString(vm.ctx, utf8str);
      malloc.free(utf8str);
      final lengthPtr = JS_GetProp(vm.ctx, handle.value, lengthStr.cast<JSValueConstOpaque>());
      JS_FreeValuePointer(vm.ctx, lengthStr);
      int length = JS_GetFloat64(vm.ctx, lengthPtr).toInt();
      expect(length, data.length);
      final psize = malloc<IntPtr>();
      final buff = JS_GetArrayBuffer(vm.ctx, psize, handle.value);
      Uint8List actual = buff.asTypedList(psize.value);
      malloc.free(psize);
      print(expected);
      print(actual);
      try {
        expect(actual, data);
      }finally {
        handle.dispose();
      }
    });
  });
}