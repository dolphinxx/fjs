import '../context.dart';
import '../vm.dart';
import 'qjs_ffi.dart';
import 'vm.dart';

class QuickJSContext extends JavaScriptContext {
  late final QuickJSVm vm;

  QuickJSContext() {
    vm = QuickJSVm();
    postCreate();
  }

  void dispose() {
    super.dispose();
  }

  @override
  JSValuePointer eval(String js, {String? name}) {
    return vm.evalCode(js, filename: name);
  }

  @override
  JSValuePointer callFunction(JSValuePointer fn, {List<JSValuePointer>? args, JSValuePointer? thisObject}) {
    return vm.callFunction(fn, thisObject, args);
  }

  @override
  JSValuePointer dartToJS(val) {
    return vm.dartToJS(val);
  }

  @override
  jsToDart(JSValuePointer jsValueRef) {
    return vm.jsToDart(jsValueRef);
  }

  int executePendingJob() {
    return vm.executePendingJobs();
  }

  void registerModule(String moduleName, ModuleResolver resolver) {
    vm.registerModule(moduleName, resolver);
  }
}