import 'package:fjs/vm.dart';
import 'package:test/test.dart';

void testRegexCapturingGroup(Vm vm) {
  final actual = vm.jsToDart(vm.evalCode(
      r'/(?<greeting>hello)/ig.exec("Hello World!").groups.greeting'));
  expect(actual, 'Hello');
}

/// ```javascript
/// JSON.stringify(undefined)// undefined
/// JSON.stringify(null)// null
/// JSON.stringify(1)// 1
/// JSON.stringify(1.1)// 1.1
/// JSON.stringify(Number(1.1))// 1.1
/// JSON.stringify(new Number(1.1))// 1.1
/// JSON.stringify(NaN)// null
/// JSON.stringify(Infinity)// null
/// JSON.stringify(1/0)// null
/// JSON.stringify(true)// true
/// JSON.stringify(false)// false
/// JSON.stringify(Boolean(true))// true
/// JSON.stringify(Boolean(false))// false
/// JSON.stringify(new Boolean(true))// true
/// JSON.stringify(new Boolean(false))// false
/// JSON.stringify('Hello')// "Hello"
/// JSON.stringify(String('Hello'))// "Hello"
/// JSON.stringify(new String('Hello'))// "Hello"
/// JSON.stringify(`Hello ${'World'}`)// "Hello World"
/// JSON.stringify({a:1,b:true,c:'Hello'})// {"a":1,"b":true,"c":"Hello"}
/// JSON.stringify([1, 'Hello', true])// [1,"Hello",true]
/// JSON.stringify(Symbol('Hello'))// undefined
/// JSON.stringify(/Hello/)// {}
/// JSON.stringify(() => Hello)// undefined
/// ```
void testJSONStringify(Vm vm) {
  List<List<dynamic>> tests = [
    ['undefined', 'undefined'],
    ['null', 'null'],
    ['1', '1'],
    ['1.1', '1.1'],
    ['Number(1.1)', '1.1'],
    ['new Number(1.1)', '1.1'],
    ['NaN', 'null'],
    ['Infinity', 'null'],
    ['1/0', 'null'],
    ['true', 'true'],
    ['false', 'false'],
    ['Boolean(true)', 'true'],
    ['Boolean(false)', 'false'],
    ['new Boolean(true)', 'true'],
    ['new Boolean(false)', 'false'],
    ['"Hello"', '"Hello"'],
    ['String("Hello")', '"Hello"'],
    ['new String("Hello")', '"Hello"'],
    ['`Hello ${"World"}`', '"Hello World"'],
    ['({a:1,b:true,c:"Hello"})', '{"a":1,"b":true,"c":"Hello"}'],
    ['[1, "Hello", true]', '[1,"Hello",true]'],
    ['Symbol("Hello")', 'undefined'],
    ['/Hello/', '{}'],
    ['(() => Hello)', 'undefined'],
  ];
  for(var t in tests) {
    String? actual = vm.JSONStringify(vm.evalCode(t[0]));
    expect(actual, t[1], reason: 'JSON.stringify(${t[0]}) == ${t[1]}');
  }
}