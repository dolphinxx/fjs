import 'dart:convert';

import 'package:fjs_example/es6_features.dart';
import 'package:fjs_example/isolate.dart';
import 'package:flutter/material.dart';
import 'package:fjs/vm.dart';
import 'module/http.dart';
import 'multiple_example.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldState = GlobalKey();
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FlutterJsHomeScreen(),
    );
  }
}

class FlutterJsHomeScreen extends StatefulWidget {
  @override
  _FlutterJsHomeScreenState createState() => _FlutterJsHomeScreenState();
}

class _FlutterJsHomeScreenState extends State<FlutterJsHomeScreen> {
  final String _code = r"""
            if (typeof MyClass == 'undefined') {
              var MyClass = class {
                constructor(id) {
                  this._id = id;
                }

                get id() {return this._id;}

                set id(id) {this._id = id;}
              }
            }
            var obj = new MyClass(1);
            JSON.stringify({
              "object": JSON.stringify(obj),
              "Math.random": Math.random(),
              "now": new Date(),
              "eval('1+1')": eval("1+1"),
              "RegExp": `"Hello World!".match(new RegExp('world', 'i')) => ${"Hello World!".match(new RegExp('world', 'i'))}`,
              "decodeURIComponent": decodeURIComponent("https://github.com/dolphinxx/fjs/issues?q=is%3Aissue+is%3Aopen"),
              "encodeURIComponent": ["Hello World", "世界你好", "مرحبا بالعالم", "こんにちは世界"].map(_ => `${_} => ${encodeURIComponent(_)}`).join(', '),
            }, null, 2);
            """;
  String _jsResult = '';

  late TextEditingController editController;

  @override
  void initState() {
    editController = TextEditingController(text: _code);
    initIsolate();
    super.initState();
  }

  @override
  dispose() {
    editController.dispose();
    disposeIsolate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlutterJS Example'),
      ),
      body: Padding(
        padding: EdgeInsets.all(6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                ElevatedButton(
                  child: const Text('HTTP Module'),
                  onPressed: () => Navigator.of(context).push(PageRouteBuilder(pageBuilder: (ctx, _, __) => HttpModuleExample())),
                ),
                ElevatedButton(
                  child: const Text('Multiple'),
                  onPressed: () => Navigator.of(context).push(PageRouteBuilder(pageBuilder: (ctx, _, __) => MultipleVmExample())),
                ),
                ElevatedButton(
                  child: const Text('ES6'),
                  onPressed: () => Navigator.of(context).push(PageRouteBuilder(pageBuilder: (ctx, _, __) => ES6FeaturesCheck())),
                ),
              ],
            ),
            TextField(
              maxLines: 12,
              controller: editController,
              decoration: InputDecoration(filled: true, fillColor: Colors.black),
              style: TextStyle(color: Colors.white),
            ),
            const Padding(padding: EdgeInsets.only(top: 12)),
            Expanded(
              child: SingleChildScrollView(
                child: ColoredBox(
                  color: Colors.blueGrey,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'JS Evaluate Result:\n\n$_jsResult\n',
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: Object(),
            backgroundColor: Colors.amber,
            child: Text('Eval', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),),
            onPressed: () async {
              _jsResult = '${(await evalCode(editController.text))}';
              setState(() {
              });
            },
          ),
          const Padding(padding: EdgeInsets.only(top: 6),),
          FloatingActionButton(
            heroTag: Object(),
            backgroundColor: Colors.amber,
            child: Text('Isolate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),),
            onPressed: () async {
              _jsResult = '${(await evalInIsolate(editController.text))}';
              setState(() {
              });
            },
          ),
        ],
      ),
    );
  }

  Future evalCode(String code) async {
    final Vm vm = Vm.create(disableConsole: false);
    try {
      vm.startEventLoop();
      dynamic result = vm.jsToDart(vm.evalCode(code));;
      if(result is Future) {
        result = await result;
      }
      if(!(result is String || result is bool || result is num || result is DateTime)) {
        try {
          return JsonEncoder.withIndent('  ').convert(result);
        } catch (_) {
          return result.toString();
        }
      } else {
        return result.toString();
      }
    } finally {
      vm.dispose();
    }
  }

  Future evalInIsolate(String code) async {
    try {
      dynamic result = await invokeInIsolate(code);
      return result?.toString();
    } finally {

    }
  }
}
