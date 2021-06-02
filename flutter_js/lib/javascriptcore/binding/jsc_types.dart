import 'dart:ffi';

import '../../types.dart';
export '../../types.dart';

typedef JSValueRef = JSValuePointer;
typedef JSContextRef = JSContextPointer;
typedef JSGlobalContextRef = JSContextRef;
typedef JSObjectRef = JSValuePointer;
typedef JSObjectRefRef = Pointer<JSObjectRef>;
typedef JSValueRefRef = Pointer<JSValueRef>;
typedef JSStringRefArray = Pointer<JSValueRef>;
typedef JSStringRef = JSValuePointer;
typedef JSValueRefArray = Pointer<JSStringRef>;
abstract class JSContextGroup extends Opaque {}
typedef JSContextGroupRef = Pointer<JSContextGroup>;

typedef JSCharArray = HeapUnicodeCharPointer;