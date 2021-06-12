import 'dart:ffi';

import '../../types.dart';
export '../../types.dart';

typedef JSValueRef = JSValuePointer;
typedef JSContextRef = JSContextPointer;
typedef JSGlobalContextRef = JSContextRef;
typedef JSObjectRef = JSValuePointer;
/// calloc<JSObjectRef>()
typedef JSObjectRefRef = Pointer<JSObjectRef>;
/// `calloc<JSValueRef>()`
typedef JSValueRefRef = Pointer<JSValueRef>;
/// `calloc<JSValueRef>()`
typedef JSValueRefArray = Pointer<JSValueRef>;
abstract class JSStringOpaque extends Opaque {}
typedef JSStringRef = Pointer<JSStringOpaque>;
/// calloc<JSStringRef>()
typedef JSStringRefArray = Pointer<JSStringRef>;
abstract class JSContextGroup extends Opaque {}
typedef JSContextGroupRef = Pointer<JSContextGroup>;

typedef JSCharArray = HeapUnicodeCharPointer;