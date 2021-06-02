import 'dart:ffi';

import 'jsc_ffi.dart';

/// Creates a JavaScript context group.
/// A JSContextGroup associates JavaScript contexts with one another.
/// Contexts in the same group may share and exchange JavaScript objects. Sharing and/or exchanging
/// JavaScript objects between contexts in different groups will produce undefined behavior.
/// When objects from the same context group are used in multiple threads, explicit
/// synchronization is required.
///
/// A JSContextGroup may need to run deferred tasks on a run loop, such as garbage collection
/// or resolving WebAssembly compilations. By default, calling JSContextGroupCreate will use
/// the run loop of the thread it was called on. Currently, there is no API to change a
/// JSContextGroup's run loop once it has been created.
/// [@result] (JSContextGroupRef) The created JSContextGroup.
final jSContextGroupCreate = jscLib!
    .lookupFunction<JSContextGroupRef Function(), JSContextGroupRef Function()>('JSContextGroupCreate');

/// Retains a JavaScript context group.
/// [group] (JSContextGroupRef) The JSContextGroup to retain.
/// [@result] (JSContextGroupRef) A JSContextGroup that is the same as group.
final jSContextGroupRetain = jscLib!
    .lookupFunction<JSContextGroupRef Function(JSContextGroupRef), JSContextGroupRef Function(JSContextGroupRef group)>('JSContextGroupRetain');

/// Releases a JavaScript context group.
/// [group] (JSContextGroupRef) The JSContextGroup to release.
final void Function(JSContextGroupRef group) jSContextGroupRelease = jscLib!
    .lookup<NativeFunction<Void Function(JSContextGroupRef)>>('JSContextGroupRelease')
    .asFunction();

/// Creates a global JavaScript execution context.
/// JSGlobalContextCreate allocates a global object and populates it with all the
/// built-in JavaScript objects, such as Object, Function, String, and Array.
///
/// In WebKit version 4.0 and later, the context is created in a unique context group.
/// Therefore, scripts may execute in it concurrently with scripts executing in other contexts.
/// However, you may not use values created in the context in other contexts.
/// [globalObjectClass] (JSClassRef) The class to use when creating the global object. Pass NULL to use the default object class.
/// [@result] (JSGlobalContextRef) A JSGlobalContext with a global object of class globalObjectClass.
final JSGlobalContextRef Function(Pointer globalObjectClass) jSGlobalContextCreate = jscLib!
    .lookup<NativeFunction<JSGlobalContextRef Function(Pointer)>>('JSGlobalContextCreate')
    .asFunction();

/// Creates a global JavaScript execution context in the context group provided.
/// JSGlobalContextCreateInGroup allocates a global object and populates it with
/// all the built-in JavaScript objects, such as Object, Function, String, and Array.
/// [group] (JSContextGroupRef) The context group to use. The created global context retains the group. Pass NULL to create a unique group for the context.
/// [globalObjectClass] (JSClassRef) The class to use when creating the global object. Pass NULL to use the default object class.
/// [@result] (JSGlobalContextRef) A JSGlobalContext with a global object of class globalObjectClass and a context group equal to group.
final JSGlobalContextRef Function(JSContextGroupRef group, Pointer globalObjectClass)
    jSGlobalContextCreateInGroup = jscLib!
        .lookup<NativeFunction<JSGlobalContextRef Function(JSContextGroupRef, Pointer)>>(
            'JSGlobalContextCreateInGroup')
        .asFunction();

/// Retains a global JavaScript execution context.
/// [ctx] (JSGlobalContextRef) The JSGlobalContext to retain.
/// [@result] (JSGlobalContextRef) A JSGlobalContext that is the same as ctx.
final JSGlobalContextRef Function(JSGlobalContextRef ctx) jSGlobalContextRetain = jscLib!
    .lookup<NativeFunction<JSGlobalContextRef Function(JSGlobalContextRef)>>('JSGlobalContextRetain')
    .asFunction();

/// Releases a global JavaScript execution context.
/// [ctx] (JSGlobalContextRef) The JSGlobalContext to release.
final void Function(JSGlobalContextRef ctx) jSGlobalContextRelease = jscLib!
    .lookup<NativeFunction<Void Function(JSGlobalContextRef)>>('JSGlobalContextRelease')
    .asFunction();

/// Gets the global object of a JavaScript execution context.
/// [ctx] (JSContextRef) The JSContext whose global object you want to get.
/// [@result] (JSObjectRef) ctx's global object.
final JSObjectRef Function(JSContextRef ctx) jSContextGetGlobalObject = jscLib!
    .lookup<NativeFunction<JSObjectRef Function(JSContextRef)>>(
        'JSContextGetGlobalObject')
    .asFunction();

/// Gets the context group to which a JavaScript execution context belongs.
/// [ctx] (JSContextRef) The JSContext whose group you want to get.
/// [@result] (JSContextGroupRef) ctx's group.
final JSContextGroupRef Function(JSContextRef ctx) jSContextGetGroup = jscLib!
    .lookup<NativeFunction<JSContextGroupRef Function(JSContextRef)>>('JSContextGetGroup')
    .asFunction();

/// Gets the global context of a JavaScript execution context.
/// [ctx] (JSContextRef) The JSContext whose global context you want to get.
/// [@result] (JSGlobalContextRef) ctx's global context.
final JSGlobalContextRef Function(JSContextRef ctx) jSContextGetGlobalContext = jscLib!
    .lookup<NativeFunction<JSGlobalContextRef Function(JSContextRef)>>(
        'JSContextGetGlobalContext')
    .asFunction();

/// Gets a copy of the name of a context.
/// A JSGlobalContext's name is exposed for remote debugging to make it
/// easier to identify the context you would like to attach to.
/// [ctx] (JSGlobalContextRef) The JSGlobalContext whose name you want to get.
/// [@result] (JSStringRef) The name for ctx.
final JSStringRef Function(JSGlobalContextRef ctx) jSGlobalContextCopyName = jscLib!
    .lookup<NativeFunction<JSStringRef Function(JSGlobalContextRef)>>(
        'JSGlobalContextCopyName')
    .asFunction();

/// Sets the remote debugging name for a context.
/// [ctx] (JSGlobalContextRef) The JSGlobalContext that you want to name.
/// [name] (JSStringRef) The remote debugging name to set on ctx.
final void Function(JSGlobalContextRef ctx, JSStringRef name) jSGlobalContextSetName = jscLib!
    .lookup<NativeFunction<Void Function(JSGlobalContextRef, JSStringRef)>>(
        'JSGlobalContextSetName')
    .asFunction();
