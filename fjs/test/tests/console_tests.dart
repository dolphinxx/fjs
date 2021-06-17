import 'package:test/test.dart';
import '../test_utils.dart';
import 'package:fjs/vm.dart';

testConsoleLog(Vm vm) {
  vm.evalCode('console.log(1, 2, 3)');
  expect(consumeLastPrint(), equals("1 2 3"));
  vm.evalCode(r'''console.log('Hello', "World", 2021, "!")''');
  expect(consumeLastPrint(), equals("Hello World 2021 !"));
  vm.evalCode(
      r'''console.log({a:1, b:'2'}, [1, 2, 3], Symbol(1), /./, new Date(1622737824029))''');
  expect(consumeLastPrint(),
      equals("{a: 1, b: 2} [1, 2, 3] null {} 2021-06-04 00:30:24.029"));
}
