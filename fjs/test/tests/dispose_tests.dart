import 'package:fjs/error.dart';
import 'package:fjs/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

/// It should be safe to dispose vm before setTimeout callback is invoked.
testSetTimeout(Vm vm) async {
  vm.evalCode('setTimeout(function() {console.log(1024)}, 2000)');
  vm.dispose();
  await Future.delayed(Duration(seconds: 4));
  String? output = consumeLastPrint();
  expect(output, 'vm disposed');
  print('success');
}

testNewPromise(Vm vm) async {
  var promise = vm.dartToJS(Future.delayed(Duration(seconds: 2), () {
    return JSError('This message should not present!');
  }));
  vm.setProperty(vm.global, 'test', promise);
  Future future = Future.value(vm.jsToDart(vm.evalCode('(async function() {throw await test;}())')));
  vm.dispose();
  try {
    await future;
    throw 'should not run to here!';
  } catch(e) {
    expect(e, isA<JSError>());
    expect((e as JSError).message, 'Vm disposed!');
  }
  print('success');
}