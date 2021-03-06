import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';
import '../tests/constructor_tests.dart';

void main() {
  group('constructor', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('constructor call in dart', () {
      testConstructorCallInDart(vm);
    });
    test('constructor call in js', () {
      testConstructorCallInJS(vm);
    });
  });
}
