import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../tests/convert_tests.dart';

void main() {
  group('convert', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('dart to js to dart', () async {
      await testDartToJSToDart(vm);
    });
    test('js to dart to js', () async {
      await testJSToDartToJS(vm);
    });
  });
}
