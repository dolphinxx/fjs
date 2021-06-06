import 'vm.dart';

abstract class FlutterJSModule {
  String get name;

  void dispose() {}

  JSValuePointer resolve(Vm vm);
}
