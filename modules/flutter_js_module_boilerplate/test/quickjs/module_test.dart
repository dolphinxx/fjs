import 'package:flutter_js/quickjs/vm.dart';
import 'package:flutter_js/vm.dart';
import 'package:flutter_js_module_boilerplate/module.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('greeting_module', () {
    late Vm vm;
    setUp(() async {
      vm = QuickJSVm();
      vm.registerModule(FlutterJSGreetingModule());
    });
    tearDown(() {
      vm.dispose();
    });
    test('greeting', () async {
      vm.startEventLoop();
      final ptr = vm.evalCode(r'''require("greeting").greeting("Flutter")''');
      final f = vm.jsToDart(ptr);
      final actual = await f;
      expect(actual, 'Hello Flutter!');
    });
  });
}