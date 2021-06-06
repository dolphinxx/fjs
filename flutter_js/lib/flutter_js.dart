import 'dart:io';

import 'javascriptcore/vm.dart';
import 'quickjs/vm.dart';
import 'vm.dart';

// import condicional to not import ffi libraries when using web as target
// import "something.dart" if (dart.library.io) "other.dart";
// REF:
// - https://medium.com/flutter-community/conditional-imports-across-flutter-and-web-4b88885a886e
// - https://github.com/creativecreatorormaybenot/wakelock/blob/master/wakelock/lib/wakelock.dart
Vm getJavaScriptVm() {
  if (Platform.isIOS || Platform.isMacOS) {
    return JavaScriptCoreVm();
  }
  return QuickJSVm();
}
