import 'package:fjs/error.dart';
import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('JavaScriptCore', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('JavaScriptCore error from host', capturePrint(() {
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
        expect(e.stackTrace.toString(), contains('/test/javascriptcore/error_test.dart'));
      }
    }));
    test('JavaScriptCore error from JS', capturePrint(() {
      try {
        vm.evalCode('foo()', filename: '<test.js>');
        throw 'should throw an error.';
      } catch(e) {
        expect(e, isA<JSError>());
        e as JSError;
        expect(e.message, "Can't find variable: foo");
        expect(e.stackTrace.toString(), contains('<test.js>:1:4'));
      }
    }));
  });
}
