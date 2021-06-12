// part of 'jscore_runtime.dart';
//
// typedef bytes_deallocator = Void Function(Pointer<NativeType>, Pointer<NativeType>);
// typedef PromiseCallback = void Function(bool success, dynamic value);
// int _jsToNativeCallbackIdIncrement = 1;
// Map<dynamic, Map<int, Function>> _jsToNativeCallbacks= {};
// int _addNativeCallback(dynamic instanceId, Function fn) {
//   int id = _jsToNativeCallbackIdIncrement++;
//   Map<int, Function> store = _jsToNativeCallbacks.putIfAbsent(instanceId, () => ({}));
//   store[id] = fn;
//   return id;
// }
// Function? _getNativeCallback(dynamic instanceId, int callbackId, [bool remove = true]) {
//   Map<int, Function>? store = _jsToNativeCallbacks[instanceId];
//   if(store == null) {
//     return null;
//   }
//   Function? fn = store[callbackId];
//   if(fn != null && remove) {
//     store.remove(callbackId);
//   }
//   return fn;
// }
// /// Used for test.
// void clearAllNativeCallbacks() {
//   _jsToNativeCallbacks.clear();
// }
// dynamic getInstanceIdFromContext(Pointer<NativeType> context) {
//   return jsToDart(context, jsEval(context, 'FlutterJS.instanceId'));
// }
//
// void _bytesDeallocator(Pointer<NativeType> bytes, Pointer<NativeType> context) {
//   calloc.free(bytes);
// }
//
// Pointer<NativeType> jsEval(Pointer<NativeType> context,String js, {String? name}) {
//   // print('eval $name:\n$js');
//   Pointer<Utf8> scriptCString = js.toNativeUtf8();
//   Pointer<Utf8>? nameCString = name?.toNativeUtf8();
//
//   final exception = calloc<Pointer>();
//   var jsValueRef = jSEvaluateScript(
//       context,
//       jSStringCreateWithUTF8CString(scriptCString),
//       nullptr,
//       name == null ? nullptr : jSStringCreateWithUTF8CString(nameCString!),
//       1,
//       exception);
//   calloc.free(scriptCString);
//   if(nameCString != null) {
//     calloc.free(nameCString);
//   }
//   String? error = jsErrorToString(context, exception);
//   calloc.free(exception);
//   if(error != null) {
//     throw error;
//   }
//   return jsValueRef;
// }
//
// /// Call a JS function from dart.
// ///
// /// Use [jsEval] to obtain a JS function reference and pass it as [fn] parameter, the same way for [thisObject] reference if needed.
// ///
// /// The values in [args] are automatically converted to JsValue.
// ///
// /// example:
// ///
// /// Define `plus` in JS:
// /// ```js
// /// const a = {
// ///   b: {
// ///     c: [
// ///       {
// ///         plus(left, right){
// ///           return (left + right) * this.d;
// ///         }
// ///       }
// ///     ],
// ///     d: 10
// ///   }
// /// };
// /// ```
// ///
// /// Call `plus` from dart:
// /// ```dart
// /// var fn = jsEval(context, 'a.b.c[0].plus');
// /// var thisObj = jsEval(context, 'a.b');
// /// double result = jsCallFunction(fn, thisObject:thisObj, args: [1, 2]);
// /// expect(result, 30);
// /// ```
// ///
// /// See `javascriptcore_test.dart` for more information.
// T jsCallFunction<T>(Pointer<NativeType> context, Pointer<NativeType> fn, {List? args, Pointer<NativeType>? thisObject}) {
//   var arguments;
//   if(args?.isNotEmpty == true) {
//     arguments = jsCreateArgumentArray(args!.map((_) => dartToJs(context, _)));
//   } else {
//     arguments = nullptr;
//   }
//   final exception = calloc<Pointer>();
//   final result = jSObjectCallAsFunction(context, fn, thisObject??nullptr, args?.length??0, arguments, exception);
//   jsThrowOnError(context, exception);
//   return jsToDart(context, result);
// }
//
// void jsThrowOnError(Pointer<NativeType> context, Pointer<Pointer<NativeType>> error) {
//   String? e = jsErrorToString(context, error);
//   calloc.free(error);
//   if(e != null) {
//     throw e;
//   }
// }
//
// String? jsErrorToString(Pointer<NativeType> context, Pointer<Pointer<NativeType>> error) {
//   if(jSValueIsObject(context, error[0]) == 1) {
//     final ptr = jSValueToStringCopy(context, error[0], nullptr);
//     final _ptr = jSStringGetCharactersPtr(ptr);
//     if(_ptr == nullptr) {
//       return null;
//     }
//     int length = jSStringGetLength(ptr);
//     final e = String.fromCharCodes(Uint16List.view(_ptr.cast<Uint16>().asTypedList(length).buffer, 0, length));
//     jSStringRelease(ptr);
//     return e;
//   }
//   return null;
// }
//
// String? jsGetString(Pointer<NativeType> stringRef) {
//   Pointer<Utf16> cString = jSStringGetCharactersPtr(stringRef);
//   if(cString == nullptr) {
//     return null;
//   }
//   int length = jSStringGetLength(stringRef);
//   return String.fromCharCodes(Uint16List.view(cString.cast<Uint16>().asTypedList(length).buffer, 0, length));
// }
//
// String? jsValueToString(Pointer<NativeType> context, Pointer value) {
//   final exception = calloc<Pointer>();
//   final cp = jSValueToStringCopy(context, value, exception);
//   jsThrowOnError(context, exception);
//   String? result = jsGetString(cp);
//   jSStringRelease(cp);
//   return result;
// }
//
// Pointer<NativeType> jsGetProperty(Pointer<NativeType> context, Pointer obj, String propertyName) {
//   final propertyNamePtr = propertyName.toNativeUtf8();
//   final exception = calloc<Pointer>();
//   Pointer<NativeType> result = jsObject.jSObjectGetProperty(context, obj, jSStringCreateWithUTF8CString(propertyNamePtr), exception);
//   calloc.free(propertyNamePtr);
//   String? error = jsErrorToString(context, exception);
//   calloc.free(exception);
//   if(error != null) {
//     throw error;
//   }
//   return result;
// }
//
// typedef PromiseOnFulFilled = Void Function(Pointer<NativeType> value);
// typedef PromiseOnError = Void Function(Pointer<NativeType> error);
//
// /// convert js value to dart value.
// ///
// /// null->null
// /// undefined->null
// /// Number->double
// /// String->String
// /// Array->List
// /// Promise->Future
// /// Function->Function
// /// Object->Map<String,dynamic>
// ///
// dynamic jsToDart(Pointer<NativeType> context, Pointer jsValueRef) {
//   int type = jSValueGetType(context, jsValueRef);
//   if(type == JSType.kJSTypeUndefined || type == JSType.kJSTypeNull) {
//     return null;
//   }
//   if(type == JSType.kJSTypeBoolean) {
//     return jSValueToBoolean(context, jsValueRef) == 1;
//   }
//   if(type == JSType.kJSTypeNumber) {
//     return jSValueToNumber(context, jsValueRef, nullptr);
//   }
//   if(type == JSType.kJSTypeString || type == JSType.kJSTypeSymbol/*TODO:*/) {
//     // final cp = jSValueToStringCopy(context, jsValueRef, nullptr);
//     // Pointer<Utf16> cString = jSStringGetCharactersPtr(cp);
//     // if(cString == nullptr) {
//     //   return null;
//     // }
//     // int length = jSStringGetLength(cp);
//     // final result = String.fromCharCodes(Uint16List.view(cString.cast<Uint16>().asTypedList(length).buffer, 0, length));
//     // jSStringRelease(cp);
//     return jsValueToString(context, jsValueRef);
//   }
//   if(type == JSType.kJSTypeObject) {
//     if(jSValueIsArray(context, jsValueRef) == 1) {
//       final lengthPtr = jsGetProperty(context, jsValueRef, 'length');
//       int length = jSValueToNumber(context, lengthPtr, nullptr).toInt();
//       List result = [];
//       for(int i = 0;i < length;i++) {
//         result.add(jsToDart(context, jsObject.jSObjectGetPropertyAtIndex(context, jsValueRef, i, nullptr)));
//       }
//       return result;
//     }
//     final _typeOf = jsEval(context, 'FlutterJS.typeOf');
//     var exception = calloc<Pointer>();
//     final typeOfPtr = jsObject.jSObjectCallAsFunction(context, _typeOf, nullptr, 1, jsCreateArgumentArray([jsValueRef]), exception);
//     jsThrowOnError(context, exception);
//     String strType = jsValueToString(context, typeOfPtr)!;
//     // Limitation: The returned Function only accept a single parameter of List type.
//     if(strType == 'function') {
//       return (List? args) {
//         final result = jsCallFunction(context, jsValueRef, args: args);
//         return result;
//       };
//     }
//     Pointer<NativeType> thenPtr = jsGetProperty(context, jsValueRef, 'then');
//     if(jSValueIsObject(context, thenPtr) == 1 && jSValueIsObject(context, jsGetProperty(context, jsValueRef, 'catch')) == 1) {
//       // Treat as a Promise instance
//       Completer completer = Completer();
//       dynamic instanceId = getInstanceIdFromContext(context);
//       int callbackId = _addNativeCallback(instanceId, (success, value) {
//         if(success) {
//           completer.complete(value);
//         } else {
//           completer.completeError(value);
//         }
//       });
//       final onFulFilled = jsEval(context, '(value)=>FlutterJS.sendMessage("internal::native_callback",{id:$callbackId,instanceId:"$instanceId",args:[true,value]})', name: 'promise onFulFilled setup');
//       final onError = jsEval(context, '(error)=>FlutterJS.sendMessage("internal::native_callback",{id:$callbackId,instanceId:"$instanceId",args:[false,error]})', name: 'promise onError setup');
//       exception = calloc<Pointer>();
//       jSObjectCallAsFunction(context, thenPtr, jsValueRef, 1, jsCreateArgumentArray([onFulFilled, onError]), exception);
//       jsThrowOnError(context, exception);
//       return completer.future;
//     }
//     final propNamesPtr = jsObject.jSObjectCopyPropertyNames(context, jsValueRef);
//     int propNameLength = jsObject.jSPropertyNameArrayGetCount(propNamesPtr);
//     final result = {};
//     for(int i = 0;i < propNameLength;i++) {
//       final propNamePtr = jsObject.jSPropertyNameArrayGetNameAtIndex(propNamesPtr, i);
//       String propName = jsGetString(propNamePtr)!;
//       result[propName] = jsToDart(context, jsObject.jSObjectGetProperty(context, jsValueRef, propNamePtr, nullptr));
//     }
//     jsObject.jSPropertyNameArrayRelease(propNamesPtr);
//     return result;
//   }
//   final exception = calloc<Pointer>();
//   String? jsonStr = jsGetString(jSValueCreateJSONString(context, jsValueRef, 0, exception));
//   jsThrowOnError(context, exception);
//   return jsonStr == null ? null : jsonDecode(jsonStr);
// }
//
// Pointer dartToJs(Pointer<NativeType> context, dynamic val) {
//   if(val == null) {
//     return jSValueMakeUndefined(context);
//   }
//   if(val is Error) {
//     // TODO: Error constructor arg types
//     final exception = calloc<Pointer>();
//     final result = jsObject.jSObjectMakeError(context, 2, dartArrayToJs(context, [val.toString(), val.stackTrace.toString()]), exception);
//     String? error = jsErrorToString(context, exception);
//     calloc.free(exception);
//     if(error != null) {
//       throw error;
//     }
//     return result;
//   }
//   if(val is Exception) {
//     return jsObject.jSObjectMakeError(context, 1, dartArrayToJs(context, [val.toString()]), nullptr);
//   }
//   if(val is Future) {
//     final resolve = calloc<Pointer>();
//     final reject = calloc<Pointer>();
//     val.then((value) {
//       final exception = calloc<Pointer>();
//       jsObject.jSObjectCallAsFunction(context, resolve[0], nullptr, 1, jsCreateArgumentArray([dartToJs(context, value)]), exception);
//       String? error = jsErrorToString(context, exception);
//       calloc.free(exception);
//       if(error != null) {
//         throw error;
//       }
//     }).catchError((err) {
//       final exception = calloc<Pointer>();
//       jsObject.jSObjectCallAsFunction(context, reject[0], nullptr, 1, jsCreateArgumentArray([dartToJs(context, err)]), exception);
//       String? error = jsErrorToString(context, exception);
//       calloc.free(exception);
//       if(error != null) {
//         throw error;
//       }
//     }).whenComplete(() {
//       calloc.free(resolve);
//       calloc.free(reject);
//     });
//     final exception = calloc<Pointer>();
//     final result = jsObject.jSObjectMakeDeferredPromise(context, resolve, reject, exception);
//     String? error = jsErrorToString(context, exception);
//     calloc.free(exception);
//     if(error != null) {
//       throw error;
//     }
//     return result;
//     // final callbackId = ..;
//     // final result = jsEval(context, '''new Promise(function(resolve,reject){FlutterJS.nativeCallbacks["$callbackId"]=function(result,error){delete FlutterJS.nativeCallbacks["$callbackId"];error?reject(result):resolve(result)}})''', name: 'dart2js future hook');
//     // val.then((value) {
//     //   final cb = jsEval(context, 'FlutterJS.nativeCallbacks["$callbackId"]');
//     //   jSObjectCallAsFunction(context, cb, nullptr, 2, jsCreateArgumentArray([dartToJs(context, value),jSValueMakeBoolean(context, 1)]), nullptr);
//     // }).catchError((error) {
//     //   final cb = jsEval(context, 'FlutterJS.nativeCallbacks["$callbackId"]');
//     //   jSObjectCallAsFunction(context, cb, nullptr, 2, jsCreateArgumentArray([dartToJs(context, error), jSValueMakeBoolean(context, 0)]), nullptr);
//     // });
//     // return result;
//   }
//   if(val is bool) {
//     return jSValueMakeBoolean(context, val ? 1 : 0);
//   }
//   if(val is int || val is double) {
//     return jSValueMakeNumber(context, val is int ? val.toDouble() : val);
//   }
//   if(val is String) {
//     Pointer<Utf8> ptr = val.toNativeUtf8();
//     final strVal = jSStringCreateWithUTF8CString(ptr);
//     final result = jSValueMakeString(context, strVal);
//     calloc.free(ptr);
//     return result;
//   }
//   if(val is Uint8List) {
//     final ptr = malloc<Uint8>(val.length);
//     final byteList = ptr.asTypedList(val.length);
//     byteList.setAll(0, val);
//     final Pointer<NativeFunction<bytes_deallocator>> deallocator = Pointer.fromFunction(_bytesDeallocator);
//     final exception = calloc<Pointer>();
//     final result = jSObjectMakeArrayBufferWithBytesNoCopy(context, ptr, val.length, deallocator, nullptr, exception);
//     String? error = jsErrorToString(context, exception);
//     calloc.free(exception);
//     if(error != null) {
//       throw error;
//     }
//     return result;
//   }
//   if(val is List) {
//     final result = jsObject.jSObjectMakeArray(context, 0, nullptr, nullptr);
//     for(int i = 0;i < val.length;i++) {
//       final exception = calloc<Pointer>();
//       jsObject.jSObjectSetPropertyAtIndex(context, result, i, dartToJs(context, val[i]), nullptr);
//       String? error = jsErrorToString(context, exception);
//       calloc.free(exception);
//       if(error != null) {
//         throw error;
//       }
//     }
//     return result;
//   }
//   if(val is Map) {
//     final result = jsObject.jSObjectMake(context, nullptr, nullptr);
//     val.forEach((key, value) {
//       final exception = calloc<Pointer>();
//       jSObjectSetPropertyForKey(context, result, dartToJs(context, key), dartToJs(context, value), 0, nullptr);
//       String? error = jsErrorToString(context, exception);
//       calloc.free(exception);
//       if(error != null) {
//         throw error;
//       }
//     });
//     return result;
//   }
//   if(val is Function) {
//     dynamic instanceId = getInstanceIdFromContext(context);
//     final callbackId = _addNativeCallback(instanceId, val);
//     return jsEval(context, '() => FlutterJS.sendMessage("internal::native_callback",{id:$callbackId, instanceId:"$instanceId", args:[...arguments]})');
//   }
//   throw UnsupportedError('Convert dart type[${val.runtimeType}] to JS type is not yet supported!');
// }
//
// Pointer<Pointer<NativeType>> dartArrayToJs(Pointer<NativeType> context, List array) {
//   final pointer = calloc<Pointer>(array.length);
//   for(int i = 0;i<array.length;i++) {
//     pointer[i] = dartToJs(context, array[i]);
//   }
//   return pointer;
// }
//
// Pointer<Pointer<NativeType>> jsCreateArgumentArray(Iterable<Pointer<NativeType>> array) {
//   final pointer = calloc<Pointer>(array.length);
//   int i = 0;
//   array.forEach((element) {
//     pointer[i++] = element;
//   });
//   return pointer;
// }