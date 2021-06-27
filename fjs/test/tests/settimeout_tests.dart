import 'package:fjs/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

testLambda(Vm vm) async {
  vm.evalCode('setTimeout(() => console.log(1024), 1000)');
  await Future.delayed(Duration(milliseconds: 2000));
  String? output = consumeLastPrint();
  expect(output, '1024');
}

testLegacy(Vm vm) async {
  vm.evalCode('setTimeout(function() {console.log(1024)}, 1000)');
  await Future.delayed(Duration(milliseconds: 2000));
  String? output = consumeLastPrint();
  expect(output, '1024');
}

testClearTimeout(Vm vm) async {
  int id = vm
      .getNumber(vm.evalCode('setTimeout(() => console.log(1024), 2000)'))!
      .toInt();
  await Future.delayed(Duration(milliseconds: 3000));
  String? output = consumeLastPrint();
  expect(output, '1024');
  id = vm
      .getNumber(vm.evalCode('setTimeout(() => console.log(1024), 2000)'))!
      .toInt();
  vm.evalCode('clearTimeout($id)');
  await Future.delayed(Duration(milliseconds: 3000));
  output = consumeLastPrint();
  expect(output, isNull);
}

testNested(Vm vm) async {
// FIXME: The following exception thrown when running after the `clearTimeout` test.
// If switch the order of the two tests, the exception is gone.
// unhandled error during finalization of test:
// TestDeviceException(Shell subprocess crashed with segmentation fault.)
  await Future.delayed(Duration(seconds: 2));
  vm.evalCode(
      'setTimeout(() => setTimeout(() => console.log(1024), 1000), 1000)');
  await Future.delayed(Duration(milliseconds: 3000));
  String? output = consumeLastPrint();
  expect(output, '1024');
}