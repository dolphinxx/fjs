import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('dart2js', () {
    late FlutterDriver driver;
    // Connect to the Flutter driver before running any tests.
    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    // Close the connection to the driver after the tests have completed.
    tearDownAll(() async {
      driver.close();
    });
    runTest(dynamic data) async {
      await driver.runUnsynchronized(() async {
        dynamic result = jsonDecode(await driver.requestData(jsonEncode(data)));
        if (result['success'] != true) {
          throw result['error'];
        }
      });
    }

    test('null values', () async {
      await runTest({
        'group': 'dart2js',
        'dart': null,
        'code': r'if(test!==null) throw "error"',
      });
    });
    test('undefined values', () async {
      await runTest({
        'group': 'dart2js',
        'dartType': 'DART_UNDEFINED',
        'code': r'if(test!==undefined) throw "error"',
      });
    });
    test('number values', () async {
      await runTest([
        {
          'group': 'dart2js',
          'dart': 1,
          'code': r'if(test!==1) throw "error"',
        },
        {
          'group': 'dart2js',
          'dart': 1.5,
          'code': r'if(test!==1.5) throw "error"',
        },
        {
          'group': 'dart2js',
          'dart': 1024102410241024,
          'code': r'if(test!==1024102410241024) throw "error"',
        },
      ]);
    });
    test('bool values', () async {
      await runTest([
        {
          'group': 'dart2js',
          'dart': true,
          'code': r'if(test!==true) throw "error"',
        },
        {
          'group': 'dart2js',
          'dart': false,
          'code': r'if(test!==false) throw "error"',
        },
      ]);
    });
    test('string values', () async {
      await runTest({
        'group': 'dart2js',
        'dart': 'Hello World!',
        'code': r'if(test!=="Hello World!") throw "error"',
      });
    });
    test('array values', () async {
      await runTest({
        'group': 'dart2js',
        'dart': ['Hello World!', 2021],
        'code':
            r'if(!(test instanceof Array) || test.length !== 2 || test[0] !== "Hello World!" || test[1] !== 2021) throw "error"',
      });
    });
    test('arraybuffer values', () async {
      await runTest({
        'group': 'dart2js',
        'dartType': 'Uint8List',
        'dart': [1, 2, 3, 4, 5, 6],
        'code': r'''
        if(!(test instanceof ArrayBuffer)) throw "instanceof ArrayBuffer";
        if(test.byteLength !== 6) throw `expected byteLength=6, actual ${test.byteLength}`;
        var ub = new Uint8Array(test);if(ub[5] !== 6) throw `value in index 5 expected 6, actual ${ub[5]}, ${ub.toString()}`;
        ''',
      });
    });
    test('function values', () async {
      await runTest({
        'group': 'dart2js',
        'dartType': 'function',
        'code':
            r'''if(typeof test !== 'function') throw "expect a function, actual " + typeof test;var _ = test('Flutter');if(_ !== 'Hello Flutter!') throw "expect " + "\"Hello Flutter!\", actual \"" + _ + "\""''',
      });
    });
    test('date values', () async {
      await runTest([
        {
          'group': 'dart2js',
          'vmOptions': [
            ['constructDate', false]
          ],
          'dartType': 'DateTime',
          'dart': 1622537565122,
          'code':
              r'''if(typeof test !== 'number' || test !== 1622537565122) throw "error"''',
        },
        {
          'group': 'dart2js',
          'vmOptions': [
            ['constructDate', true]
          ],
          'dartType': 'DateTime',
          'dart': 1622537565122,
          'code':
              r'''if(!(test instanceof Date) || test.getTime() != 1622537565122) throw "error"''',
        }
      ]);
    });
    test('promise values', () async {
      await runTest({
        'group': 'dart2js',
        'eventLoop': true,
        'dartType': 'Future',
        'code': r'''
        if(!(test instanceof Promise)) throw "expected: instanceof Proxy";
        test.then(_ => {if(_ !== "Hello World!") throw "error"})
        ''',
      });
    });
    test('object values', () async {
      await runTest({
        'group': 'dart2js',
        'dart': {
          'a': 1,
          'b': '2',
          'c': [
            1,
            2,
            {'regex': {}, 'Symbol': null, '2': 'number prop name'},
          ]
        },
        'code': r'''
        if(typeof test !== 'object') throw "expected: typeof object";
        if(test.a !== 1) throw "expected: test.a === 1";
        if(test.b !== '2') throw "expected: test.b === '2'";
        if(!(test.c instanceof Array)) throw "expected: test.c instanceof Array";
        if(test.c[0] !== 1) throw "expected: test.c[0] === 1";
        if(!test.c[2].hasOwnProperty("Symbol")) throw "expected: test.c[2] hasOwnProperty 'Symbol'";
        ''',
      });
    });
  });
}
