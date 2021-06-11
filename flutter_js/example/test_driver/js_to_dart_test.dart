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
      await runTest([
        {
          'group': 'js2dart',
          'code': 'null',
          'dart': null,
        },
        {
          'group': 'js2dart',
          'vmOptions': [
            ['reserveUndefined', true]
          ],
          'code': 'undefined',
          'dartType': 'DART_UNDEFINED'
        },
        {
          'group': 'js2dart',
          'vmOptions': [
            ['reserveUndefined', true]
          ],
          'code': 'var a;a',
          'dartType': 'DART_UNDEFINED'
        },
        {
          'group': 'js2dart',
          'vmOptions': [
            ['reserveUndefined', false]
          ],
          'code': 'undefined',
          'dartType': null
        },
        {
          'group': 'js2dart',
          'vmOptions': [
            ['reserveUndefined', false]
          ],
          'code': 'var a;a',
          'dartType': null
        },
      ]);
    });
    test('number values', () async {
      await runTest([
        {
          'group': 'js2dart',
          'code': '1',
          'dart': 1,
        },
        {
          'group': 'js2dart',
          'code': '1.5',
          'dart': 1.5,
        },
        {
          'group': 'js2dart',
          'code': '1.50000000',
          'dart': 1.5,
        },
        {
          'group': 'js2dart',
          'code': '1024102410241024',
          'dart': 1024102410241024,
        },
        {
          'group': 'js2dart',
          'code': '0xff',
          'dart': 0xff,
        },
        {
          'group': 'js2dart',
          'code': 'Number("1.500000")',
          'dart': 1.5,
        },
        {
          'group': 'js2dart',
          'code': 'new Number("1.500000")',
          'dart': 1.5,
        },
      ]);
    });
    test('bool values', () async {
      await runTest([
        {
          'group': 'js2dart',
          'code': 'true',
          'dart': true,
        },
        {
          'group': 'js2dart',
          'code': 'false',
          'dart': false,
        },
        {
          'group': 'js2dart',
          'code': 'Boolean("true")',
          'dart': true,
        },
        {
          'group': 'js2dart',
          // like !!"false"
          'code': 'Boolean("false")',
          'dart': true,
        },
        {
          'group': 'js2dart',
          'code': 'Boolean(true)',
          'dart': true,
        },
        {
          'group': 'js2dart',
          'code': 'Boolean(false)',
          'dart': false,
        },
        {
          'group': 'js2dart',
          'code': 'new Boolean(true)',
          'dart': true,
        },
        {
          'group': 'js2dart',
          'code': 'new Boolean(false)',
          // like !!{}
          'dart': true,
        },
      ]);
    });
    test('string values', () async {
      await runTest([
        {
          'group': 'js2dart',
          'code': '\'Hello World!\'',
          'dart': 'Hello World!',
        },
        {
          'group': 'js2dart',
          'code': '`Hello`',
          'dart': 'Hello',
        },
        {
          'group': 'js2dart',
          'code': '"Hello"',
          'dart': 'Hello',
        },
        {
          'group': 'js2dart',
          'code': 'String("Hello")',
          'dart': 'Hello',
        },
        {
          'group': 'js2dart',
          'code': 'new String("Hello")',
          'dart': 'Hello',
        },
      ]);
    });
    test('array values', () async {
      await runTest([
        {
          'group': 'js2dart',
          'code': '[]',
          'dart': [],
        },
        {
          'group': 'js2dart',
          'code': '[`Hello`, "World", 2021]',
          'dart': ['Hello', 'World', 2021],
        },
        {
          'group': 'js2dart',
          'code': 'var array = new Array();array[1] = 1024;array',
          'dart': [null, 1024],
        },
      ]);
    });
    test('arraybuffer values', () async {
      await runTest({
        'group': 'js2dart',
        'dartType': 'Uint8List',
        'dart': utf8.encode("Hello World!"),
        'code':
            'var str = "Hello World!";var buf = new ArrayBuffer(str.length);var bv = new Uint8Array(buf);for(var i = 0;i<str.length;i++)bv[i]=str.charCodeAt(i);buf',
      });
    });
    test('function values', () async {
      await runTest({
        'group': 'js2dart',
        'code': r'(function(message) {return `Hello ${this}!${message}`})',
        'jsArgs': ["Flutter 2021!"],
        'jsThisObj': "World",
        'dart': "Hello World!Flutter 2021!",
      });
    });
    test('date values', () async {
      await runTest([
        {
          'group': 'js2dart',
          'vmOptions': [
            ['constructDate', false]
          ],
          'code': 'new Date(1622470242901)',
          'dart': 1622470242901,
        },
        {
          'group': 'js2dart',
          'vmOptions': [
            ['constructDate', true]
          ],
          'code': 'new Date(1622470242901)',
          'dart': 1622470242901,
          'dartType': 'DateTime',
        },
      ]);
    });
    test('promise values fulfilled', () async {
      await runTest({
        'group': 'js2dart',
        'eventLoop': true,
        'code':
            'new Promise((resolve, reject) => resolve("Hello World!")).then(_ => _ + "!")',
        'dart': "Hello World!!",
      });
    });
    test('promise values rejected', () async {
      await runTest({
        'group': 'js2dart',
        'eventLoop': true,
        'code': 'new Promise((resolve, reject) => reject("Expected error."))',
        'error': 'Expected error.',
      });
    });
    test('promise with timeout values', () async {
      await runTest({
        'group': 'js2dart',
        'eventLoop': true,
        'code': '''
      new Promise((resolve, reject) => 
        setTimeout(function() {
          console.log(1);
          resolve("Hello World!");
          console.log(2);
        }, 1000)
      ).then(function(_) {
        console.log(3);
        return _ + "!";
      })''',
        'dart': "Hello World!!",
      });
    });
    test('object values', () async {
      await runTest([
        {
          'group': 'js2dart',
          'vmOptions': [
            ['jsonSerializeObject', true]
          ],
          'dart': {
            'a': 1,
            'b': '2',
            'c': [
              1,
              2,
              {'regex': {}, '2': 'number prop name'},
            ]
          },
          'code':
              r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''',
        },
        {
          'group': 'js2dart',
          'vmOptions': [
            ['jsonSerializeObject', false]
          ],
          'dart': {
            'a': 1,
            'b': '2',
            'c': [
              1,
              2,
              {'regex': {}, 'Symbol': null, '2': 'number prop name'},
            ]
          },
          'code':
              r'''({a:1,b:"2", 'c':[1, 2, {regex: /.*/, 'Symbol': Symbol(1), 2: 'number prop name'}, ]})''',
        },
      ]);
    });
  });
}
