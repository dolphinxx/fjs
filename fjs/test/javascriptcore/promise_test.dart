import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../tests/promise_tests.dart';

void main() {
  group('promise', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('nested promise', () async {
      await testNested(vm);
    });
  });
}
