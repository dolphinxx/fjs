import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';
import '../tests/console_tests.dart';

void main() {
  group('JavaScriptCore', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm(disableConsole: false);
    });
    tearDown(() {
      vm.dispose();
    });
    test('JavaScriptCore console.log', capturePrint(() {
      testConsoleLog(vm);
    }));
  });
}
