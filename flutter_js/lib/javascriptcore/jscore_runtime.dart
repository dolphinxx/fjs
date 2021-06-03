import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import './context.dart';
import '../javascript_runtime.dart';
import './binding/js_object_ref.dart';
import './binding/js_string_ref.dart';
import './context.dart';
import './jscore_bindings.dart';

// part 'wrapper.dart';

class JavascriptCoreRuntime extends JavascriptRuntime {
  late JavaScriptCoreContext _context;

  JavaScriptCoreContext get context => _context;

  int executePendingJob() {
    // The ContextGroup handles event loop automatically.
    return 0;
  }

  String? onMessageFunctionName;
  String? sendMessageFunctionName;

  JavascriptCoreRuntime() {
    _context = JavaScriptCoreContext();
    init();
  }

  @override
  T evaluate<T>(String js, {String? name}) {
    final jsValueRef = _context.eval(js, name: name).value;
    return _context.jsToDart(jsValueRef);
  }

  @override
  void dispose() {
    _context.dispose();
    super.dispose();
  }

  @override
  String getEngineInstanceId() => _context.instanceId;

  @override
  void setupBridge(String channelName, dynamic Function(dynamic args) fn) {
    final channelFunctionCallbacks =
        JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()]!;

    channelFunctionCallbacks[channelName] = fn;
  }
}
