import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../tests/memory_pressure_tests.dart';

main() {
  group('JavaScriptCoreVm', () {
    late JavaScriptCoreVm vm;

    setUp(() {
      vm = JavaScriptCoreVm();
    });

    tearDown(() {
      vm.dispose();
    });

    group('memory pressure', () {
      test('128 rows', () async {
        testMemoryPressure(vm, 128);
      });
      test('256 rows', () async {
        testMemoryPressure(vm, 256);
      });
      test('512 rows', () async {
        // May crash
        testMemoryPressure(vm, 512);
      });
      test('768 rows', () async {
        testMemoryPressure(vm, 768);
      });
      test('1024 rows', () async {
        testMemoryPressure(vm, 1024);
      });
      test('2048 rows', () async {
        testMemoryPressure(vm, 2048);
      });
    });
  });
}
