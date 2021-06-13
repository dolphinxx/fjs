import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('setTimeout', () {
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

    test('setTimeout lambda', () async {
      await runTest({
        'group': 'setTimeout',
        'code': 'setTimeout(() => console.log(1024), 1000)',
        'expected': '1024',
      });
    });

    test('JavaScriptCore setTimeout legacy', () async {
      await runTest({
        'group': 'setTimeout',
        'code': 'setTimeout(function() {console.log(1024)}, 1000)',
        'expected': '1024',
      });
    });
    test('JavaScriptCore setTimeout throw', () async {
      await runTest({
        'group': 'setTimeout',
        'code': 'setTimeout(function() {throw "Expected error."}, 1000)',
        'expected': null,
      });
      // Exception is ignored in JavaScriptCore implementation, need to try/catch exception inside the setTimeout callback by your self.
    });
    test('JavaScriptCore clearTimeout', () async {
      await runTest({
        'group': 'setTimeout',
        'code': 'var id = setTimeout(() => console.log(1024), 2000);clearTimeout(id)',
        'expected': null,
      });
    });
    test('JavaScriptCore setTimeout nested', () async {
      await runTest({
        'group': 'setTimeout',
        'code': 'setTimeout(() => setTimeout(() => console.log(1024), 1000), 1000)',
        'interval': 3000,
        'expected': '1024',
      });
    });
  });
}