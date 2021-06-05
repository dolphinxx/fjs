import 'dart:async';

import 'package:flutter_js/javascriptcore/vm.dart';
import 'package:flutter_js/lifetime.dart';
import 'package:flutter_js/quickjs/vm.dart';
import 'package:flutter_js/quickjs/qjs_ffi.dart';
import 'package:test/test.dart';

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
      StaticLifetime<JSValuePointer>? cache;
      vm.registerModule('greeting', (_vm) {
        QuickJSVm vm = _vm as QuickJSVm;
        // `newFunction` registered its return value to the Vm scope.
        // Wrap the `require`d result in a `StaticLifetime` to prevent disposed by subsequence function call.
        return cache = cache ?? StaticLifetime(vm.newFunction(null, (args, {thisObj}) {
          return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
        }).value);
      });
      var actual = vm.evalUnsafe('''
      var greeting = require("greeting");
      var greeting = require("greeting");
      var greeting = require("greeting");
      greeting("Flutter");
      ''').consume((lifetime) => vm.jsToDart(lifetime.value));
      expect(actual, 'Hello Flutter!');
      print(actual);
    });
    test('QuickJS module_loader async', () async {
      vm.registerModule('async_greeting', (_vm) {
        QuickJSVm vm = _vm as QuickJSVm;
        return vm.newPromise(Future.delayed(Duration(seconds: 2), () => vm.newFunction(null, (args, {thisObj}) {
          return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
        }))).promise;
      });
      var actual = vm.evalUnsafe('''
      require("async_greeting").then(greeting => greeting("Flutter"));
      ''').consume((lifetime) => vm.jsToDart(lifetime.value));
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
      StaticLifetime<JSValuePointer>? cache;
      vm.registerModule('greeting', (_vm) {
        JavaScriptCoreVm vm = _vm as JavaScriptCoreVm;
        return cache = cache ?? StaticLifetime(vm.newFunction(null, (args, {thisObj}) {
          return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
        }));
      });
      final actual = vm.jsToDart(vm.evalCode('''
      var greeting = require("greeting");
      var greeting = require("greeting");
      var greeting = require("greeting");
      greeting("Flutter");
      '''));
      expect(actual, 'Hello Flutter!');
    });
    test('JavaScriptCore module_loader async', () async {
      vm.registerModule('async_greeting', (_vm) {
        JavaScriptCoreVm vm = _vm as JavaScriptCoreVm;
        return vm.newPromise(Future.delayed(Duration(seconds: 2), () => vm.newFunction(null, (args, {thisObj}) {
          return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
        }))).promise;
      });
      var actual = vm.jsToDart(vm.evalCode('''
      require("async_greeting").then(greeting => greeting("Flutter"));
      '''));
      final actualStr = await Future.value(actual);
      expect(actualStr, 'Hello Flutter!');
    });
  });
}
