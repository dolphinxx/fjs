import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';

import '../tests/concurrent_tests.dart';

void main() {
  group('QuickJS', () {
    test('QuickJS concurrent', () async {
      await testConcurrent(() => QuickJSVm());
    });
  });
}
