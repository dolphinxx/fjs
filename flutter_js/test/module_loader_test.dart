import 'dart:async';

import 'package:flutter_js/javascriptcore/vm.dart';
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
      JSValuePointer? cache;
      vm.registerModule('greeting', (_vm) {
        QuickJSVm vm = _vm as QuickJSVm;
        if(cache == null) {
          cache = vm.newFunction(null, (args, {thisObj}) {
            return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
          });
        }
        return vm.copyJSValue(cache!);
      });
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
      vm.registerModule('async_greeting', (_vm) {
        QuickJSVm vm = _vm as QuickJSVm;
        return vm.newPromise(Future.delayed(Duration(seconds: 2), () => vm.newFunction(null, (args, {thisObj}) {
          print('async greeting called.');
          return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
        }))).promise.value;
      });
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
      JSValuePointer? cache;
      vm.registerModule('greeting', (_vm) {
        JavaScriptCoreVm vm = _vm as JavaScriptCoreVm;
        return cache = cache ?? vm.newFunction(null, (args, {thisObj}) {
          return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
        });
      });
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
      vm.registerModule('async_greeting', (_vm) {
        JavaScriptCoreVm vm = _vm as JavaScriptCoreVm;
        return vm.newPromise(Future.delayed(Duration(seconds: 2), () => vm.newFunction(null, (args, {thisObj}) {
          return vm.dartToJS('Hello ${vm.jsToDart(args[0])}!');
        }))).promise.value;
      });
      var actual = vm.jsToDart(vm.evalCode('''
      require("async_greeting").then(greeting => greeting("Flutter"));
      '''));
      final actualStr = await Future.value(actual);
      expect(actualStr, 'Hello Flutter!');
      print(actualStr);
    });
  });
}
