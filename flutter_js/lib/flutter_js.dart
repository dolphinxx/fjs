import 'dart:io';

import 'context.dart';
import 'javascriptcore/context.dart';
import 'quickjs/context.dart';

// import condicional to not import ffi libraries when using web as target
// import "something.dart" if (dart.library.io) "other.dart";
// REF:
// - https://medium.com/flutter-community/conditional-imports-across-flutter-and-web-4b88885a886e
// - https://github.com/creativecreatorormaybenot/wakelock/blob/master/wakelock/lib/wakelock.dart
JavaScriptContext getJavaScriptContext() {
  if (Platform.isIOS || Platform.isMacOS) {
    return JavaScriptCoreContext();
  }
  return QuickJSContext();
}
