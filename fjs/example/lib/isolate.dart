import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:fjs/vm.dart';

late Isolate _isolate;
/// receiving message from isolate
late ReceivePort _receivePort;
/// sending message to isolate
late SendPort _sendPort;

int _completerNextId = 1;
Map<int, Completer<dynamic>> _completerMap = {};

void _entryPoint(SendPort callerSendPort) {
  ReceivePort receivePort = ReceivePort();
  callerSendPort.send(receivePort.sendPort);

  int completerIncrement = 0;
  Map<int, Completer<dynamic>> completerMap = {};

  receivePort.listen((msg) async {
    String type = msg[#type];
    int? completerId = msg[#id];
    if(type == 'eval') {
      String code = msg[#code];
      Vm vm = Vm.create();
      vm.registerModuleResolver('greeting', (Vm vm) {
        return vm.newFunction('greeting', (args, {thisObj}) {
          int completerId = completerIncrement++;
          Completer<dynamic> completer = Completer();
          completerMap[completerId] = completer;
          // get data from main isolate
          var data = vm.jsToDart(args[0]);
          callerSendPort.send({#type: 'read', #id: completerId, #data: data});
          return vm.dartToJS(completer.future);
        });
      });
      vm.startEventLoop();
      var result;
      var error;
      try {
        result = vm.jsToDart(vm.evalCode(code));
        if(result is Future) {
          result = await result;
        }
        if(!(result is String || result is bool || result is num || result is DateTime)) {
          try {
            result = JsonEncoder.withIndent('  ').convert(result);
          } catch (_) {
            result = result.toString();
          }
        } else {
          result = result.toString();
        }
      } catch(e) {
        error = e.toString();
      } finally {
        vm.dispose();
      }
      callerSendPort.send({#type: 'result', #id: completerId, #result: result, #error: error});
      return;
    }
    if(type == 'read_result') {
      completerMap.remove(completerId)!.complete(msg[#result]);
      return;
    }
    throw 'unknown type $type from main isolate';
  });
}

Future<void> initIsolate() async {
  Completer<void> _entryCompleter = Completer();
  _receivePort = ReceivePort();
  _isolate = await Isolate.spawn(_entryPoint, _receivePort.sendPort);
  _receivePort.listen((message) async {
    if (message is SendPort) {
      _sendPort = message;
      _entryCompleter.complete();
      return;
    }
    String type = message[#type];
    int completerId = message[#id];
    // a call from spawned isolate
    if(type == 'read') {
      // do something in main isolate...
      String name = message[#data];
      String result = await Future.value('Hello $name!');
      _sendPort.send({#type:'read_result', #id: completerId, #result: result});
      return;
    }
    if(type == 'result') {
      // result returned from spawned isolate
      Completer completer = _completerMap.remove(completerId)!;
      if(message[#error] != null) {
        completer.completeError(message[#error]);
      } else {
        completer.complete(message[#result]);
      }
      return;
    }
    throw 'unknown type $type from spawned isolate';
  });
  return _entryCompleter.future;
}

void disposeIsolate() {
  _isolate.kill();
}

Future<dynamic> invokeInIsolate(String code) async {
  int completerId = _completerNextId++;
  Completer<dynamic> completer = Completer();
  _completerMap[completerId] = completer;
  _sendPort.send({#type: 'eval', #id: completerId, #code: code});
  return await completer.future;
}