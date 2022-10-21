import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';
import '../tests/console_tests.dart';

void main() {
  group('QuickJS', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm(disableConsole: false);
    });
    tearDown(() {
      vm.dispose();
    });
    test('QuickJS console.log', capturePrint(() async {
      testConsoleLog(vm);
    }));
  });
}
