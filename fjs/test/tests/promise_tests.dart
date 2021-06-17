import 'package:fjs/vm.dart';
import 'package:test/test.dart';

testNested(Vm vm) async {
  JSToDartFunction fn = (args, {thisObj}) {
    return vm.dartToJS(Future.delayed(
        Duration(seconds: 2),
        () => Future.delayed(Duration(seconds: 2),
            () => ({'message': 'Hello World!', 'year': 2021}))));
  };

  vm.setProperty(vm.global, 'fn', vm.newFunction(null, fn));
  vm.startEventLoop();
  final actual = await vm.jsToDart(vm.evalCode(r'fn()'));
  expect(actual, {'message': 'Hello World!', 'year': 2021});
}
