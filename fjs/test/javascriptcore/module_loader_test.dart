
import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../tests/module_loader_tests.dart';

void main() {
  group('JavaScriptCore', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('JavaScriptCore module_loader simple', () {
      testSimple(vm);
    });
    test('JavaScriptCore module_loader async', () async {
      await testAsync(vm);
    });
    test('JavaScriptCore module_loader universal', () async {
      await testUniversal(vm);
    });
  });
}
