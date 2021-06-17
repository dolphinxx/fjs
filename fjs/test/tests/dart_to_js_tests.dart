import 'dart:typed_data';

import 'package:fjs/vm.dart';

void testNullValues(Vm vm) {
  final _ = vm.dartToJS(null);
  vm.setProperty(vm.global, 'test', _);
  vm.evalCode(r'if(test!==null) throw "error"');
}

void testUndefinedValues(Vm vm) {
  final _ = vm.dartToJS(DART_UNDEFINED);
  vm.setProperty(vm.global, 'test', _);
  vm.evalCode(r'if(test!==undefined) throw "error"');
}

testNumberValues(Vm vm) {
  {
    final _ = vm.dartToJS(1);
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(r'if(test!==1) throw "error"');
  }
  {
    final _ = vm.dartToJS(1.5);
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(r'if(test!==1.5) throw "error"');
  }
  {
    final _ = vm.dartToJS(1024102410241024);
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(r'if(test!==1024102410241024) throw "error"');
  }
}

testBoolValues(Vm vm) {
  {
    final _ = vm.dartToJS(true);
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(r'if(test!==true) throw "error"');
  }
  {
    final _ = vm.dartToJS(false);
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(r'if(test!==false) throw "error"');
  }
}

testStringValues(Vm vm) {
  final _ = vm.dartToJS('Hello World!');
  vm.setProperty(vm.global, 'test', _);
  vm.evalCode(r'if(test!=="Hello World!") throw "error"');
}

testArrayValues(Vm vm) {
  final _ = vm.dartToJS(['Hello World!', 2021]);
  vm.setProperty(vm.global, 'test', _);
  vm.evalCode(
      r'if(!(test instanceof Array) || test.length !== 2 || test[0] !== "Hello World!" || test[1] !== 2021) throw "error"');
}

testArrayBufferValues(Vm vm) {
  Uint8List data = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
  {
    final _ = vm.dartToJS(data);
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(r'''
        if(!(test instanceof ArrayBuffer)) throw "instanceof ArrayBuffer";
        if(test.byteLength !== 6) throw `expected byteLength=6, actual ${test.byteLength}`;
        var ub = new Uint8Array(test);if(ub[5] !== 6) throw `value in index 5 expected 6, actual ${ub[5]}, ${ub.toString()}`;
        ''');
  }
  {
    final _ = vm.dartToJS(data);
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(r'''
        if(!(test instanceof ArrayBuffer)) throw "instanceof ArrayBuffer";
        if(test.byteLength !== 6) throw `expected byteLength=6, actual ${test.byteLength}`;
        var ub = new Uint8Array(test);if(ub[5] !== 6) throw `value in index 5 expected 6, actual ${ub[5]}, ${ub.toString()}`;
        ''');
  }
}

testFunctionValues(Vm vm) {
  JSToDartFunction fn = (args, {thisObj}) {
    return vm.newString('Hello ${vm.jsToDart(args[0])}!');
  };
  final _ = vm.dartToJS(fn);
  vm.setProperty(vm.global, 'test', _);
  vm.evalCode(r'''
          if(typeof test !== 'function') throw "error: typeof test should be 'function'";
          var result = test('Flutter');
          if(result != 'Hello Flutter!') throw `error: invoke result of test expected: 'Hello Flutter!', actual: ${result}`;
          ''');
}

testDateValues(Vm vm) {
  {
    vm.constructDate = false;
    final _ = vm.dartToJS(DateTime.fromMillisecondsSinceEpoch(1622537565122));
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(
        r'''if(typeof test !== 'number' || test !== 1622537565122) throw "error"''');
  }
  {
    vm.constructDate = true;
    final _ = vm.dartToJS(DateTime.fromMillisecondsSinceEpoch(1622537565122));
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(
        r'''if(!(test instanceof Date) || test.getTime() != 1622537565122) throw "error"''');
  }
}

testPromiseValues(Vm vm) async {
  Future f = Future.delayed(Duration(seconds: 1), () => 'Hello World!');
  final _ = vm.dartToJS(f);
  vm.setProperty(vm.global, 'test', _);
  final result = vm.evalCode(r'''
        if(!(test instanceof Promise)) throw "expected: instanceof Proxy";
        test.then(_ => {if(_ !== "Hello World!") throw "error"})
        ''');
  await f;
  final promise = vm.jsToDart(result);
  vm.startEventLoop();
  await promise;
}

testObjectValues(Vm vm) {
  final _ = vm.dartToJS({
    'a': 1,
    'b': '2',
    'c': [
      1,
      2,
      {'regex': {}, 'Symbol': null, '2': 'number prop name'},
    ]
  });
  vm.setProperty(vm.global, 'test', _);
  vm.evalCode(r'''
        if(typeof test !== 'object') throw "expected: typeof object";
        if(test.a !== 1) throw "expected: test.a === 1";
        if(test.b !== '2') throw "expected: test.b === '2'";
        if(!(test.c instanceof Array)) throw "expected: test.c instanceof Array";
        if(test.c[0] !== 1) throw "expected: test.c[0] === 1";
        if(!test.c[2].hasOwnProperty("Symbol")) throw "expected: test.c[2] hasOwnProperty 'Symbol'";
        ''');
}
