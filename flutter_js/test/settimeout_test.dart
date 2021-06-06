import 'dart:async';

import 'package:flutter_js/javascriptcore/vm.dart';
import 'package:flutter_js/quickjs/qjs_ffi.dart';
import 'package:flutter_js/quickjs/vm.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

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
      vm.evalCode('setTimeout(() => console.log(1024), 1000)');
      await Future.delayed(Duration(milliseconds: 2000));
      String? output = consumeLastPrint();
      expect(output, '1024');
    }));
    test('QuickJS setTimeout legacy', capturePrint(() async {
      vm.evalCode('setTimeout(function() {console.log(1024)}, 1000)');
      await Future.delayed(Duration(milliseconds: 2000));
      String? output = consumeLastPrint();
      expect(output, '1024');
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
      int id = vm.evalAndConsume('setTimeout(() => console.log(1024), 2000)', (lifetime) => vm.getInt(lifetime)!);
      await Future.delayed(Duration(milliseconds: 3000));
      String? output = consumeLastPrint();
      expect(output, '1024');
      id = vm.evalAndConsume('setTimeout(() => console.log(1024), 2000)', (lifetime) => vm.getInt(lifetime)!);
      vm.evalCode('clearTimeout($id)');
      await Future.delayed(Duration(milliseconds: 3000));
      output = consumeLastPrint();
      expect(output, isNull);
    }));
    test('QuickJS setTimeout nested', capturePrint(() async {
      vm.evalCode('setTimeout(() => setTimeout(() => console.log(1024), 1000), 1000)');
      await Future.delayed(Duration(milliseconds: 3000));
      String? output = consumeLastPrint();
      expect(output, '1024');
    }));
  });
  group('JavaScriptCore', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('JavaScriptCore setTimeout lambda', capturePrint(() async {
      vm.evalCode('setTimeout(() => console.log(1024), 1000)');
      await Future.delayed(Duration(milliseconds: 2000));
      String? output = consumeLastPrint();
      expect(output, '1024');
    }));
    test('JavaScriptCore setTimeout legacy', capturePrint(() async {
      vm.evalCode('setTimeout(function() {console.log(1024)}, 1000)');
      await Future.delayed(Duration(milliseconds: 2000));
      String? output = consumeLastPrint();
      expect(output, '1024');
    }));
    test('JavaScriptCore setTimeout throw', () async {
      // Exception is ignored in JavaScriptCore implementation, need to try/catch exception inside the setTimeout callback by your self.
      vm.evalCode('setTimeout(function() {throw "Expected error."}, 1000)');
      await Future.delayed(Duration(milliseconds: 2000));
    });
    test('JavaScriptCore clearTimeout', capturePrint(() async {
      int id = vm.getInt(vm.evalCode('setTimeout(() => console.log(1024), 2000)'))!;
      await Future.delayed(Duration(milliseconds: 3000));
      String? output = consumeLastPrint();
      expect(output, '1024');
      id = vm.getInt(vm.evalCode('setTimeout(() => console.log(1024), 2000)'))!;
      vm.evalCode('clearTimeout($id)');
      await Future.delayed(Duration(milliseconds: 3000));
      output = consumeLastPrint();
      expect(output, isNull);
    }));
    test('JavaScriptCore setTimeout nested', capturePrint(() async {
      vm.evalCode('setTimeout(() => setTimeout(() => console.log(1024), 1000), 1000)');
      await Future.delayed(Duration(milliseconds: 3000));
      String? output = consumeLastPrint();
      expect(output, '1024');
    }));
  });
}
