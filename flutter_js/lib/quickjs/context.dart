import 'dart:ffi';

import 'package:flutter_js/lifetime.dart';

import '../context.dart';
import 'qjs_ffi.dart';
import 'vm.dart';

class QuickJSContext extends JavaScriptContext {
  static Map<int, QuickJSContext> _contexts = {};

  static QuickJSContext getFromJS(JSContextPointer context) {
    // JSValuePointer result = _jsEval(context, 'FlutterJS.instanceId');
    // String instanceId = jsValueToString(context, result);
    // jsFreeValue(context, result, 1);
    return _contexts[context.address]!;
  }

  late final QuickJSVm vm;

  QuickJSContext() {
    vm = QuickJSVm();
    _contexts[vm.ctx.address] = this;
    postCreate();
  }

  @override
  Pointer<NativeType> dartToJs(val) {
    return vm.dartToJS(val).value;
  }

  @override
  Lifetime<JSValuePointer> jsCallFunction(JSValuePointer fn, {List<JSValuePointer>? args, JSValuePointer? thisObject}) {
    return Scope.withScope((scope) {
      List<JSValuePointer> _args = [];
      if(args?.isNotEmpty == true) {
        args!.forEach((_) {
          _args.add(scope.manage(vm.dartToJS(_)).value);
        });
      }
      return vm.unwrapResult<Lifetime<JSValuePointer>>(vm.callFunction(fn, thisObject, _args));
    });
  }

  @override
  Lifetime<JSValuePointer> jsEval(String js, {String? name}) {
    return vm.evalUnsafe(js, filename: name);
  }

  @override
  jsToDart(JSValuePointer jsValueRef) {
    return vm.jsToDart(jsValueRef);
  }

  @override
  void setupChannelFunction() {
    // TODO: implement setupChannelFunction
  }
  
}