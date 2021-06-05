import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_js/error.dart';
import 'package:flutter_js/lifetime.dart';
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
      expect(vm.evalUnsafe('null').consume((lifetime) => vm.jsToDart(lifetime.value)), isNull);
      vm.reserveUndefined = true;
      expect(vm.evalUnsafe('undefined').consume((lifetime) => vm.jsToDart(lifetime.value)), DART_UNDEFINED);
      expect(vm.evalUnsafe('var a;a').consume((lifetime) => vm.jsToDart(lifetime.value)), DART_UNDEFINED);
      vm.reserveUndefined = false;
      expect(vm.evalUnsafe('undefined').consume((lifetime) => vm.jsToDart(lifetime.value)), isNull);
      expect(vm.evalUnsafe('var a;a').consume((lifetime) => vm.jsToDart(lifetime.value)), isNull);
    });
    test('number values', () {
      expect(vm.newNumber(1).consume((lifetime) => vm.jsToDart(lifetime.value)), 1.0);
      expect(vm.newNumber(1.5).consume((lifetime) => vm.jsToDart(lifetime.value)), 1.5);
      expect(vm.evalUnsafe('1.500000').consume((lifetime) => vm.jsToDart(lifetime.value)), 1.5);
      expect(vm.evalUnsafe('1024102410241024').consume((lifetime) => vm.jsToDart(lifetime.value)), 1024102410241024);
      expect(vm.evalUnsafe('0xff').consume((lifetime) => vm.jsToDart(lifetime.value)), allOf(equals(0xff), isA<int>()), reason: 'Should get Dart int from JS int');
      expect(vm.evalUnsafe('Number("1.500000")').consume((lifetime) => vm.jsToDart(lifetime.value)), 1.5);
      expect(vm.evalUnsafe('new Number("1.500000")').consume((lifetime) => vm.jsToDart(lifetime.value)), 1.5);
    });
    test('bool values', () {
      expect(vm.evalUnsafe('true').consume((lifetime) => vm.jsToDart(lifetime.value)), isTrue);
      expect(vm.evalUnsafe('false').consume((lifetime) => vm.jsToDart(lifetime.value)), isFalse);
      expect(vm.evalUnsafe('Boolean("true")').consume((lifetime) => vm.jsToDart(lifetime.value)), isTrue);
      expect(vm.evalUnsafe('new Boolean(true)').consume((lifetime) => vm.jsToDart(lifetime.value)), isTrue);
    });
    test('string values', () {
      expect(vm.evalUnsafe('\'Hello World!\'').consume((lifetime) => vm.jsToDart(lifetime.value)), 'Hello World!');
      expect(vm.evalUnsafe('`Hello`').consume((lifetime) => vm.jsToDart(lifetime.value)), 'Hello');
      expect(vm.evalUnsafe('"Hello"').consume((lifetime) => vm.jsToDart(lifetime.value)), 'Hello');
      expect(vm.evalUnsafe('String("Hello")').consume((lifetime) => vm.jsToDart(lifetime.value)), 'Hello');
      expect(vm.evalUnsafe('new String("Hello")').consume((lifetime) => vm.jsToDart(lifetime.value)), 'Hello');
    });
    test('array values', () {
      expect(vm.evalUnsafe('[]').consume((lifetime) => vm.jsToDart(lifetime.value)), []);
      expect(vm.evalUnsafe('[`Hello`, "World", 2021]').consume((lifetime) => vm.jsToDart(lifetime.value)), ['Hello', 'World', 2021]);
      expect(vm.evalUnsafe('var array = new Array();array[1] = 1024;array').consume((lifetime) => vm.jsToDart(lifetime.value)), [null, 1024]);
    });
    test('arraybuffer values', () {
      expect(vm.evalUnsafe('var str = "Hello World!";var buf = new ArrayBuffer(str.length);var bv = new Uint8Array(buf);for(var i = 0;i<str.length;i++)bv[i]=str.charCodeAt(i);buf').consume((lifetime) => vm.jsToDart(lifetime.value)), Uint8List.fromList(utf8.encode("Hello World!")));
    });
    test('function values', () {
      Scope.withScope((scope) {
        String actual = vm.jsToDart(vm.evalUnsafe(r'(function(message) {return `Hello ${this}!${message}`})').consume((lifetime) => (vm.jsToDart(lifetime.value) as JSToDartFunction)([scope.manage(vm.newString("Flutter 2021!")).value], thisObj: scope.manage(vm.newString("World")).value))!);
        expect(actual, "Hello World!Flutter 2021!");
      });
    });
    test('date values', () {
      vm.constructDate = false;
      expect(vm.evalUnsafe('new Date(1622470242901)').consume((lifetime) => vm.jsToDart(lifetime.value)), 1622470242901);
      vm.constructDate = true;
      expect(vm.evalUnsafe('new Date(1622470242901)').consume((lifetime) => vm.jsToDart(lifetime.value)), DateTime.fromMillisecondsSinceEpoch(1622470242901));
    });
    test('promise values', () async {
      var f = vm.evalUnsafe('new Promise((resolve, reject) => resolve("Hello World!")).then(_ => _ + "!")').consume((lifetime) => vm.jsToDart(lifetime.value)) as Future;
      vm.executePendingJobs();
      expect(await f, "Hello World!!");
      try {
        f = (vm.evalUnsafe('new Promise((resolve, reject) => reject("Expected error."))').consume((lifetime) => vm.jsToDart(lifetime.value)) as Future);
        vm.executePendingJobs();
        await f;
      } catch(e) {
        expect(e, isA<JSError>());
        expect((e as JSError).message, 'Expected error.');
      }
    });
    test('promise with timeout values', () async {
      final evalResult = vm.evalUnsafe('''
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
      Future f = (evalResult.consume((lifetime) => vm.jsToDart(lifetime.value)) as Future);
      // Use a delay or event loop
      Future.delayed(Duration(seconds: 3), () => vm.executePendingJobs());
      final actual = await f;
      expect(actual, "Hello World!!");
    });
    test('object values', () {
      var expected = {'a':1,'b':'2', 'c': [1, 2, {'regex': {}, '2': 'number prop name'}, ]};
      vm.jsonSerializeObject = true;
      expect(vm.evalUnsafe(r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''').consume((lifetime) => vm.jsToDart(lifetime.value)),
          expected);
      vm.jsonSerializeObject = false;
      expected = {'a':1,'b':'2', 'c': [1, 2, {'regex': {}, 'Symbol': null, '2': 'number prop name'}, ]};
      expect(vm.evalUnsafe(r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''').consume((lifetime) => vm.jsToDart(lifetime.value)),
          expected);
    });
  });
}
