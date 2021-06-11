import 'dart:convert';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'package:collection/collection.dart';

import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_js/error.dart';
import 'package:flutter_js/quickjs/qjs_ffi.dart';
import 'package:flutter_js/quickjs/vm.dart';
import 'package:flutter_js/vm.dart';
import '../lib/driver_main.dart' as app;

void main() {
  enableFlutterDriverExtension(handler: (_) async {
    if(_ == null) {
      await runDefaultTest();
      return '';
    }
    return await runTests(jsonDecode(_));
  });
  app.main();
}

Future<void> runDefaultTest() async {
  testQuickJSBoolVal();
}

/// test QuickJS Bool value(I made an idiot mistake.)
void testQuickJSBoolVal() {
  Vm vm = Vm.create();
  try {
    QuickJSVm v = vm as QuickJSVm;
    print('true: ${v.$true.address}, false: ${v.$false.address}');
    print('bool false: ${JS_ToBool(v.ctx, vm.$false)}');
    print('bool true: ${JS_ToBool(v.ctx, vm.$true)}');
    print('handyTypeof ${JS_HandyTypeof(v.ctx, v.$false).toDartString()}');
    final ptr = JS_NewBool(v.ctx, 0);
    final val = JS_ToBool(v.ctx, ptr);
    JS_FreeValuePointer(v.ctx, ptr);
    print('false -> $val, ${ptr.address}');

    v.setProperty(v.global, 'falseVal', v.$false);
    v.setProperty(v.global, 'trueVal', v.$true);
    var evalResult = v.jsToDart(v.evalCode(r'''`false is [${falseVal + ''}], true is [${trueVal + ''}]`'''));
    print('evalResult: $evalResult');
  } catch(e, s) {
    print('$e\n$s');
  } finally {
    vm.dispose();
  }
}

Future<String> runTests(options) async {
  try {
    if(options is List) {
      for(final _ in options) {
        await runTest(_);
      }
    } else {
      await runTest(options);
    }
    return jsonEncode({'success': true});
  } catch(e, s) {
    return jsonEncode({'success': false, 'error': '$e\n$s'});
  }
}

Future<void> runTest(options) async {
  if(options['group'] == 'dart2js') {
    await testDartToJS(options);
    return;
  }
  if(options['group'] == 'js2dart') {
    await testJSToDart(options);
    return;
  }
}

dynamic parseDartVal(Map options, Vm vm) {
  if(options.containsKey('dartType')) {
    switch(options['dartType']) {
      case 'DART_UNDEFINED':
        return DART_UNDEFINED;
      case 'Uint8List':
        return Uint8List.fromList((options['dart'] as List).cast<int>());
      case 'DateTime':
        return DateTime.fromMillisecondsSinceEpoch(options['dart']);
      case 'function':
        return (args, {thisObj}) {
          return vm.newString('Hello ${vm.jsToDart(args[0])}!');
        };
      case 'Future':
        return Future.delayed(Duration(seconds: 1), () => 'Hello World!');
    }
  }
  return options['dart'];
}

void applyVmOptions(Vm vm, Map options) {
  if(options.containsKey('vmOptions')) {
    (options['vmOptions'] as List).forEach((opt) {
      switch(opt[0]) {
        case 'constructDate':
          vm.constructDate = opt[1];
          break;
        case 'reserveUndefined':
          vm.reserveUndefined = opt[1];
          break;
        case 'jsonSerializeObject':
          vm.jsonSerializeObject = opt[1];
          break;
      }
    });
  }
  if(options['eventLoop'] == true) {
    vm.startEventLoop();
  }
}

Future<void> testDartToJS(Map options) async {
  Vm vm = Vm.create();
  String code = options['code'];
  dynamic dartVal = parseDartVal(options, vm);
  applyVmOptions(vm, options);
  try {
    final _ = vm.dartToJS(dartVal);
    vm.setProperty(vm.global, 'test', _);
    vm.evalCode(code, filename: '<dart2js_test>');
  } finally {
    vm.dispose();
  }
}

Future<void> testJSToDart(Map options) async {
  Vm vm = Vm.create();
  String code = options['code'];
  dynamic dartVal = parseDartVal(options, vm);
  applyVmOptions(vm, options);
  try {
    final _ = vm.jsToDart(vm.evalCode(code, filename: '<js2dart_test>'));
    var actual = _;
    if(_ is Function) {
      actual = vm.jsToDart(_((options['jsArgs'] as List).map((_) => vm.dartToJS(_)).toList(), thisObj: vm.dartToJS(options['jsThisObj'])));
    } else if(_ is Future) {
      actual = await _;
    }
    print('actual: $actual, code: $code');
    if(!DeepCollectionEquality().equals(actual, dartVal)) {
      throw 'expected: $dartVal, actual: $actual';
    }
  } catch(e) {
    if(e is JSError && options.containsKey('error')) {
      if(e.message != options['error']) {
        throw 'expected error: ${options["error"]}, actual: ${e.message}';
      }
    } else {
      rethrow;
    }
  } finally {
    vm.dispose();
  }
}