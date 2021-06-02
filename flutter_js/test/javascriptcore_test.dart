import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/javascriptcore/binding/js_context_ref.dart';
import '../lib/javascriptcore/binding/js_object_ref.dart';
import '../lib/javascriptcore/binding/js_value_ref.dart';
import '../lib/javascriptcore/context.dart';
import '../lib/javascriptcore/binding/jsc_types.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JavaScriptCoreContext context;
  setUp(() {
    context = JavaScriptCoreContext();
  });

  tearDown(() {
    context.dispose();
  });

  test('get variable', () {
    final ptr = context.jsEval('const Foo = 123;Foo').value;
    expect(context.jsToDart(ptr), 123.0);
  });

  test('typeof', () {
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf(()=>null)').value), 'function');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf(null)').value), 'object');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf(undefined)').value), 'undefined');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf(1)').value), 'number');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf(1.1)').value), 'number');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf(Infinity)').value), 'number');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf(NaN)').value), 'number');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf(Math.PI)').value), 'number');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf("FlutterJS")').value), 'string');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf(true)').value), 'boolean');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf({})').value), 'object');
    expect(context.jsToDart(context.jsEval('FlutterJS.typeOf([])').value), 'object');
  });

  test('int to js', () {
    final root = context.jsEval('const Test = {};Test').value;
    final value = context.dartToJs(100);
    jSObjectSetProperty(context.context, root, context.dartToJs('value'), value, 0, nullptr);
    final result = context.jsEval(r'''Test.value === 100''').value;
    final actual = context.jsToDart(result);
    expect(actual, isTrue);
  });

  test('double to js', () {
    final root = context.jsEval('const Test = {};Test').value;
    final value = context.dartToJs(100.1);
    jSObjectSetProperty(context.context, root, context.dartToJs('value'), value, 0, nullptr);
    final result = context.jsEval(r'''Test.value === 100.1''').value;
    final actual =context.jsToDart(result);
    expect(actual, isTrue);
  });

  test('string to js', () {
    final root = context.jsEval('const Test = {};Test').value;
    final value = context.dartToJs('FlutterJS');
    jSObjectSetProperty(context.context, root, context.dartToJs('value'), value, 0, nullptr);
    final result = context.jsEval(r'''Test.value === "FlutterJS"''').value;
    final actual =context.jsToDart(result);
    expect(actual, isTrue);
  });

  test('bool to js', () {
    final root = context.jsEval('const Test = {};Test').value;
    final _true = context.dartToJs(true);
    final _false = context.dartToJs(false);
    jSObjectSetProperty(context.context, root, context.dartToJs('_true'), _true, 0, nullptr);
    jSObjectSetProperty(context.context, root, context.dartToJs('_false'), _false, 0, nullptr);
    final result = context.jsEval(r'''Test._true === true && Test._false === false''').value;
    final actual =context.jsToDart(result);
    expect(actual, isTrue);
  });

  test('List to js', () {
    final root = context.jsEval('const Test = {};Test').value;
    final value = context.dartToJs([1, 2.1, "FlutterJS", true, false]);
    jSObjectSetProperty(context.context, root, context.dartToJs('value'), value, 0, nullptr);
    final result = context.jsEval(r'''const v = Test.value;v[0]===1&&v[1]===2.1&&v[2]==="FlutterJS"&&v[3]===true&&v[4]===false''').value;
    final actual =context.jsToDart(result);
    expect(actual, isTrue);
  });

  test('Map to js', () {
    final root = context.jsEval('const Test = {};Test').value;
    final value = context.dartToJs({'int':1,'double':2.1,"string":"FlutterJS","bool":true, "array":[1,2]});
    jSObjectSetProperty(context.context, root, context.dartToJs('value'), value, 0, nullptr);
    final result = context.jsEval(r'''const v = Test.value;v["int"]===1&&v["double"]===2.1&&v["string"]==="FlutterJS"&&v["bool"]===true&&v["array"].length===2&&v["array"][0]===1&&v["array"][1]===2''').value;
    final actual =context.jsToDart(result);
    expect(actual, isTrue);
  });

  test('Uint8List to js', () {
    final root = context.jsEval('const Test = {};Test').value;
    final value = context.dartToJs(Uint8List.fromList([1, 2, 3]));
    jSObjectSetProperty(context.context, root, context.dartToJs('value'), value, 0, nullptr);
    final result = context.jsEval(r'''const v = Test.value;const vv=new Uint8Array(v,0);(v instanceof ArrayBuffer)&&vv.byteLength===3&&vv[0]===1&&vv[1]===2&&vv[2]===3''').value;
    final actual =context.jsToDart(result);
    expect(actual, isTrue);
  });

  test('future to js', () async {
    final val = context.dartToJs(Future.value('Hello World!'));
    var exception = calloc<JSValueRef>();
    jSObjectSetProperty(context.context, context.channelInstance, context.dartToJs('ff'), val, 0, exception);
    jsThrowOnError(context.context, exception);
    final result = context.jsEval('(async function() {return await FlutterJS.ff === "Hello World!"}())').value;
    final actual =context.jsToDart(result);
    expect(await Future.value(actual), true);
  });

  test('function to js', () async {
    final val = context.dartToJs((double left, double right) => left + right);
    var exception = calloc<JSValueRef>();
    jSObjectSetProperty(context.context, context.channelInstance, context.dartToJs('plus'), val, 0, exception);
    jsThrowOnError(context.context, exception);
    final result = context.jsEval('FlutterJS.plus(1,2)').value;
    final actual = context.jsToDart(result);
    expect(actual, 3.0);
  });

  test('error to js', () {
    final val = context.dartToJs(UnsupportedError('Test message.'));
    var exception = calloc<JSValueRef>();
    jSObjectSetProperty(context.context, context.channelInstance, context.dartToJs('error'), val, 0, exception);
    jsThrowOnError(context.context, exception);
    final result = context.jsEval('var v = FlutterJS.error;v.message').value;
    final actual = context.jsToDart(result);
    expect(actual, 'Unsupported operation: Test message.');
  });

  test('get object property names', () {
    final objPtr = context.jsEval('({a:1,"b":2,3:30})').value;
    final propNamesPtr = jSObjectCopyPropertyNames(context.context, objPtr);
    final propNamesLength = jSPropertyNameArrayGetCount(propNamesPtr);
    List propNames = [];
    for(int i = 0;i < propNamesLength;i++) {
      final propNamePtr = jSPropertyNameArrayGetNameAtIndex(propNamesPtr, i);
      String propName = jsGetString(propNamePtr)!;
      print(propName);
      propNames.add(propName);
    }
    expect(propNames, ['3', 'a', 'b']);
  });

  test('js primitive to dart', () async {
    expect(context.jsToDart(context.jsEval('1').value), 1.0, reason: 'int');
    expect(context.jsToDart(context.jsEval('1.1').value), 1.1, reason: 'double');
    expect(context.jsToDart(context.jsEval('true').value), true, reason: 'true');
    expect(context.jsToDart(context.jsEval('false').value), false, reason: 'false');
    expect(context.jsToDart(context.jsEval('"FlutterJS"').value), 'FlutterJS', reason: 'string');
    expect(context.jsToDart(context.jsEval('null').value), isNull, reason: 'null');
    expect(context.jsToDart(context.jsEval('undefined').value), isNull, reason: 'undefined');
  });

  test('js array to dart', () async {
    expect(context.jsToDart(context.jsEval('[1,"2",true,[3,4]]').value), [1,'2',true,[3,4]]);
  });

  test('js simple object to dart', () async {
    expect(context.jsToDart(context.jsEval('({a:1,b:"2",c:true})').value), {'a':1,'b':'2','c':true});
  });

  test('js complicate object to dart', () async {
    expect(context.jsToDart(context.jsEval('({a:1,b:{c:2, d:[3,"4"]}})').value), {'a':1,'b':{'c':2,'d':[3,'4']}});
  });

  test('js promise to dart', () async {
    // final result = context.jsEval(r'''new Promise((resolve, reject)=> resolve("Hello World!"))''');
    final result = context.jsEval(r'''(async function(){
      return new Promise((resolve, reject)=> resolve("Hello World!"));
    }())''').value;
    final actual =context.jsToDart(result);
    expect(await Future.value(actual), 'Hello World!');
  });

  test('js function to dart', () async {
    final ptr = context.jsEval('function plus(left, right){return left + right;};plus').value;
    final fn =context.jsToDart(ptr);
    final actual = (fn as Function)([1, 2]);
    expect(actual, 3);
  });

  test('call function', () {
    final fn = context.jsEval(r'''function greeting(name){return `Hello ${name}!`};greeting''').value;
    int type = jSValueGetType(context.context, fn);
    expect(type, 5);
    final result = jSObjectCallAsFunction(context.context, fn, nullptr, 1, jsCreateArgumentArray([context.dartToJs('World')]), nullptr);
    final actual =context.jsToDart(result);
    expect(actual, 'Hello World!');
  });

  test('call arrow function', () {
    final fn = context.jsEval(r'''(name) => {return `Hello ${name}!`}''').value;
    int type = jSValueGetType(context.context, fn);
    expect(type, 5);
    final result = jSObjectCallAsFunction(context.context, fn, nullptr, 1, jsCreateArgumentArray([context.dartToJs('World')]), nullptr);
    final actual =context.jsToDart(result);
    expect(actual, 'Hello World!');
  });

  test('promise result', () async {
    final promise = context.jsEval(r'''new Promise((resolve, reject) => {resolve('Hello World!')})''').value;
    final actual = await Future.value(context.jsToDart(promise));
    expect(actual, 'Hello World!');
  });

  test('call native return primitive', () async {
    final fn = jSObjectMakeFunctionWithCallback(context.context, nullptr, Pointer.fromFunction(fnWithCallbackPrimitive));
    final result = jSObjectCallAsFunction(context.context, fn, nullptr, 1, jsCreateArgumentArray([context.dartToJs('World')]), nullptr);
    final actual =context.jsToDart(result);
    expect(actual, 'Hello World!');
  });

  test('call native return future', () async {
    final fn = jSObjectMakeFunctionWithCallback(context.context, nullptr, Pointer.fromFunction(fnWithCallbackFuture));
    final result = jSObjectCallAsFunction(context.context, fn, nullptr, 1, jsCreateArgumentArray([context.dartToJs('World')]), nullptr);
    final actual =context.jsToDart(result);
    expect(await Future.value(actual), 'Hello World!');
  });

  test('call function from dart', () {
    context.jsEval('''
const a = {
  b: {
    c: [
      {
        plus(left, right){
          return (left + right) * this.d;
        }
      }
    ],
    d: 10
  }
};
    ''');
    var fn = context.jsEval('a.b.c[0].plus').value;
    var thisObj = context.jsEval('a.b').value;
    final resultPtr = context.jsCallFunction(fn, thisObject:thisObj, args: [1, 2]).value;
    double result = context.jsToDart(resultPtr);
    expect(result, 30);
  });

  test('call dart made function from dart', () {
    final thisObj = context.jsEval('const a = {greeting: "Hola"};a').value;
    // Make a JS function from dart.
    // See [Pointer.fromFunction] for the limitation:
    // Does not accept dynamic invocations -- where the type of the receiver is
    // [dynamic].
    //
    // If you need to make a JS function invoking dynamic dart function, consider using [bindNative].
    final fn = jSObjectMakeFunctionWithCallback(context.context, nullptr, Pointer.fromFunction(fnWithCallbackPrimitive));
    final actual = context.jsToDart(context.jsCallFunction(fn, thisObject: thisObj, args: ['World']).value);
    expect(actual, 'Hola World!');
  });
}

Pointer<NativeType> fnWithCallbackPrimitive(JSContextRef context, JSObjectRef function, JSObjectRef thisObject, int argumentCount, JSValueRefArray arguments, JSValueRefRef exception) {
  JavaScriptCoreContext ctx = JavaScriptCoreContext.getFromJS(context);
  String message = ctx.jsToDart(arguments[0]);
  final globalThis = jSContextGetGlobalObject(context);
  dynamic thisObj = globalThis.address == thisObject.address ? null : ctx.jsToDart(thisObject);
  String? greeting;
  if(thisObj != null) {
    greeting = (thisObj as Map)['greeting'];
  }
  return ctx.dartToJs('${greeting?? "Hello"} $message!');
}

Pointer<NativeType> fnWithCallbackFuture(JSContextRef context, JSObjectRef function, JSObjectRef thisObject, int argumentCount, JSValueRefArray arguments, JSValueRefRef exception) {
  JavaScriptCoreContext ctx = JavaScriptCoreContext.getFromJS(context);
  String message = ctx.jsToDart(arguments[0]);
  return ctx.dartToJs(Future.value('Hello $message!'));
}