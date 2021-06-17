import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';
import '../tests/js_feature_tests.dart';

void main() {
  group('js_feature', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('regex capturing group', () async {
      testRegexCapturingGroup(vm);
    });
  });
}