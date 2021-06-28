import 'dart:convert';
import 'dart:typed_data';

import 'package:fjs/error.dart';
import 'package:fjs/quickjs/qjs_ffi.dart';
import 'package:fjs/quickjs/vm.dart';
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
    test('toString', () {
      final ptr = vm.newNumber(1024);
      final actual = JS_GetString(vm.ctx, ptr).toDartString();
      expect(actual, '1024');
    });
    test('newString', () {
      String expected = "Hello World!";
      final ptr = vm.newString(expected);
      final actual = JS_GetString(vm.ctx, ptr).toDartString();
      // JS_FreeValuePointer(vm.ctx, ptr.value);
      expect(actual, expected);
    });
    test('newBool', () {
      {
        int expected = 0;
        final ptr = JS_NewBool(vm.ctx, expected);
        int actual = JS_ToBool(vm.ctx, ptr);
        JS_FreeValuePointer(vm.ctx, ptr);
        expect(actual, expected);
      }
      {
        int expected = 1;
        final ptr = JS_NewBool(vm.ctx, expected);
        int actual = JS_ToBool(vm.ctx, ptr);
        JS_FreeValuePointer(vm.ctx, ptr);
        expect(actual, expected);
      }
    });
    test('newError', () {
      final error = JSError('A test message.')..name = 'DARTJSError';
      final ptr = vm.newError(error);
      final err = JS_Throw(vm.ctx, ptr);
      final errorPtr = JS_ResolveException(vm.ctx, err);
      try {
        expect(errorPtr, isNot(nullptr));
      } finally {
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
      final lengthPtr = JS_GetProp(vm.ctx, handle, lengthStr.cast<JSValueConstOpaque>());
      JS_FreeValuePointer(vm.ctx, lengthStr);
      int length = JS_GetFloat64(vm.ctx, lengthPtr).toInt();
      expect(length, expected.length);
      final psize = malloc<IntPtr>();
      final buff = JS_GetArrayBuffer(vm.ctx, psize, handle);
      Uint8List actual = Uint8List.fromList(buff.asTypedList(psize.value));
      malloc.free(psize);
      print(expected);
      print(actual);
      expect(actual, expected);
    });
    test('newArrayBuffer_NoCopy', () {
      List<int> data = utf8.encode('Hello World!');
      Uint8List expected = Uint8List.fromList(data);
      final handle = vm.newArrayBuffer(expected);
      final utf8str = 'byteLength'.toNativeUtf8();
      final lengthStr = JS_NewString(vm.ctx, utf8str);
      malloc.free(utf8str);
      final lengthPtr = JS_GetProp(vm.ctx, handle, lengthStr.cast<JSValueConstOpaque>());
      JS_FreeValuePointer(vm.ctx, lengthStr);
      int length = JS_GetFloat64(vm.ctx, lengthPtr).toInt();
      expect(length, data.length);
      final psize = malloc<IntPtr>();
      final buff = JS_GetArrayBuffer(vm.ctx, psize, handle);
      Uint8List actual = buff.asTypedList(psize.value);
      malloc.free(psize);
      print(expected);
      print(actual);
      expect(actual, data);
    });
    test('get function from eval and invoke', () {
      final codePtr = '(function(){return 1024;})'.toNativeUtf8();
      final filenamePtr = '<eval.js>'.toNativeUtf8();
      JSValuePointer fnRef = JS_Eval(vm.ctx, codePtr, codePtr.length, filenamePtr, JSEvalFlag.GLOBAL);
      calloc.free(codePtr);
      calloc.free(filenamePtr);
      try {
        HeapCharPointer typeRef = JS_Typeof(vm.ctx, fnRef);
        String type = typeRef.toDartString();
        malloc.free(typeRef);
        expect(type, 'function');

        JSValuePointer resultRef = JS_Call(vm.ctx, fnRef, JS_GetUndefined(), 0, nullptr);
        double actual = JS_GetFloat64(vm.ctx, resultRef);
        JS_FreeValuePointer(vm.ctx, resultRef);
        expect(actual, 1024);
      } finally {
        JS_FreeValuePointer(vm.ctx, fnRef);
      }
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
    test('getProp', () {
      final obj = vm.newObject({'a': 1024});
      expect(vm.jsToDart(vm.getProperty(obj, 'a')), 1024);
      expect(vm.jsToDart(vm.getProperty(obj, 'b')), isNull);
    });
    test('set prop to args', () {
      final fn = vm.newFunction(null, (args, {thisObj}) {
        vm.setProperty(args[0], 'msg', vm.dartToJS('Hello World!'));
        vm.setProperty(args[0], 'ov', vm.dartToJS('Greeting!'));
      });
      var obj = vm.newObject({'ov': 'should be overwritten'});
      vm.callVoidFunction(fn, null, [obj]);
      expect(vm.jsToDart(vm.getProperty(obj, 'msg')), 'Hello World!');
      expect(vm.jsToDart(vm.getProperty(obj, 'ov')), 'Greeting!');

      obj = vm.newObject({'ov': 'should be overwritten'});
      vm.setProperty(vm.global, 'fn', fn);
      vm.setProperty(vm.global, 'obj', obj);
      vm.evalCode('fn(obj)');
      expect(vm.jsToDart(vm.getProperty(obj, 'msg')), 'Hello World!');
      expect(vm.jsToDart(vm.getProperty(obj, 'ov')), 'Greeting!');
    });
  });
}