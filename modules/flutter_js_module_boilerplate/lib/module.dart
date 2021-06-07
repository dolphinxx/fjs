import 'package:flutter_js/module.dart';
import 'package:flutter_js/types.dart';
import 'package:flutter_js/vm.dart';

import 'src/js.dart';

class FlutterJSGreetingModule extends FlutterJSModule {
  final String name = 'greeting';

  @override
  JSValuePointer resolve(Vm vm) {
    return vm.evalCode(source, filename: '<greeting_module.js>');
  }
}