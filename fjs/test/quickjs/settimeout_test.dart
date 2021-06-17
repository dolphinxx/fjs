import 'dart:async';

import 'package:fjs/quickjs/qjs_ffi.dart';
import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';
import '../tests/settimeout_tests.dart';

void main() {
  group('QuickJS', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('QuickJS setTimeout lambda', capturePrint(() async {
      await testLambda(vm);
    }));
    test('QuickJS setTimeout legacy', capturePrint(() async {
      await testLegacy(vm);
    }));
    test('QuickJS setTimeout throw', () async {
      vm.evalCode('setTimeout(function() {throw "Expected error."}, 1000)');
      await Future.delayed(Duration(milliseconds: 2000));
      JSValuePointer exception = JS_GetException(vm.ctx);
      String actual = vm.getString(exception);
      JS_FreeValuePointer(vm.ctx, exception);
      expect(actual, 'Expected error.');
    });
    test('QuickJS clearTimeout', capturePrint(() async {
      await testClearTimeout(vm);
    }));
    test('QuickJS setTimeout nested', capturePrint(() async {
      await testNested(vm);
    }));
  });
}
