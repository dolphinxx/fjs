import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';
import '../tests/dispose_tests.dart';

void main() {
  group('JavaScriptCore', () {
    test('JavaScriptCore setTimeout interrupted', capturePrint(() async {
      JavaScriptCoreVm vm = JavaScriptCoreVm();
      await testSetTimeout(vm);
    }));
    test('JavaScriptCore Promise interrupted', capturePrint(() async {
      JavaScriptCoreVm vm = JavaScriptCoreVm();
      await testNewPromise(vm);
    }));
  });
}