import 'dart:io';

import 'package:fjs/vm.dart';

testMemoryPressure(Vm vm, int rows) {
  final jsonString = File('${Directory.current.path}/test/json-generator-dot-com-$rows-rows.json').readAsStringSync();
  print(vm.jsToDart(vm.evalCode(jsonString)).length);
}
