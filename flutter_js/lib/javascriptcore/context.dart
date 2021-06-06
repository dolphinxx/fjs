import '../vm.dart';
import '../context.dart';
import 'binding/jsc_types.dart';
export 'binding/jsc_types.dart' show JSValueRef;
import 'vm.dart';


class JavaScriptCoreContext extends JavaScriptContext {
  late final JavaScriptCoreVm vm;

  JavaScriptCoreContext() {
    vm = JavaScriptCoreVm();
    postCreate();
  }

  void dispose() {
    super.dispose();
  }

  JSValuePointer eval(String js, {String? name}) {
    return vm.evalCode(js, filename: name);
  }

  JSValueRef callFunction(JSValueRef fn,
      {List<JSValueRef>? args, JSValueRef? thisObject}) {
    return vm.callFunction(fn, thisObject, args??[]);
  }

  dynamic jsToDart(JSValueRef jsValueRef) {
    return vm.jsToDart(jsValueRef);
  }

  JSValueRef dartToJS(dynamic val) {
    return vm.dartToJS(val);
  }

  void registerModule(String moduleName, ModuleResolver resolver) {
    vm.registerModule(moduleName, resolver);
  }
}
