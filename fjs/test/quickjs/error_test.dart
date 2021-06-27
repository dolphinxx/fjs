import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';
import '../tests/error_tests.dart';

void main() {
  group('QuickJSVm', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('QuickJSVm error from host', capturePrint(() {
      testErrorFromHost(vm);
    }));
    test('QuickJSVm error from JS', capturePrint(() {
      testErrorFromJS(vm, "\'foo\' is not defined", '(<test.js>)');
    }));
    test('QuickJSVm error from throw', capturePrint(() {
      testErrorFromThrow(vm, "Error occurred!", 'QuickJSVm.extractError');
    }));
  });
}
