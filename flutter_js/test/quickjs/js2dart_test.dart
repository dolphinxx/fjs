import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_js/error.dart';
import 'package:flutter_js/types.dart';
import 'package:flutter_js/quickjs/vm.dart';
import 'package:test/test.dart';

void main() {
  group('js2dart', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('null values', () {
      expect(vm.evalAndConsume('null', (_) => vm.jsToDart(_)), isNull);
      vm.reserveUndefined = true;
      expect(vm.evalAndConsume('undefined', (_) => vm.jsToDart(_)), DART_UNDEFINED);
      expect(vm.evalAndConsume('var a;a', (_) => vm.jsToDart(_)), DART_UNDEFINED);
      vm.reserveUndefined = false;
      expect(vm.evalAndConsume('undefined', (_) => vm.jsToDart(_)), isNull);
      expect(vm.evalAndConsume('var a;a', (_) => vm.jsToDart(_)), isNull);
    });
    test('number values', () {
      expect(vm.consumeAndFree(vm.newNumber(1), (_) => vm.jsToDart(_)), 1.0);
      expect(vm.consumeAndFree(vm.newNumber(1.5), (_) => vm.jsToDart(_)), 1.5);
      expect(vm.evalAndConsume('1.500000', (_) => vm.jsToDart(_)), 1.5);
      expect(vm.evalAndConsume('1024102410241024', (_) => vm.jsToDart(_)), 1024102410241024);
      expect(vm.evalAndConsume('0xff', (_) => vm.jsToDart(_)), allOf(equals(0xff), isA<int>()), reason: 'Should get Dart int from JS int');
      expect(vm.evalAndConsume('Number("1.500000")', (_) => vm.jsToDart(_)), 1.5);
      expect(vm.evalAndConsume('new Number("1.500000")', (_) => vm.jsToDart(_)), 1.5);
    });
    test('bool values', () {
      expect(vm.evalAndConsume('true', (_) => vm.jsToDart(_)), isTrue);
      expect(vm.evalAndConsume('false', (_) => vm.jsToDart(_)), isFalse);
      expect(vm.evalAndConsume('Boolean("true")', (_) => vm.jsToDart(_)), isTrue);
      expect(vm.evalAndConsume('new Boolean(true)', (_) => vm.jsToDart(_)), isTrue);
    });
    test('string values', () {
      expect(vm.consumeAndFree(vm.evalCode('\'Hello World!\''), (_) => vm.jsToDart(_)), 'Hello World!');
      expect(vm.evalAndConsume('`Hello`', (_) => vm.jsToDart(_)), 'Hello');
      expect(vm.evalAndConsume('"Hello"', (_) => vm.jsToDart(_)), 'Hello');
      expect(vm.evalAndConsume('String("Hello")', (_) => vm.jsToDart(_)), 'Hello');
      expect(vm.evalAndConsume('new String("Hello")', (_) => vm.jsToDart(_)), 'Hello');
    });
    test('array values', () {
      expect(vm.evalAndConsume('[]', (_) => vm.jsToDart(_)), []);
      expect(vm.evalAndConsume('[`Hello`, "World", 2021]', (_) => vm.jsToDart(_)), ['Hello', 'World', 2021]);
      expect(vm.evalAndConsume('var array = new Array();array[1] = 1024;array', (_) => vm.jsToDart(_)), [null, 1024]);
    });
    test('arraybuffer values', () {
      expect(vm.evalAndConsume('var str = "Hello World!";var buf = new ArrayBuffer(str.length);var bv = new Uint8Array(buf);for(var i = 0;i<str.length;i++)bv[i]=str.charCodeAt(i);buf', (_) => vm.jsToDart(_)), Uint8List.fromList(utf8.encode("Hello World!")));
    });
    test('function values', () {
      String actual = vm.jsToDart(vm.evalAndConsume(r'(function(message) {return `Hello ${this}!${message}`})', (_) => (vm.jsToDart(_) as JSToDartFunction)([vm.newString("Flutter 2021!")], thisObj: vm.newString("World")))!);
      expect(actual, "Hello World!Flutter 2021!");
    });
    test('date values', () {
      vm.constructDate = false;
      expect(vm.evalAndConsume('new Date(1622470242901)', (_) => vm.jsToDart(_)), 1622470242901);
      vm.constructDate = true;
      expect(vm.evalAndConsume('new Date(1622470242901)', (_) => vm.jsToDart(_)), DateTime.fromMillisecondsSinceEpoch(1622470242901));
    });
    test('promise values', () async {
      var f = vm.evalAndConsume('new Promise((resolve, reject) => resolve("Hello World!")).then(_ => _ + "!")', (_) => vm.jsToDart(_)) as Future;
      vm.executePendingJobs();
      expect(await f, "Hello World!!");
      try {
        f = (vm.evalAndConsume('new Promise((resolve, reject) => reject("Expected error."))', (_) => vm.jsToDart(_)) as Future);
        vm.executePendingJobs();
        await f;
      } catch(e) {
        expect(e, isA<JSError>());
        expect((e as JSError).message, 'Expected error.');
      }
    });
    test('promise with timeout values', () async {
      final evalResult = vm.evalCode('''
      new Promise((resolve, reject) => 
        setTimeout(function() {
          console.log(1);
          resolve("Hello World!");
          console.log(2);
        }, 1000)
      ).then(function(_) {
        console.log(3);
        return _ + "!";
      })''');
      Future f = (vm.consumeAndFree(evalResult, (_) => vm.jsToDart(_)) as Future);
      // Use a delay or event loop
      Future.delayed(Duration(seconds: 3), () => vm.executePendingJobs());
      final actual = await f;
      expect(actual, "Hello World!!");
    });
    test('object values', () {
      var expected = {'a':1,'b':'2', 'c': [1, 2, {'regex': {}, '2': 'number prop name'}, ]};
      vm.jsonSerializeObject = true;
      expect(vm.evalAndConsume(r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''', (_) => vm.jsToDart(_)),
          expected);
      vm.jsonSerializeObject = false;
      expected = {'a':1,'b':'2', 'c': [1, 2, {'regex': {}, 'Symbol': null, '2': 'number prop name'}, ]};
      expect(vm.evalAndConsume(r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''', (_) => vm.jsToDart(_)),
          expected);
    });
  });
}
