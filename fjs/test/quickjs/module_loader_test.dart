import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';

import '../tests/module_loader_tests.dart';

void main() {
  group('QuickJS', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('QuickJS module_loader simple', () {
      testSimple(vm);
    });
    test('QuickJS module_loader async', () async {
      await testAsync(vm);
    });
    test('QuickJS module_loader universal', () async {
      await testUniversal(vm);
    });
  });
}
