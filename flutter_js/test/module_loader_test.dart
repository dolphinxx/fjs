import 'dart:async';

import 'package:flutter_js/javascriptcore/vm.dart';
import 'package:flutter_js/module.dart';
import 'package:flutter_js/quickjs/vm.dart';
import 'package:flutter_js/quickjs/qjs_ffi.dart';
import 'package:flutter_js/vm.dart';
import 'package:test/test.dart';

class GreetingModule extends FlutterJSModule {
  final String name = 'greeting';
  JSValuePointer? cache;
  JSValuePointer resolve(Vm vm) {
    if(vm is QuickJSVm) {
      if(cache == null) {
        cache = vm.newFunction(null, (args, {thisObj}) {
          return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
        });
      }
      return vm.dupRef(cache!);
    }
    if(vm is JavaScriptCoreVm) {
      return cache = cache ?? vm.newFunction(null, (args, {thisObj}) {
        return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
      });
    }
    throw 'unsupported!';
  }
}

class AsyncGreetingModule extends FlutterJSModule {
  final String name = 'async_greeting';

  @override
  JSValuePointer resolve(Vm vm) {
    if(vm is QuickJSVm) {
      return vm.newPromise(Future.delayed(Duration(seconds: 2), () => vm.newFunction(null, (args, {thisObj}) {
        print('async greeting called.');
        return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
      }))).promise.value;
    }
    if(vm is JavaScriptCoreVm) {
      return vm.newPromise(Future.delayed(Duration(seconds: 2), () => vm.newFunction(null, (args, {thisObj}) {
        return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
      }))).promise.value;
    }
    throw 'unsupported!';
  }
}

void main() {
  group('QuickJS', () {
    late QuickJSVm vm;
    setUp(() {
      vm = QuickJSVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('QuickJS module_loader simple', () async {
      vm.registerModule(GreetingModule());
      var actual = vm.evalAndConsume('''
      var greeting = require("greeting");
      var greeting = require("greeting");
      var greeting = require("greeting");
      greeting("Flutter");
      ''', (_) => vm.jsToDart(_));
      expect(actual, 'Hello Flutter!');
      print(actual);
    });
    test('QuickJS module_loader async', () async {
      vm.registerModule(AsyncGreetingModule());
      final result = vm.evalCode('''
      require("async_greeting").then(greeting => greeting("Flutter"));
      ''');
      var actual = vm.jsToDart(result);
      Future.delayed(Duration(seconds: 3), () => vm.executePendingJobs());
      final actualStr = await Future.value(actual);
      expect(actualStr, 'Hello Flutter!');
      print(actualStr);
    });
  });
  group('JavaScriptCore', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('JavaScriptCore module_loader simple', () async {
      vm.registerModule(GreetingModule());
      final actual = vm.jsToDart(vm.evalCode('''
      var greeting = require("greeting");
      var greeting = require("greeting");
      var greeting = require("greeting");
      greeting("Flutter");
      '''));
      expect(actual, 'Hello Flutter!');
      print(actual);
    });
    test('JavaScriptCore module_loader async', () async {
      vm.registerModule(AsyncGreetingModule());
      var actual = vm.jsToDart(vm.evalCode('''
      require("async_greeting").then(greeting => greeting("Flutter"));
      '''));
      final actualStr = await Future.value(actual);
      expect(actualStr, 'Hello Flutter!');
      print(actualStr);
    });
  });
}
