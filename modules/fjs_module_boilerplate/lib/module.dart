import 'package:fjs/module.dart';
import 'package:fjs/vm.dart';

import 'src/js.dart';

class FlutterJSGreetingModule extends FlutterJSModule {
  final String name = 'greeting';

  @override
  JSValuePointer resolve(Vm vm, String path) {
    return vm.evalCode(source, filename: '<greeting_module.js>');
  }
}