import 'package:fjs/javascriptcore/vm.dart';
import 'package:fjs/types.dart';
import 'package:test/test.dart';

void main() {
  group('constructor', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    JSToDartFunction fn = (args, {thisObj}) {
      return vm.dartToJS({'name': 'Flutter', 'year': vm.dupRef(args[0])});
    };
    test('constructor call in dart', () async {
      final c = vm.newConstructor(fn);
      final instance = vm.callConstructor(c, [vm.newNumber(2021)]);
      final actual = vm.jsToDart(instance);
      expect(actual, {'name': 'Flutter', 'year': 2021});
    });
    test('constructor call in js', () async {
      final c = vm.newConstructor(fn);
      vm.setProperty(vm.global, 'fn', c);
      final instance = vm.evalCode('new fn(2021)');
      final actual = vm.jsToDart(instance);
      expect(actual, {'name': 'Flutter', 'year': 2021});
    });
  });
}