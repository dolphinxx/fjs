/**
 * These tests demonstate some common patterns for using quickjs-emscripten.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';

import '../../lib/quickjs/vm.dart';
import '../../lib/error.dart';

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
        expect(vm.getNumber(numHandle.value), jsNumber);
      });

      test('can round-trip a string', () {
        final jsString = 'an example 🤔 string with unicode 🎉';
        final stringHandle = vm.newString(jsString);
        expect(vm.getString(stringHandle.value), jsString);
        stringHandle.dispose();
      });

      test('can round-trip undefined', () {
        expect(vm.dump(vm.$undefined.value), isNull);
      });

      test('can round-trip true', () {
        expect(vm.dump(vm.$true.value), isTrue);
      });

      test('can round-trip false', () {
        expect(vm.dump(vm.$false.value), isFalse);
      });

      test('can round-trip null', () {
        expect(vm.dump(vm.$null.value), isNull);
      });
    });

    group('functions', () {
      test('empty name is valid', () {
        final fnHandle = vm.newFunction(null, (args, {thisObj}) => vm.newNumber(1024));
        final result = vm.callFunction(fnHandle.value, vm.$undefined.value, []);
        if (result.error != null) {
          throw ('calling fnHandle must succeed');
        }
        expect(vm.getNumber(result.value!.value), 1024);
        fnHandle.dispose();
      });
      test('can wrap a Javascript function and call it', () {
        final some = 9;
        final fnHandle = vm.newFunction('addSome', (args, {thisObj}) {
          return vm.newNumber(some + vm.getNumber(args[0].value)!);
        });
        final result = vm.callFunction(
            fnHandle.value, vm.$undefined.value, [vm.newNumber(1).value]);
        if (result.error != null) {
          throw ('calling fnHandle must succeed');
        }
        expect(vm.getNumber(result.value!.value), 10);
        fnHandle.dispose();
      });

      test('passes through native exceptions', () {
        final fnHandle = vm.newFunction('jsOops', (args, {thisObj}) {
          throw ('oops');
        });

        final result = vm.callFunction(fnHandle.value, vm.$undefined.value, []);
        if (result.error == null) {
          throw ('function call must return error');
        }
        expect(vm.dump(result.error!.value), {
          'name': 'Error',
          'message': 'oops',
        });
        result.error!.dispose();
        fnHandle.dispose();
      });

      test('can return undefined twice', () {
        final fnHandle = vm.newFunction('returnUndef', (args, {thisObj}) {
          return vm.$undefined;
        });

        vm
            .unwrapResult(
                vm.callFunction(fnHandle.value, vm.$undefined.value, []))
            .dispose();
        final result = vm.unwrapResult(
            vm.callFunction(fnHandle.value, vm.$undefined.value, []));

        expect(vm.typeof(result.value), 'undefined');
        result.dispose();
        fnHandle.dispose();
      });

      test('can see its arguments being cloned', () {
        QuickJSHandle? value;

        final fnHandle = vm.newFunction('doSomething', (args, {thisObj}) {
          value = vm.copyJSValue(args.first.value);
        });

        final argHandle = vm.newString('something');
        final callHandle = vm.callFunction(
            fnHandle.value, vm.$undefined.value, [argHandle.value]);

        argHandle.dispose();
        vm.unwrapResult(callHandle).dispose();

        if (value == null) throw ('Value unset');

        expect(vm.getString(value!.value), 'something');
        value!.dispose();

        fnHandle.dispose();
      });
    });

    group('properties', () {
      test('defining a property does not leak', () {
        final nameHandle = vm.newString('Name');
        vm.defineProp(
            vm.global.value,
            nameHandle.value,
            VmPropertyDescriptor(
              enumerable: false,
              configurable: false,
              get: (args, {thisObj}) => vm.newString('World'),
            ));
        nameHandle.dispose();
        final result = vm.unwrapResult(vm.evalCode('"Hello " + Name'));
        expect(vm.dump(result.value), 'Hello World');
        result.dispose();
      });
    });

    group('objects', () {
      test('can set and get properties by native string', () {
        final object = vm.newObject();
        final value = vm.newNumber(42);
        final nameHandle = vm.newString('propName');
        vm.setProp(object.value, nameHandle.value, value.value);
        final value2 = vm.getProp(object.value, nameHandle.value);
        expect(vm.getNumber(value2.value), 42);

        nameHandle.dispose();
        object.dispose();
        value.dispose();
        value2.dispose();
      });

      test('can set and get properties by handle string', () {
        final object = vm.newObject();
        final key = vm.newString('prop as a QuickJS string');
        final value = vm.newNumber(42);
        vm.setProp(object.value, key.value, value.value);

        final value2 = vm.getProp(object.value, key.value);
        expect(vm.getNumber(value2.value), 42);

        object.dispose();
        key.dispose();
        value.dispose();
        value2.dispose();
      });

      test('can create objects with a prototype', () {
        final defaultGreeting = vm.newString('SUP DAWG');
        final greeterPrototype = vm.newObject();
        vm.setProperty(
            greeterPrototype.value, 'greeting', defaultGreeting.value);
        defaultGreeting.dispose();
        final greeter = vm.newObject(greeterPrototype.value);

// Gets something from the prototype
        final getGreeting = vm.getProperty(greeter.value, 'greeting');
        expect(vm.getString(getGreeting.value), 'SUP DAWG');
        getGreeting.dispose();

// But setting a property from the prototype does not modify the prototype
        final newGreeting = vm.newString('How do you do?');
        vm.setProperty(greeter.value, 'greeting', newGreeting.value);
        newGreeting.dispose();

        final originalGreeting =
            vm.getProperty(greeterPrototype.value, 'greeting');
        expect(vm.getString(originalGreeting.value), 'SUP DAWG');
        originalGreeting.dispose();

        greeterPrototype.dispose();
        greeter.dispose();
      });
    });

    group('arrays', () {
      test('can set and get entries by native number', () {
        final array = vm.newArray();
        final val1 = vm.newNumber(101);
        vm.setProperty(array.value, 0, val1.value);

        final val2 = vm.getProperty(array.value, 0);
        expect(vm.getNumber(val2.value), 101);

        array.dispose();
        val1.dispose();
        val2.dispose();
      });

      test('adding items sets array.length', () {
        final vals = [vm.newNumber(0), vm.newNumber(1), vm.newString('cow')];
        final array = vm.newArray();
        for (int i = 0; i < vals.length; i++) {
          vm.setProperty(array.value, i, vals[i].value);
        }

        final length = vm.getProperty(array.value, 'length');
        expect(vm.getNumber(length.value), 3);

        array.dispose();
        vals.forEach((val) => val.dispose());
      });
    });

    group('.unwrapResult', () {
      test('successful result: returns the value', () {
        final handle = vm.newString('OK!');
        final VmCallResult<QuickJSHandle> result = VmCallResult.value(handle);

        expect(vm.unwrapResult(result), handle);
        handle.dispose();
      });

      test('error result: throws the error as a Javascript value', () {
        final handle = vm.newString('ERROR!');
        final VmCallResult<QuickJSHandle> result = VmCallResult.error(handle);

        try {
          vm.unwrapResult(result);
          throw ('vm.unwrapResult(error) must throw');
        } catch (error) {
          expect(error, isA<JSError>());
          expect((error as JSError).message, 'ERROR!');
        }
      });
    });

    group('.evalCode', () {
      test('on success: returns { value: success }', () {
        final value = vm.unwrapResult(
            vm.evalCode('''["this", "should", "work"].join(' ')'''));
        expect(vm.getString(value.value), 'this should work');
        value.dispose();
      });

      test('on failure: returns { error: exception }', () {
        final result = vm.evalCode('''["this", "should", "fail].join(' ')''');
        if (result.error == null) {
          throw ('result should be an error');
        }
        expect(vm.dump(result.error!.value), {
          'name': 'SyntaxError',
          'message': 'unexpected end of string',
          'stack': '    at eval.js:1\n',
        });
        result.error!.dispose();
      });

      test('runs in the global context', () {
        vm
            .unwrapResult(vm.evalCode("var declaredWithEval = 'Nice!'"))
            .dispose();
        final declaredWithEval =
            vm.getProperty(vm.global.value, 'declaredWithEval');
        expect(vm.getString(declaredWithEval.value), 'Nice!');
        declaredWithEval.dispose();
      });

      test('can access assigned globals', () {
        int i = 0;
        final fnHandle = vm.newFunction('nextId', (args, {thisObj}) {
          return vm.newNumber(++i);
        });
        vm.setProperty(vm.global.value, 'nextId', fnHandle.value);
        fnHandle.dispose();

        final nextId =
            vm.unwrapResult(vm.evalCode('nextId(); nextId(); nextId()'));
        expect(i, 3);
        expect(vm.getNumber(nextId.value), 3);
      });
    });

    group('.executePendingJobs', () {
      test('runs pending jobs', () {
        int i = 0;
        final fnHandle = vm.newFunction('nextId', (args, {thisObj}) {
          return vm.newNumber(++i);
        });
        vm.setProperty(vm.global.value, 'nextId', fnHandle.value);
        fnHandle.dispose();

        final result = vm.unwrapResult(vm.evalCode(
            '(new Promise(resolve => resolve())).then(nextId).then(nextId).then(nextId);1'));
        expect(i, 0);
        vm.executePendingJobs();
        expect(i, 3);
        expect(vm.getNumber(result.value), 1);
      });
    });

    group('.hasPendingJob', () {
      test('returns true when job pending', () {
        int i = 0;
        final fnHandle = vm.newFunction('nextId', (args, {thisObj}) {
          return vm.newNumber(++i);
        });
        vm.setProperty(vm.global.value, 'nextId', fnHandle.value);
        fnHandle.dispose();

        vm
            .unwrapResult(vm.evalCode(
                '(new Promise(resolve => resolve(5)).then(nextId));1'))
            .dispose();
        expect(vm.hasPendingJob(), true,
            reason: 'has a pending job after creating a promise');

        final executed = vm.unwrapResult(vm.executePendingJobs());
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
          final handle = vm.unwrapResult(vm.evalCode('(${json})'));
          expect(vm.dump(handle.value), val);
          handle.dispose();
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
          final handle = vm.unwrapResult(vm.evalCode('(${json})'));
          expect(vm.typeof(handle.value), nativeType);
          handle.dispose();
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

        vm.unwrapResult(vm.evalCode('1 + 1')).dispose();

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

        final result = vm.evalCode('i = 0; while (1) { i++ }');

// Make sure we actually got to interrupt the loop.
        final iHandle = vm.getProperty(vm.global.value, 'i');
        final i = vm.getNumber(iHandle.value)!;
        iHandle.dispose();

        expect(i > 10, isTrue, reason: 'incremented i');
        expect(i > calls, isTrue,
            reason: 'incremented i more than called the interrupt handler');
// console.log('Javascript loop iterrations:', i, 'interrupt handler calls:', calls);

        if (result.error != null) {
          final errorJson = vm.dump(result.error!.value);
          result.error!.dispose();
          expect(errorJson['name'], 'InternalError');
          expect(errorJson['message'], 'interrupted');
        } else {
          result.value!.dispose();
          throw ('Should have returned an interrupt error');
        }
      });
    });

    group('.computeMemoryUsage', () {
      test('returns an object with JSON memory usage info', () {
        final result = vm.computeMemoryUsage();
        final resultObj = vm.dump(result.value);
        result.dispose();

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
        final result = vm.evalCode('new Uint8Array(101); "ok"');

        if (result.error == null) {
          result.value!.dispose();
          throw ('should be an error');
        }

        vm.setMemoryLimit(-1); // so we can dump
        final error = vm.dump(result.error!.value);
        result.error!.dispose();

        expect(error, null);
      });

      test('removes limit when set to -1', () {
        vm.setMemoryLimit(100);
        vm.setMemoryLimit(-1);

        final result =
            vm.unwrapResult(vm.evalCode('new Uint8Array(101); "ok"'));
        final value = vm.dump(result.value);
        result.dispose();
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
        QuickJSDeferredPromise? deferred;

        Future timeout(int ms) {
          return Future.delayed(Duration(milliseconds: ms));
        }

        final asyncFuncHandle = vm.newFunction('getThingy', (args, {thisObj}) {
          deferred = vm.newPromise();
          timeout(5).then((_) => vm
              .newNumber(expectedValue)
              .consume((val) => deferred!.resolve(val.value)));
          return deferred!.promise;
        });

        asyncFuncHandle.consume(
            (func) => vm.setProperty(vm.global.value, 'getThingy', func.value));

        vm.unwrapResult(vm.evalCode('''
  var globalThingy = 'not set by promise';
  getThingy().then(thingy => { globalThingy = thingy });
  ''')).dispose();

// Wait for the promise to settle
        await deferred!.settled;

// Execute promise callbacks inside the VM
        vm.executePendingJobs();

// Check that the promise executed.
        final vmValue = vm
            .unwrapResult(vm.evalCode('globalThingy'))
            .consume((x) => vm.dump(x.value));
        expect(vmValue, expectedValue);
      });
    });

    group('memory pressure', () {
      test('can pass a large string to a C function', () async {
        final jsonString = File(
                '${Directory.current.path}/test/json-generator-dot-com-1024-rows.json')
            .readAsStringSync();
        final stringHandle = vm.newString(jsonString);
        stringHandle.dispose();
      });
    });
  });
}
