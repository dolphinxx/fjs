import 'dart:typed_data';

import 'package:flutter_js/quickjs/vm.dart';
import 'package:test/test.dart';

void main() {
  group('dart2js', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('null values', () {
      vm.dartToJS(null).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'if(test!==null) throw "error"').dispose();
      });
    });
    test('undefined values', () {
      vm.dartToJS(DART_UNDEFINED).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'if(test!==undefined) throw "error"').dispose();
      });
    });
    test('number values', () {
      vm.dartToJS(1).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'if(test!==1) throw "error"').dispose();
      });
      vm.dartToJS(1.5).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'if(test!==1.5) throw "error"').dispose();
      });
      vm.dartToJS(1024102410241024).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'if(test!==1024102410241024) throw "error"').dispose();
      });
    });
    test('bool values', () {
      vm.dartToJS(true).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'if(test!==true) throw "error"').dispose();
      });
      vm.dartToJS(false).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'if(test!==false) throw "error"').dispose();
      });
    });
    test('string values', () {
      vm.dartToJS('Hello World!').consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'if(test!=="Hello World!") throw "error"').dispose();
      });
    });
    test('array values', () {
      vm.dartToJS(['Hello World!', 2021]).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'if(!(test instanceof Array) || test.length !== 2 || test[0] !== "Hello World!" || test[1] !== 2021) throw "error"').dispose();
      });
    });
    test('arraybuffer values', () {
      Uint8List data = Uint8List.fromList([1,2,3,4,5,6]);
      vm.dartToJS(data).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'''
        if(!(test instanceof ArrayBuffer)) throw "instanceof ArrayBuffer";
        if(test.byteLength !== 6) throw `expected byteLength=6, actual ${test.byteLength}`;
        var ub = new Uint8Array(test);if(ub[5] !== 6) throw `value in index 5 expected 6, actual ${ub[5]}, ${ub.toString()}`;
        ''').dispose();
      });
      vm.dartToJS(data).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'''
        if(!(test instanceof ArrayBuffer)) throw "instanceof ArrayBuffer";
        if(test.byteLength !== 6) throw `expected byteLength=6, actual ${test.byteLength}`;
        var ub = new Uint8Array(test);if(ub[5] !== 6) throw `value in index 5 expected 6, actual ${ub[5]}, ${ub.toString()}`;
        ''').dispose();
      });
    });
    test('function values', () {
      VmFunctionImplementation fn = (args, {thisObj}) {
        return vm.newString(args[0].consume((_) => 'Hello ${vm.jsToDart(_.value)}!'));
      };
      vm.dartToJS(fn).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'''if(typeof test !== 'function' || test('Flutter') != 'Hello Flutter!') throw "error"''').dispose();
      });
    });
    test('date values', () {
      vm.constructDate = false;
      vm.dartToJS(DateTime.fromMillisecondsSinceEpoch(1622537565122)).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'''if(typeof test !== 'number' || test !== 1622537565122) throw "error"''').dispose();
      });
      vm.constructDate = true;
      vm.dartToJS(DateTime.fromMillisecondsSinceEpoch(1622537565122)).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'''if(!(test instanceof Date) || test.getTime() != 1622537565122) throw "error"''').dispose();
      });
    });
    test('promise values', () async {
      Future f = Future.delayed(Duration(seconds: 1), () => 'Hello World!');
      final _ = vm.dartToJS(f);
      try {
        vm.setProperty(vm.global.value, 'test', _.value);
        final result = vm.evalUnsafe(r'''
        if(!(test instanceof Promise)) throw "expected: instanceof Proxy";
        test.then(_ => {if(_ !== "Hello World!") throw "error"})
        ''');
        await f;
        await vm.jsToDart(result.value);
        result.dispose();
      } finally {
        _.dispose();
      }
    });
    test('object values', () {
      vm.dartToJS({'a':1,'b':'2', 'c': [1, 2, {'regex': {}, 'Symbol': null, '2': 'number prop name'}, ]}).consume((_) {
        vm.setProperty(vm.global.value, 'test', _.value);
        vm.evalUnsafe(r'''
        if(typeof test !== 'object') throw "expected: typeof object";
        if(test.a !== 1) throw "expected: test.a === 1";
        if(test.b !== '2') throw "expected: test.b === '2'";
        if(!(test.c instanceof Array)) throw "expected: test.c instanceof Array";
        if(test.c[0] !== 1) throw "expected: test.c[0] === 1";
        if(!test.c[2].hasOwnProperty("Symbol")) throw "expected: test.c[2] hasOwnProperty 'Symbol'";
        ''').dispose();
      });
    });
  });
}
