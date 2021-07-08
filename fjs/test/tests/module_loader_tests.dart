import 'dart:io';

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

testUniversal(Vm vm) async {
  vm.registerModuleResolver('greeting', (vm, path, version) => vm.newFunction('greeting', (args, {thisObj}) => vm.dartToJS('Hello ${vm.jsToDart(args[0])}!')));
  vm.registerModuleResolver('', (vm, path, version) {
    File file = File('test/modules/${path.join("/")}.js');
    if(file.existsSync()) {
      String source = file.readAsStringSync();
      return vm.evalCode('var exports = {};$source;exports', filename: '<${path.join("/")}.js>');
    }
    return vm.$undefined;
  });
  var actual = vm.jsToDart(vm.evalCode('''
  const greeting = require('greeting');
  greeting("Flutter");
  '''));
  expect(actual, "Hello Flutter!");
  actual = vm.jsToDart(vm.evalCode('''
  const {plus} = require('plus');
  plus(1, 2);
  '''));
  expect(actual, 3);
  actual = vm.jsToDart(vm.evalCode('''
  const minus = require('minus');
  minus(3, 2);
  '''));
  expect(actual, 1);
  actual = vm.jsToDart(vm.evalCode('''
  require('foo');
  '''));
  expect(actual, isNull);
}