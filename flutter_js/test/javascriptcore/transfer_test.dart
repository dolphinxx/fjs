import 'package:flutter_js/javascriptcore/vm.dart';
import 'package:test/test.dart';

void main() {
  group('transfer', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('dart to js to dart', () async {
      final expected = {'name': 'Les Misérables', 'author': 'Victor Marie Hugo'};
      final js = vm.dartToJS(expected);
      final actual = vm.jsToDart(js);
      expect(actual, expected);
    });
    test('js to dart to js', () async {
      final expected = vm.evalCode('''const expected = {'name': 'Les Misérables', 'author': 'Victor Marie Hugo'};expected''');
      final dart = vm.jsToDart(expected);
      final actual = vm.dartToJS(dart);
      vm.setProperty(vm.global, 'actual', actual);
      vm.evalCode(r'''
      function assertEqual(e, a) {
        if(e !== a) throw `expect ${a} and ${a} to be equal.`;
      }
      for(let o in expected) {
        if(expected.hasOwnProperty(o)) {
          assertEqual(expected[o], actual[o]);
        }
      }
      for(let o in actual) {
        if(actual.hasOwnProperty(o)) {
          assertEqual(expected[o], actual[o])
        }
      }
      console.log(expected, actual);
      ''');
    });
  });
}