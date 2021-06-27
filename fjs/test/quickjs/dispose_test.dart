import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';
import '../tests/dispose_tests.dart';

void main() {
  group('QuickJS', () {
    test('QuickJS setTimeout interrupted', capturePrint(() async {
      QuickJSVm vm = QuickJSVm();
      await testSetTimeout(vm);
    }));
    test('QuickJS Promise interrupted', capturePrint(() async {
      QuickJSVm vm = QuickJSVm();
      vm.startEventLoop();
      await testNewPromise(vm);
    }));
  });
}