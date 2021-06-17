import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';
import '../tests/js_feature_tests.dart';

void main() {
  group('js_feature', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('regex capturing group', () async {
      testRegexCapturingGroup(vm);
    });
  });
}