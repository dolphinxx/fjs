import 'dart:convert';
import 'dart:typed_data';

import 'package:fjs/error.dart';
import 'package:test/test.dart';
import 'package:fjs/vm.dart';

testNullValues(Vm vm) {
  expect(vm.jsToDart(vm.evalCode('null')), isNull);
  vm.reserveUndefined = true;
  expect(vm.jsToDart(vm.evalCode('undefined')), DART_UNDEFINED);
  expect(vm.jsToDart(vm.evalCode('var a;a')), DART_UNDEFINED);
  vm.reserveUndefined = false;
  expect(vm.jsToDart(vm.evalCode('undefined')), isNull);
  expect(vm.jsToDart(vm.evalCode('var a;a')), isNull);
}

testNumberValues(Vm vm) {
  expect(vm.jsToDart(vm.newNumber(1)), 1.0);
  expect(vm.jsToDart(vm.newNumber(1.5)), 1.5);
  expect(vm.jsToDart(vm.evalCode('1.500000')), 1.5);
  expect(vm.jsToDart(vm.evalCode('1024102410241024')), 1024102410241024);
  expect(vm.jsToDart(vm.evalCode('0xff')), allOf(equals(0xff), isA<int>()),
      reason: 'Should get Dart int from JS int');
  expect(vm.jsToDart(vm.evalCode('Number("1.500000")')), 1.5);
  expect(vm.jsToDart(vm.evalCode('new Number("1.500000")')), 1.5);
}

testBoolValues(Vm vm) {
  expect(vm.jsToDart(vm.evalCode('true')), isTrue);
  expect(vm.jsToDart(vm.evalCode('false')), isFalse);
// !!string === true
  expect(vm.jsToDart(vm.evalCode('Boolean("true")')), isTrue);
  expect(vm.jsToDart(vm.evalCode('Boolean("false")')), isTrue);

  expect(vm.jsToDart(vm.evalCode('Boolean(true)')), isTrue);
  expect(vm.jsToDart(vm.evalCode('Boolean(false)')), isFalse);
// !!object === true
  expect(vm.jsToDart(vm.evalCode('new Boolean(true)')), isTrue);
  expect(vm.jsToDart(vm.evalCode('new Boolean(false)')), isTrue);
  expect(vm.jsToDart(vm.evalCode('new Boolean("false")')), isTrue);
}

testStringValues(Vm vm) {
  expect(vm.jsToDart(vm.evalCode('\'Hello World!\'')), 'Hello World!');
  expect(vm.jsToDart(vm.evalCode('`Hello`')), 'Hello');
  expect(vm.jsToDart(vm.evalCode('"Hello"')), 'Hello');
  expect(vm.jsToDart(vm.evalCode('String("Hello")')), 'Hello');
  expect(vm.jsToDart(vm.evalCode('new String("Hello")')), 'Hello');
}

testArrayValues(Vm vm) {
  expect(vm.jsToDart(vm.evalCode('[]')), []);
  expect(vm.jsToDart(vm.evalCode('[`Hello`, "World", 2021]')),
      ['Hello', 'World', 2021]);
  expect(
      vm.jsToDart(vm.evalCode('var array = new Array();array[1] = 1024;array')),
      [null, 1024]);
}

testArrayBufferValues(Vm vm) {
  expect(
      vm.jsToDart(vm.evalCode(
          'var str = "Hello World!";var buf = new ArrayBuffer(str.length);var bv = new Uint8Array(buf);for(var i = 0;i<str.length;i++)bv[i]=str.charCodeAt(i);buf')),
      Uint8List.fromList(utf8.encode("Hello World!")));
}

testFunctionValues(Vm vm) {
  String actual = vm.jsToDart((vm.jsToDart(vm.evalCode(
              r'(function(message) {return `Hello ${this}!${message}`})'))
          as JSToDartFunction)([vm.newString("Flutter 2021!")],
      thisObj: vm.newString("World"))!);
  expect(actual, "Hello World!Flutter 2021!");
}

testDateValues(Vm vm) {
  vm.constructDate = false;
  expect(vm.jsToDart(vm.evalCode('new Date(1622470242901)')), 1622470242901);
  vm.constructDate = true;
  expect(vm.jsToDart(vm.evalCode('new Date(1622470242901)')),
      DateTime.fromMillisecondsSinceEpoch(1622470242901));
}

testPromiseValues(Vm vm) async {
  vm.startEventLoop();
  expect(
      await (vm.jsToDart(vm.evalCode(
              'new Promise((resolve, reject) => resolve("Hello World!")).then(_ => _ + "!")'))
          as Future),
      "Hello World!!");
  try {
    await (vm.jsToDart(vm.evalCode(
            'new Promise((resolve, reject) => reject("Expected error."))'))
        as Future);
  } catch (e) {
    expect(e, isA<JSError>());
    expect((e as JSError).message, 'Expected error.');
  }
}

testPromiseWithTimeoutValues(Vm vm) async {
  vm.startEventLoop();
  final actual = await (vm.jsToDart(vm.evalCode(
          'new Promise((resolve, reject) => setTimeout(function() {console.log(123);resolve("Hello World!")}, 1000)).then(_ => _ + "!")'))
      as Future);
  expect(actual, "Hello World!!");
}

testObjectValues(Vm vm) {
  var expected = {
    'a': 1,
    'b': '2',
    'c': [
      1,
      2,
      {'regex': {}, '2': 'number prop name'},
    ]
  };
  vm.jsonSerializeObject = true;
  expect(
      vm.jsToDart(vm.evalCode(
          r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''')),
      expected);
  vm.jsonSerializeObject = false;
  expected = {
    'a': 1,
    'b': '2',
    'c': [
      1,
      2,
      {'regex': {}, 'Symbol': null, '2': 'number prop name'},
    ]
  };
  expect(
      vm.jsToDart(vm.evalCode(
          r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''')),
      expected);
}

testFunctionInMap(Vm vm) {
  // var map = vm.jsToDart(vm.evalCode(r'''({fn: ((name) => `Hi, ${name}!`)})'''));
  // var fn = map['fn'] as JSToDartFunction;
  // var result = fn([vm.dartToJS('Flutter')])!
  var map = vm.evalCode(r'''({fn: ((name) => `Hi, ${name}!`)})''');
  var dartMap = vm.jsToDart(map);
  var f = vm.getProperty(map, 'fn');
  var dartFn = dartMap['fn'] as JSToDartFunction;
  var result = vm.callFunction(f, vm.nullThis, [vm.dartToJS('Flutter')]);
  expect(vm.jsToDart(result), "Hi, Flutter!");
  var result1 = dartFn([vm.dartToJS('Flutter')])!;
  expect(vm.jsToDart(result1), "Hi, Flutter!");
}

testPromiseInMap(Vm vm) async {
  vm.startEventLoop();
  var map = vm.jsToDart(vm.evalCode(r'''({promise: (new Promise((resolve, reject) => resolve("Hello World!")))})'''));
  var promise = map['promise'] as Future;
  var value = await promise;
  expect(value, 'Hello World!');
}