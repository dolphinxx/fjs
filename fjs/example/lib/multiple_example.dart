import 'package:fjs/vm.dart';
import 'package:flutter/material.dart';

class MultipleVmExample extends StatefulWidget {
  const MultipleVmExample({Key? key}) : super(key: key);

  @override
  _MultipleVmExampleState createState() => _MultipleVmExampleState();
}

class _MultipleVmExampleState extends State<MultipleVmExample> {
  dynamic result1;
  dynamic result2;
  dynamic result3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Multiple Vm'),),
      body: SingleChildScrollView(
        child: Row(
          children: [
            Expanded(
              child: Text('$result1'),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 6),
            ),
            Expanded(
              child: Text('$result2'),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 6),
            ),
            Expanded(
              child: Text('$result3'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: eval,
        child: Text('Eval'),
      ),
    );
  }

  void eval() async {
    Vm vm1 = Vm.create();
    Vm vm2 = Vm.create();
    Vm vm3 = Vm.create();
    String code = r'new Promise(function(resolve, reject) {resolve(`Hello World!\n${new Date()}`)})';
    vm1.startEventLoop();
    vm2.startEventLoop();
    vm3.startEventLoop();
    result1 = await vm1.jsToDart(vm1.evalCode(code));
    result2 = await vm2.jsToDart(vm2.evalCode(code));
    result3 = await vm3.jsToDart(vm3.evalCode(code));
    vm1.dispose();
    vm2.dispose();
    vm3.dispose();
    if(mounted) {
      setState(() {
      });
    }
  }
}
