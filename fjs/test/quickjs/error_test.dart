import 'package:fjs/error.dart';
import 'package:fjs/quickjs/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('QuickJSVm', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('QuickJSVm error from host', capturePrint(() {
      final fnPtr = vm.newFunction(null, (args, {thisObj}) {
        var a = [];
        a as String;
      });
      vm.setProperty(vm.global, 'fn', fnPtr);
      try {
        vm.evalCode('fn()');
        throw 'should throw an error.';
      } catch(e) {
        expect(e, isA<JSError>());
        e as JSError;
        expect(e.message, "type 'List<dynamic>' is not a subtype of type 'String' in type cast");
        expect(e.stackTrace.toString(), contains('/test/quickjs/error_test.dart'));
      }
    }));
    test('QuickJSVm error from JS', capturePrint(() {
      try {
        vm.evalCode('foo()', filename: '<test.js>');
        throw 'should throw an error.';
      } catch(e) {
        expect(e, isA<JSError>());
        e as JSError;
        expect(e.message, "\'foo\' is not defined");
        expect(e.stackTrace.toString(), contains('(<test.js>)'));
      }
    }));
  });
}
