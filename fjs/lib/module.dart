import 'vm.dart';

abstract class FlutterJSModule {
  String get name;

  void dispose() {}

  /// Resolve [path] and return the corresponding module.
  ///
  /// For `require("crypto-js/aes"), the [path] is ["crypto-js", "aes"].
  JSValuePointer resolve(Vm vm, List<String> path);
}
