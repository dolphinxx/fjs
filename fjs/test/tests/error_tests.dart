import 'package:test/test.dart';
import 'package:fjs/vm.dart';
import 'package:fjs/error.dart';

testErrorFromHost(Vm vm) {
  final fnPtr = vm.newFunction(null, (args, {thisObj}) {
    var a = [];
    a as String;
  });
  vm.setProperty(vm.global, 'fn', fnPtr);
  try {
    vm.evalCode('fn()');
    throw 'should throw an error.';
  } catch (e) {
    expect(e, isA<JSError>());
    e as JSError;
    expect(e.message,
        "type 'List<dynamic>' is not a subtype of type 'String' in type cast");
    expect(e.stackTrace.toString(), contains('/test/tests/error_tests.dart'));
  }
}

testErrorFromJS(Vm vm, String expectedMsg, String expectedStack) {
  try {
    vm.evalCode('foo()', filename: '<test.js>');
    throw 'should throw an error.';
  } catch (e) {
    expect(e, isA<JSError>());
    e as JSError;
    expect(e.message, expectedMsg);
    expect(e.stackTrace.toString(), contains(expectedStack));
  }
}

testErrorFromThrow(Vm vm, String expectedMsg, String expectedStack) {
  try {
    vm.evalCode('throw "Error occurred!"', filename: '<test.js>');
    throw 'should throw an error.';
  } catch (e, s) {
    // print('$e\n$s');
    expect(e, isA<JSError>());
    e as JSError;
    expect(e.message, expectedMsg);
    expect(e.stackTrace.toString(), contains(expectedStack));
  }
}
