import 'dart:async';

import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';
import '../tests/settimeout_tests.dart';

void main() {
  group('JavaScriptCore', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm(disableConsole: false);
    });
    tearDown(() {
      vm.dispose();
    });
    test('JavaScriptCore setTimeout lambda', capturePrint(() async {
      await testLambda(vm);
    }));
    test('JavaScriptCore setTimeout legacy', capturePrint(() async {
      await testLegacy(vm);
    }));
    test('JavaScriptCore setTimeout throw', () async {
      // Exception is ignored in JavaScriptCore implementation, need to try/catch exception inside the setTimeout callback by your self.
      vm.evalCode('setTimeout(function() {throw "Expected error."}, 1000)');
      await Future.delayed(Duration(milliseconds: 2000));
    });
    test('JavaScriptCore clearTimeout', capturePrint(() async {
      await testClearTimeout(vm);
    }));
    test('JavaScriptCore setTimeout nested', capturePrint(() async {
      // FIXME: The following exception thrown when running after the `clearTimeout` test(MacOS).
      // If switch the order of the two tests, the exception is gone.
      // nhandled error during finalization of test:
      // TestDeviceException(Shell subprocess crashed with segmentation fault.)
      await testNested(vm);
    }));
  });
}
