import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_js/error.dart';
import 'package:flutter_js/types.dart';
import 'package:flutter_js/javascriptcore/vm.dart';
import 'package:test/test.dart';

void main() {
  group('js2dart', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('null values', () {
      expect(vm.jsToDart(vm.evalCode('null')), isNull);
      vm.reserveUndefined = true;
      expect(vm.jsToDart(vm.evalCode('undefined')), DART_UNDEFINED);
      expect(vm.jsToDart(vm.evalCode('var a;a')), DART_UNDEFINED);
      vm.reserveUndefined = false;
      expect(vm.jsToDart(vm.evalCode('undefined')), isNull);
      expect(vm.jsToDart(vm.evalCode('var a;a')), isNull);
    });
    test('number values', () {
      expect(vm.jsToDart(vm.newNumber(1)), 1.0);
      expect(vm.jsToDart(vm.newNumber(1.5)), 1.5);
      expect(vm.jsToDart(vm.evalCode('1.500000')), 1.5);
      expect(vm.jsToDart(vm.evalCode('1024102410241024')), 1024102410241024);
      expect(vm.jsToDart(vm.evalCode('0xff')), allOf(equals(0xff), isA<int>()), reason: 'Should get Dart int from JS int');
      expect(vm.jsToDart(vm.evalCode('Number("1.500000")')), 1.5);
      expect(vm.jsToDart(vm.evalCode('new Number("1.500000")')), 1.5);
    });
    test('bool values', () {
      expect(vm.jsToDart(vm.evalCode('true')), isTrue);
      expect(vm.jsToDart(vm.evalCode('false')), isFalse);
      expect(vm.jsToDart(vm.evalCode('Boolean("true")')), isTrue);
      expect(vm.jsToDart(vm.evalCode('new Boolean(true)')), isTrue);
    });
    test('string values', () {
      expect(vm.jsToDart(vm.evalCode('\'Hello World!\'')), 'Hello World!');
      expect(vm.jsToDart(vm.evalCode('`Hello`')), 'Hello');
      expect(vm.jsToDart(vm.evalCode('"Hello"')), 'Hello');
      expect(vm.jsToDart(vm.evalCode('String("Hello")')), 'Hello');
      expect(vm.jsToDart(vm.evalCode('new String("Hello")')), 'Hello');
    });
    test('array values', () {
      expect(vm.jsToDart(vm.evalCode('[]')), []);
      expect(vm.jsToDart(vm.evalCode('[`Hello`, "World", 2021]')), ['Hello', 'World', 2021]);
      expect(vm.jsToDart(vm.evalCode('var array = new Array();array[1] = 1024;array')), [null, 1024]);
    });
    test('arraybuffer values', () {
      expect(vm.jsToDart(vm.evalCode('var str = "Hello World!";var buf = new ArrayBuffer(str.length);var bv = new Uint8Array(buf);for(var i = 0;i<str.length;i++)bv[i]=str.charCodeAt(i);buf')), Uint8List.fromList(utf8.encode("Hello World!")));
    });
    test('function values', () {
      String actual = vm.jsToDart((vm.jsToDart(vm.evalCode(r'(function(message) {return `Hello ${this}!${message}`})')) as JSToDartFunction)([vm.newString("Flutter 2021!")], thisObj: vm.newString("World"))!);
      expect(actual, "Hello World!Flutter 2021!");
    });
    test('date values', () {
      vm.constructDate = false;
      expect(vm.jsToDart(vm.evalCode('new Date(1622470242901)')), 1622470242901);
      vm.constructDate = true;
      expect(vm.jsToDart(vm.evalCode('new Date(1622470242901)')), DateTime.fromMillisecondsSinceEpoch(1622470242901));
    });
    test('promise values', () async {
      expect(await (vm.jsToDart(vm.evalCode('new Promise((resolve, reject) => resolve("Hello World!"))')) as Future), "Hello World!");
      try {
        await (vm.jsToDart(vm.evalCode('new Promise((resolve, reject) => reject("Expected error."))')) as Future);
      } catch(e) {
        expect(e, isA<JSError>());
        expect((e as JSError).message, 'Expected error.');
      }
    });
    test('promise with timeout values', () async {
      final actual = await (vm.jsToDart(vm.evalCode('new Promise((resolve, reject) => setTimeout(function() {console.log(123);resolve("Hello World!")}, 1000)).then(_ => _ + "!")')) as Future);
      expect(actual, "Hello World!!");
    });
    test('object values', () {
      var expected = {'a':1,'b':'2', 'c': [1, 2, {'regex': {}, '2': 'number prop name'}, ]};
      vm.jsonSerializeObject = true;
      expect(vm.jsToDart(vm.evalCode(r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''')),
          expected);
      vm.jsonSerializeObject = false;
      expected = {'a':1,'b':'2', 'c': [1, 2, {'regex': {}, 'Symbol': null, '2': 'number prop name'}, ]};
      expect(vm.jsToDart(vm.evalCode(r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''')),
          expected);
    });
  });
}
