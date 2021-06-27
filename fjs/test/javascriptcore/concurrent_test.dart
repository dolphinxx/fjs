import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../tests/concurrent_tests.dart';

void main() {
  group('JavaScriptCore', () {
    test('JavaScriptCore concurrent', () async {
      await testConcurrent(() => JavaScriptCoreVm());
    });
  });
}
