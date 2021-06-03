import 'dart:async';
import 'dart:io';

import 'package:flutter_js/javascriptcore/vm.dart';
import 'package:flutter_js/quickjs/vm.dart';
import 'package:test/test.dart';

var log = [];
// https://stackoverflow.com/questions/14764323/how-do-i-mock-or-verify-a-call-to-print-in-dart-unit-tests/14765018#answer-38709440
void Function() overridePrint(void testFn()) => () {
  var spec = new ZoneSpecification(
      print: (_, __, ___, String msg) {
        // Add to log instead of printing to stdout
        log.add(msg);
        stdout.writeln(msg);
      }
  );
  return Zone.current.fork(specification: spec).run<void>(testFn);
};

void main() {
  group('QuickJS', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('QuickJS console.log', overridePrint(() async {
      vm.evalUnsafe('console.log(1, 2, 3)');
      expect(log.last, equals("1 2 3"));
      log.clear();
      vm.evalUnsafe(r'''console.log('Hello', "World", 2021, "!")''');
      expect(log.last, equals("Hello World 2021 !"));
      log.clear();
      vm.evalUnsafe(r'''console.log({a:1, b:'2'}, [1, 2, 3], Symbol(1), /./, new Date(1622737824029))''');
      expect(log.last, equals("{a: 1, b: 2} [1, 2, 3] null {} 2021-06-04 00:30:24.029"));
      log.clear();
    }));
  });
  group('JavaScriptCore', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('JavaScriptCore console.log', overridePrint(() {
      vm.evalCode('console.log(1, 2, 3)');
      expect(log.last, equals("1 2 3"));
      log.clear();
      vm.evalCode(r'''console.log('Hello', "World", 2021, "!")''');
      expect(log.last, equals("Hello World 2021 !"));
      log.clear();
      vm.evalCode(r'''console.log({a:1, b:'2'}, [1, 2, 3], Symbol(1), /./, new Date(1622737824029))''');
      expect(log.last, equals("{a: 1, b: 2} [1, 2, 3] null {} 2021-06-04 00:30:24.029"));
      log.clear();
    }));
  });
}
