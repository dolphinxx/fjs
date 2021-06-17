import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';

import '../tests/convert_tests.dart';

void main() {
  group('convert', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
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
