import 'package:fjs/module.dart';
import 'package:fjs/vm.dart';
import 'package:test/test.dart';

class GreetingModule extends FlutterJSModule {
  final String name = 'greeting';
  JSValuePointer? cache;

  JSValuePointer resolve(Vm vm, List<String> path, String? version) {
    return cache = cache ??
        vm.newFunction(null, (args, {thisObj}) {
          return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
        });
  }
}

class AsyncGreetingModule extends FlutterJSModule {
  final String name = 'async_greeting';

  @override
  JSValuePointer resolve(Vm vm, List<String> path, String? version) {
    return vm
        .newPromise(Future.delayed(
            Duration(seconds: 2),
            () => vm.newFunction(null, (args, {thisObj}) {
                  print('async greeting called.');
                  return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
                })))
        .promise
        .value;
  }
}

testSimple(Vm vm) {
  vm.registerModule(GreetingModule());
  final actual = vm.jsToDart(vm.evalCode('''
      var greeting = require("greeting");
      var greeting = require("greeting");
      var greeting = require("greeting");
      greeting("Flutter");
      '''));
  expect(actual, 'Hello Flutter!');
  print(actual);
}

testAsync(Vm vm) async {
  vm.startEventLoop();
  vm.registerModule(AsyncGreetingModule());
  var actual = vm.jsToDart(vm.evalCode('''
      require("async_greeting").then(greeting => greeting("Flutter"));
      '''));
  final actualStr = await Future.value(actual);
  expect(actualStr, 'Hello Flutter!');
  print(actualStr);
}
