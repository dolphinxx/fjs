
import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../tests/js_to_dart_tests.dart';

void main() {
  group('js2dart', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('null values', () {
      testNullValues(vm);
    });
    test('number values', () {
      testNumberValues(vm);
    });
    test('bool values', () {
      testBoolValues(vm);
    });
    test('string values', () {
      testStringValues(vm);
    });
    test('array values', () {
      testArrayValues(vm);
    });
    test('arraybuffer values', () {
      testArrayBufferValues(vm);
    });
    test('function values', () {
      testFunctionValues(vm);
    });
    test('date values', () {
      testDateValues(vm);
    });
    test('promise values', () async {
      await testPromiseValues(vm);
    });
    test('promise with timeout values', () async {
      await testPromiseWithTimeoutValues(vm);
    });
    test('object values', () {
      testObjectValues(vm);
    });
  });
}
