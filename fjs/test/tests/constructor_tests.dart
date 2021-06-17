import 'package:test/test.dart';
import 'package:fjs/vm.dart';

JSToDartFunction getFn(Vm vm) => (args, {thisObj}) {
      return vm.dartToJS({'name': 'Flutter', 'year': vm.dupRef(args[0])});
    };

testConstructorCallInDart(Vm vm) {
  final c = vm.newConstructor(getFn(vm));
  final instance = vm.callConstructor(c, [vm.newNumber(2021)]);
  final actual = vm.jsToDart(instance);
  expect(actual, {'name': 'Flutter', 'year': 2021});
}

testConstructorCallInJS(Vm vm) {
  final c = vm.newConstructor(getFn(vm));
  vm.setProperty(vm.global, 'fn', c);
  final instance = vm.evalCode('new fn(2021)');
  final actual = vm.jsToDart(instance);
  expect(actual, {'name': 'Flutter', 'year': 2021});
}
