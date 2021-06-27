import 'dart:io';
import 'dart:math';

import 'package:fjs/error.dart';
import 'package:fjs/vm.dart';

Future<void> _setTimeout(int i, Vm vmProvider()) async {
  Vm vm = vmProvider();
  vm.evalCode('setTimeout(function() {console.log(">> setTimeout $i")}, ${Random().nextInt(1000)})');
  await Future.delayed(Duration(milliseconds: Random().nextInt(1000) + 500));
  vm.dispose();
}

Future<void> _throws(int i, Vm vmProvider()) async {
  Vm vm = vmProvider();
  try {
    vm.jsToDart(vm.evalCode('throw "An error."'));
  } catch(e) {
    print('>> throws $i');
  }
  vm.dispose();
}

Future<void> _crypto(int i, Vm vmProvider()) async {
  Vm vm = vmProvider();
  vm.registerModuleResolver('crypto-js', (vm, path, version) {
    return vm.evalCode(File('test/crypto-js-3.3.0.js').readAsStringSync());
  });
  vm.jsToDart(vm.evalCode('''
  require("crypto-js");
  var i = 'Hello World! Hello Flutter! 世界你好！弗勒特你好！${i}';
  var ciphertext = CryptoJS.AES.encrypt(i, 'secret key 123').toString();
  var bytes  = CryptoJS.AES.decrypt(ciphertext, 'secret key 123');
  var decryptedData = bytes.toString(CryptoJS.enc.Utf8);
  if(decryptedData !== i) throw 'crypto broken!';
  console.log(`>> crypto $i`);
  '''));
  vm.dispose();
}

Future<void> _json(int i, Vm vmProvider()) async {
  Vm vm = vmProvider();
  vm.jsToDart(vm.evalCode(File('test/json-generator-dot-com-128-rows.json').readAsStringSync()));
  print('>> parse json $i');
  vm.dispose();
}

testConcurrent(Vm vmProvider()) async {
  var tests = [_setTimeout, _throws, _crypto, _json];
  var len = tests.length;
  for(int i = 1;i < 501;i++) {
    tests[i%len](i, vmProvider);
  }
  await Future.delayed(Duration(seconds: 5));
}
