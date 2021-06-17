import 'package:fjs/vm.dart';
import 'package:test/test.dart';

void testRegexCapturingGroup(Vm vm) {
  final actual = vm.jsToDart(vm.evalCode(
      r'/(?<greeting>hello)/ig.exec("Hello World!").groups.greeting'));
  expect(actual, 'Hello');
}
