import 'package:fjs/error.dart';
import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';
import '../tests/error_tests.dart';

void main() {
  group('JavaScriptCore', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('JavaScriptCore error from host', capturePrint(() {
      testErrorFromHost(vm);
    }));
    test('JavaScriptCore error from JS', capturePrint(() {
      testErrorFromJS(vm, "Can't find variable: foo", '<test.js>:1:4');
    }));
    test('QuickJSVm error from throw', capturePrint(() {
      testErrorFromThrow(vm, 'Error occurred!', 'JavaScriptCoreVm.resolveException');
    }));
  });
}
