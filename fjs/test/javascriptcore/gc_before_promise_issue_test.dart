import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';

import 'dart:io';

void main() {
  test('normal_future_object', () async {
    // success
    JavaScriptCoreVm vm = JavaScriptCoreVm();
    vm.setProperty(vm.global, 'data', vm.dartToJS(Future.delayed(Duration(seconds: 1), () => Future.delayed(Duration(seconds: 2), () => {'data': File('test/json-generator-dot-com-2048-rows.json').readAsStringSync()}))));
    var actual = await Future.value(vm.jsToDart(vm.evalCode('''data''')));
    vm.dispose();
    print((actual as Map).length);
  });
  test('normal_fn_object', () async {
    // success
    JavaScriptCoreVm vm = JavaScriptCoreVm();
    var fn = vm.newFunction(null, (args, {thisObj}) {
      return vm.dartToJS({'data': File('test/json-generator-dot-com-2048-rows.json').readAsStringSync()});
    });
    vm.setProperty(vm.global, 'fn', fn);
    var actual = await Future.value(vm.jsToDart(vm.evalCode('''fn()''')));
    vm.dispose();
    print((actual as Map).length);
  });
  test('fn_future_object', () async {
    // failed before fix
    JavaScriptCoreVm vm = JavaScriptCoreVm();
    var fn = vm.newFunction(null, (args, {thisObj}) {
      return vm.dartToJS(Future.delayed(Duration(seconds: 2), () => ({'data': File('test/json-generator-dot-com-2048-rows.json').readAsStringSync()})));
    });
    vm.setProperty(vm.global, 'fn', fn);
    var actual = await Future.value(vm.jsToDart(vm.evalCode('''fn()''')));
    vm.dispose();
    print((actual as Map).length);
  });
  test('fn_future_string', () async {
    // failed before fix
    JavaScriptCoreVm vm = JavaScriptCoreVm();
    var fn = vm.newFunction(null, (args, {thisObj}) {
      return vm.dartToJS(Future.delayed(Duration(seconds: 2), () => File('test/json-generator-dot-com-2048-rows.json').readAsStringSync()));
    });
    vm.setProperty(vm.global, 'fn', fn);
    var actual = await Future.value(vm.jsToDart(vm.evalCode('''fn()''')));
    vm.dispose();
    print((actual as String).length);
  });
}