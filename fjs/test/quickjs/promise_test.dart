import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';

import '../tests/promise_tests.dart';

void main() {
  group('promise', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('nested promise', () async {
      await testNested(vm);
    });
  });
}
