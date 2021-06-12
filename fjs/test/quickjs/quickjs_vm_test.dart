/**
 * These tests demonstate some common patterns for using quickjs-emscripten.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fjs/promise.dart';
import 'package:test/test.dart';

import 'package:fjs/quickjs/vm.dart';
import 'package:fjs/types.dart';
import 'package:fjs/error.dart';

String jsTypeof(val) {
  if (val == null) {
    return 'object';
  }
  if (val is Function) {
    return 'function';
  }
  if (val is String) {
    return 'string';
  }
  if (val is num) {
    return 'number';
  }
  if (val is bool) {
    return 'boolean';
  }
  return 'object';
}

void main() {
  group('QuickJSVm', () {
    late QuickJSVm vm;

    setUp(() {
      vm = QuickJSVm();
    });

    tearDown(() {
      vm.dispose();
    });

    group('primitives', () {
      test('can round-trip a number', () {
        final jsNumber = 42.0;
        final numHandle = vm.newNumber(jsNumber);
        expect(vm.getNumber(numHandle), jsNumber);
      });

      test('can round-trip a string', () {
        final jsString = 'an example 🤔 string with unicode 🎉';
        final stringHandle = vm.newString(jsString);
        expect(vm.getString(stringHandle), jsString);
      });

      test('can round-trip undefined', () {
        expect(vm.dump(vm.$undefined), isNull);
      });

      test('can round-trip true', () {
        expect(vm.dump(vm.$true), isTrue);
      });

      test('can round-trip false', () {
        expect(vm.dump(vm.$false), isFalse);
      });

      test('can round-trip null', () {
        expect(vm.dump(vm.$null), isNull);
      });
    });

    group('functions', () {
      test('empty name is valid', () {
        final fnHandle = vm.newFunction(null, (args, {thisObj}) => vm.newNumber(1024));
        final result = vm.callFunction(fnHandle, vm.$undefined, []);
        expect(vm.getNumber(result), 1024);
      });
      test('can wrap a Javascript function and call it', () {
        final some = 9;
        final fnHandle = vm.newFunction('addSome', (args, {thisObj}) {
          return vm.newNumber(some + vm.getNumber(args[0])!);
        });
        final result = vm.callFunction(
            fnHandle, vm.$undefined, [vm.newNumber(1)]);
        expect(vm.getNumber(result), 10);
      });

      test('passes through native exceptions', () {
        final fnHandle = vm.newFunction('jsOops', (args, {thisObj}) {
          throw ('oops');
        });

        try {
          vm.callFunction(fnHandle, vm.$undefined, []);
          throw ('function call must return error');
        } on JSError catch(e) {
          expect(e.toMap(), allOf(containsPair('name', 'Error'), containsPair('message', 'oops')));
        }
      });

      test('can return undefined twice', () {
        final fnHandle = vm.newFunction('returnUndef', (args, {thisObj}) {
          return vm.$undefined;
        });

        vm.callFunction(fnHandle, vm.$undefined, []);
        final result = vm.callFunction(fnHandle, vm.$undefined, []);

        expect(vm.typeof(result), 'undefined');
      });

      test('can see its arguments being cloned', () {
        JSValuePointer? value;

        final fnHandle = vm.newFunction('doSomething', (args, {thisObj}) {
          value = vm.dupRef(args.first);
        });

        final argHandle = vm.newString('something');
        vm.callFunction(
            fnHandle, vm.$undefined, [argHandle]);

        if (value == null) throw ('Value unset');

        expect(vm.getString(value!), 'something');
      });
    });

    group('properties', () {
      test('defining a property does not leak', () {
        final nameHandle = vm.newString('Name');
        vm.defineProp(
            vm.global,
            nameHandle,
            VmPropertyDescriptor(
              enumerable: false,
              configurable: false,
              get: (args, {thisObj}) => vm.newString('World'),
            ));
        final result = vm.evalCode('"Hello " + Name');
        expect(vm.dump(result), 'Hello World');
      });
    });

    group('objects', () {
      test('can set and get properties by native string', () {
        final object = vm.newObject({'ov': 'should be overwritten'});
        final value = vm.newNumber(42);
        final nameRef = vm.newString('propName');
        final ovRef = vm.newString('ov');
        vm.setProp(object, nameRef, value);
        vm.setProp(object, ovRef, vm.newString('Greeting!'));
        expect(vm.getNumber(vm.getProp(object, nameRef)), 42);
        expect(vm.getString(vm.getProp(object, ovRef)), 'Greeting!');
      });

      test('can set and get properties by handle string', () {
        final object = vm.newObject();
        final key = vm.newString('prop as a QuickJS string');
        final value = vm.newNumber(42);
        vm.setProp(object, key, value);

        final value2 = vm.getProp(object, key);
        expect(vm.getNumber(value2), 42);
      });

      test('can create objects with a prototype', () {
        final defaultGreeting = vm.newString('SUP DAWG');
        final greeterPrototype = vm.newObject();
        vm.setProperty(
            greeterPrototype, 'greeting', defaultGreeting);
        final greeter = vm.newObjectWithPrototype(greeterPrototype);

// Gets something from the prototype
        final getGreeting = vm.getProperty(greeter, 'greeting');
        expect(vm.getString(getGreeting), 'SUP DAWG');

// But setting a property from the prototype does not modify the prototype
        final newGreeting = vm.newString('How do you do?');
        vm.setProperty(greeter, 'greeting', newGreeting);

        final originalGreeting =
            vm.getProperty(greeterPrototype, 'greeting');
        expect(vm.getString(originalGreeting), 'SUP DAWG');
      });
    });

    group('arrays', () {
      test('can set and get entries by native number', () {
        final array = vm.newArray();
        final val1 = vm.newNumber(101);
        vm.setProperty(array, 0, val1);

        final val2 = vm.getProperty(array, 0);
        expect(vm.getNumber(val2), 101);
      });

      test('adding items sets array.length', () {
        final vals = [vm.newNumber(0), vm.newNumber(1), vm.newString('cow')];
        final array = vm.newArray();
        for (int i = 0; i < vals.length; i++) {
          vm.setProperty(array, i, vals[i]);
        }

        final length = vm.getProperty(array, 'length');
        expect(vm.getNumber(length), 3);
      });
    });

    group('.evalCode', () {
      test('on success: returns { value: success }', () {
        final value = vm.evalCode('''["this", "should", "work"].join(' ')''');
        expect(vm.getString(value), 'this should work');
      });

      test('on failure: returns { error: exception }', () {
        try {
          vm.evalCode('''["this", "should", "fail].join(' ')''');
          throw ('result should be an error');
        } on JSError catch(e) {
          expect(e.toMap(), {
            'name': 'SyntaxError',
            'message': 'unexpected end of string',
            'stack': '    at <eval.js>:1\n',
          });
        }
      });

      test('runs in the global context', () {
        vm.evalCode("var declaredWithEval = 'Nice!'");
        final declaredWithEval =
            vm.getProperty(vm.global, 'declaredWithEval');
        expect(vm.getString(declaredWithEval), 'Nice!');
      });

      test('can access assigned globals', () {
        int i = 0;
        final fnHandle = vm.newFunction('nextId', (args, {thisObj}) {
          return vm.newNumber(++i);
        });
        vm.setProperty(vm.global, 'nextId', fnHandle);

        final nextId = vm.evalCode('nextId(); nextId(); nextId()');
        expect(i, 3);
        expect(vm.getNumber(nextId), 3);
      });
    });

    group('.executePendingJobs', () {
      test('runs pending jobs', () {
        int i = 0;
        final fnHandle = vm.newFunction('nextId', (args, {thisObj}) {
          return vm.newNumber(++i);
        });
        vm.setProperty(vm.global, 'nextId', fnHandle);

        final result = vm.evalCode('(new Promise(resolve => resolve())).then(nextId).then(nextId).then(nextId);1');
        expect(i, 0);
        vm.executePendingJobs();
        expect(i, 3);
        expect(vm.getNumber(result), 1);
      });
    });

    group('.hasPendingJob', () {
      test('returns true when job pending', () {
        int i = 0;
        final fnHandle = vm.newFunction('nextId', (args, {thisObj}) {
          return vm.newNumber(++i);
        });
        vm.setProperty(vm.global, 'nextId', fnHandle);

        vm.evalCode('(new Promise(resolve => resolve(5)).then(nextId));1');
        expect(vm.hasPendingJob(), true,
            reason: 'has a pending job after creating a promise');

        final executed = vm.executePendingJobs();
        expect(executed, 1, reason: 'executed exactly 1 job');

        expect(vm.hasPendingJob(), false,
            reason: 'no longer any jobs after execution');
      });
    });

    group('.dump ', () {
      void dumpTestExample(dynamic val) {
        final json = jsonEncode(val);
        final nativeType = jsTypeof(val);
        test('supports ${nativeType} (${json})', () {
          final handle = vm.evalCode('(${json})');
          expect(vm.dump(handle), val);
        });
      }

      dumpTestExample(1);
      dumpTestExample('hi');
      dumpTestExample(true);
      dumpTestExample(false);
      // dumpTestExample(undefined);
      dumpTestExample(null);
      dumpTestExample({'cow': true});
      dumpTestExample([1, 2, 3]);
    });

    group('.typeof', () {
      void typeofTestExample(dynamic val, [Function toCode = jsonEncode]) {
        final json = toCode(val);
        final nativeType = jsTypeof(val);
        test('supports ${nativeType} (${json})', () {
          final handle = vm.evalCode('(${json})');
          expect(vm.typeof(handle), nativeType);
        });
      }

      typeofTestExample(1);
      typeofTestExample('hi');
      typeofTestExample(true);
      typeofTestExample(false);
      // typeofTestExample(undefined);
      typeofTestExample(null);
      typeofTestExample({'cow': true});
      typeofTestExample([1, 2, 3]);
      typeofTestExample(
        () {},
        // Hard code JS function's toString result.
        (dynamic val) => /*val.toString()*/ 'function() {}',
      );
    });

    group('interrupt handler', () {
      test('is called with the expected VM', () {
        int calls = 0;
        final InterruptHandler interruptHandler = (interruptVm) {
          expect(interruptVm, vm,
              reason: 'ShouldInterruptHandler callback VM is the vm');
          calls++;
          return false;
        };
        vm.setInterruptHandler(interruptHandler);

        vm.evalCode('1 + 1');

        expect(calls > 0, isTrue,
            reason: 'interruptHandler called at least once');
      });

      test('interrupts infinite loop execution', () {
        int calls = 0;
        final InterruptHandler interruptHandler = (interruptVm) {
          if (calls > 10) {
            return true;
          }
          calls++;
          return false;
        };
        vm.setInterruptHandler(interruptHandler);

        try {
          vm.evalCode('i = 0; while (1) { i++ }');

          // Make sure we actually got to interrupt the loop.
          final iHandle = vm.getProperty(vm.global, 'i');
          final i = vm.getNumber(iHandle)!;
          expect(i > 10, isTrue, reason: 'incremented i');
          expect(i > calls, isTrue, reason: 'incremented i more than called the interrupt handler');
          // console.log('Javascript loop iterrations:', i, 'interrupt handler calls:', calls);
          throw ('Should have returned an interrupt error');
        } on JSError catch(e) {
          expect(e.toMap(), allOf(containsPair('name', 'InternalError'), containsPair('message', 'interrupted')));
        }
      });
    });

    group('.computeMemoryUsage', () {
      test('returns an object with JSON memory usage info', () {
        final result = vm.computeMemoryUsage();
        final resultObj = vm.dump(result);

        final example = {
          'array_count': 1,
          'atom_count': 414,
          'atom_size': 13593,
          'binary_object_count': 0,
          'binary_object_size': 0,
          'c_func_count': 46,
          'fast_array_count': 1,
          'fast_array_elements': 0,
          'js_func_code_size': 0,
          'js_func_count': 0,
          'js_func_pc2line_count': 0,
          'js_func_pc2line_size': 0,
          'js_func_size': 0,
          'malloc_count': 665,
          'malloc_limit': 4294967295,
          'memory_used_count': 665,
          'memory_used_size': 36305,
          'obj_count': 97,
          'obj_size': 4656,
          'prop_count': 654,
          'prop_size': 5936,
          'shape_count': 50,
          'shape_size': 10328,
          'str_count': 0,
          'str_size': 0,
        };

        expect((resultObj as Map).keys.toList()..sort(),
            example.keys.toList()..sort());
      });
    });

    group('.setMemoryLimit', () {
      test('sets an enforced limit', () {
        vm.setMemoryLimit(100);
        try {
          vm.evalCode('new Uint8Array(101); "ok"');
          throw ('should be an error');
        } on JSError catch(e) {
          print('An expected error: ${e.message}');
        }
      });

      test('removes limit when set to -1', () {
        vm.setMemoryLimit(100);
        vm.setMemoryLimit(-1);
        final result = vm.evalCode('new Uint8Array(101); "ok"');
        final value = vm.dump(result);
        expect(value, 'ok');
      });
    });

    group('.dumpMemoryUsage()', () {
      test('logs memory usage', () {
        expect(vm.dumpMemoryUsage(), endsWith('per fast array)\n'),
            reason: 'should end with "per fast array)\\n"');
      });
    });

    group('.newPromise()', () {
      test('dispose does not leak', () {
        vm.newPromise().dispose();
      });

      test('passes an end-to-end test', () async {
        final expectedValue = math.Random().nextInt(100);
        JSDeferredPromise? deferred;

        Future timeout(int ms) {
          return Future.delayed(Duration(milliseconds: ms));
        }

        final asyncFuncHandle = vm.newFunction('getThingy', (args, {thisObj}) {
          deferred = vm.newPromise();
          timeout(5).then((_) => vm.consumeAndFree(vm
              .newNumber(expectedValue), (val) => deferred!.resolve(val)));
          return deferred!.promise.value;
        });

        vm.consumeAndFree(asyncFuncHandle,
            (func) => vm.setProperty(vm.global, 'getThingy', func));

        vm.evalCode('''
  var globalThingy = 'not set by promise';
  getThingy().then(thingy => { globalThingy = thingy });
  ''');

// Wait for the promise to settle
        await deferred!.settled;

// Execute promise callbacks inside the VM
        vm.executePendingJobs();

// Check that the promise executed.
        final vmValue = vm
            .consumeAndFree(vm.evalCode('globalThingy'), (x) => vm.dump(x));
        expect(vmValue, expectedValue);
      });
    });

    group('memory pressure', () {
      test('can pass a large string to a C function', () async {
        final jsonString = File(
                '${Directory.current.path}/test/json-generator-dot-com-1024-rows.json')
            .readAsStringSync();
        vm.newString(jsonString);
      });
    });
  });
}
