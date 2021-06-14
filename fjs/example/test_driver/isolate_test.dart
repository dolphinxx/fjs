import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('Isolate', () {
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

    test('compute', () async {
      await runTest({
        'group': 'compute',
        'code': 'function plus(a,b){return a + b}plus("Hello ","World!")',
        'dart': "Hello World!",
      });
    });

    test('isolate', () async {
      await runTest({
        'group': 'isolate',
        'code': r'require("greeting")("Flutter").then(function(_) {return `${_}!`})',
        'dart': "Hello Flutter!!",
      });
    });
  });
}