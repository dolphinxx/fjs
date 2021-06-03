import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_js/quickjs/qjs_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hello_world', () {
    Pointer<Utf8> ptr = hello_world();
    String actual = ptr.toDartString();
    expect(actual, 'Hello World!');
  });
}