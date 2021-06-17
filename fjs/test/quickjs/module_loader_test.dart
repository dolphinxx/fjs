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
    test('JavaScriptCore module_loader simple', () {
      testSimple(vm);
    });
    test('JavaScriptCore module_loader async', () async {
      await testAsync(vm);
    });
  });
}
