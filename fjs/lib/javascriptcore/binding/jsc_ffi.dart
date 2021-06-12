import 'dart:ffi';
import 'dart:io';

export 'jsc_types.dart';

DynamicLibrary? _jscLib;

DynamicLibrary? get jscLib {
  if (_jscLib != null) {
    return _jscLib;
  }
  // JSC for Windows is only used for test.
  if(Platform.isWindows && Platform.environment.containsKey('FLUTTER_TEST')) {
    _jscLib = DynamicLibrary.open("JavaScriptCore.dll");
  } else if(Platform.isIOS || Platform.isMacOS) {
    _jscLib = DynamicLibrary.open("JavaScriptCore.framework/JavaScriptCore");
  } else {
    // Android support is removed in this fork version.
    // DynamicLibrary.open("libjsc.so")
    _jscLib = DynamicLibrary.process();
  }
  return _jscLib;
}
