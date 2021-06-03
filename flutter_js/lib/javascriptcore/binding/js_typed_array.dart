import 'dart:ffi';

import 'js_base.dart';
import 'jsc_ffi.dart';

/// Creates a JavaScript Typed Array object with the given number of elements.
/// [ctx] (JSContextRef) The execution context to use.
/// [arrayType] (JSTypedArrayType) A value identifying the type of array to create. If arrayType is kJSTypedArrayTypeNone or kJSTypedArrayTypeArrayBuffer then NULL will be returned.
/// [length] (size_t) The number of elements to be in the new Typed Array.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObjectRef that is a Typed Array with all elements set to zero or NULL if there was an error.
final Pointer Function(
    JSContextRef ctx,
    int arrayType,
    int length,
    JSValueRefRef
        exception) jSObjectMakeTypedArray = jscLib!
    .lookup<NativeFunction<Pointer Function(JSContextRef, Int8, Uint32, JSValueRefRef)>>(
        'JSObjectMakeTypedArray')
    .asFunction();

/// Creates a JavaScript Typed Array object from an existing pointer.
/// If an exception is thrown during this function the bytesDeallocator will always be called.
/// [ctx] (JSContextRef) The execution context to use.
/// [arrayType] (JSTypedArrayType) A value identifying the type of array to create. If arrayType is kJSTypedArrayTypeNone or kJSTypedArrayTypeArrayBuffer then NULL will be returned.
/// [bytes] (void*) A pointer to the byte buffer to be used as the backing store of the Typed Array object.
/// [byteLength] (size_t) The number of bytes pointed to by the parameter bytes.
/// [bytesDeallocator] (JSTypedArrayBytesDeallocator) The allocator to use to deallocate the external buffer when the JSTypedArrayData object is deallocated.
/// [deallocatorContext] (void*) A pointer to pass back to the deallocator.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObjectRef Typed Array whose backing store is the same as the one pointed to by bytes or NULL if there was an error.
final Pointer Function(
    JSContextRef ctx,
        int arrayType,
        Pointer<Pointer> bytes,
        int byteLength,
        Pointer<NativeFunction<JSTypedArrayBytesDeallocator>> bytesDeallocator,
        Pointer deallocatorContext,
    JSValueRefRef exception) jSObjectMakeTypedArrayWithBytesNoCopy =
    jscLib!
        .lookup<
            NativeFunction<
                Pointer Function(JSContextRef, Int8, Pointer, Uint32, Pointer,
                    Pointer, JSValueRefRef)>>('JSObjectMakeTypedArrayWithBytesNoCopy')
        .asFunction();

/// Creates a JavaScript Typed Array object from an existing JavaScript Array Buffer object.
/// [ctx] (JSContextRef) The execution context to use.
/// [arrayType] (JSTypedArrayType) A value identifying the type of array to create. If arrayType is kJSTypedArrayTypeNone or kJSTypedArrayTypeArrayBuffer then NULL will be returned.
/// [buffer] (JSObjectRef) An Array Buffer object that should be used as the backing store for the created JavaScript Typed Array object.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObjectRef that is a Typed Array or NULL if there was an error. The backing store of the Typed Array will be buffer.
final JSObjectRef Function(
    JSContextRef ctx,
    int arrayType,
    JSObjectRef buffer,
    JSValueRefRef
        exception) jSObjectMakeTypedArrayWithArrayBuffer = jscLib!
    .lookup<NativeFunction<JSObjectRef Function(JSContextRef, Int8, JSObjectRef, JSValueRefRef)>>(
        'JSObjectMakeTypedArrayWithArrayBuffer')
    .asFunction();

/// Creates a JavaScript Typed Array object from an existing JavaScript Array Buffer object with the given offset and length.
/// [ctx] (JSContextRef) The execution context to use.
/// [arrayType] (JSTypedArrayType) A value identifying the type of array to create. If arrayType is kJSTypedArrayTypeNone or kJSTypedArrayTypeArrayBuffer then NULL will be returned.
/// [buffer] (JSObjectRef) An Array Buffer object that should be used as the backing store for the created JavaScript Typed Array object.
/// [byteOffset] (size_t) The byte offset for the created Typed Array. byteOffset should aligned with the element size of arrayType.
/// [length] (size_t) The number of elements to include in the Typed Array.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObjectRef that is a Typed Array or NULL if there was an error. The backing store of the Typed Array will be buffer.
final JSObjectRef Function(JSContextRef ctx, int arrayType, JSObjectRef buffer,
        int byteOffset, int length, JSValueRefRef exception)
    jSObjectMakeTypedArrayWithArrayBufferAndOffset = jscLib!
        .lookup<
            NativeFunction<
                JSObjectRef Function(JSContextRef, Int8, JSObjectRef, Uint32, Uint32,
                    JSValueRefRef)>>('JSObjectMakeTypedArrayWithArrayBufferAndOffset')
        .asFunction();

/// Returns a temporary pointer to the backing store of a JavaScript Typed Array object.
/// The pointer returned by this function is temporary and is not guaranteed to remain valid across JavaScriptCore API calls.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The Typed Array object whose backing store pointer to return.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (void*) A pointer to the raw data buffer that serves as object's backing store or NULL if object is not a Typed Array object.
final Pointer<Pointer> Function(
    JSContextRef ctx, JSObjectRef object, JSValueRefRef exception)
    jSObjectGetTypedArrayBytesPtr = jscLib!
        .lookup<
            NativeFunction<
                Pointer<Pointer> Function(JSContextRef, JSObjectRef,
                    JSValueRefRef)>>('JSObjectGetTypedArrayBytesPtr')
        .asFunction();

/// Returns the length of a JavaScript Typed Array object.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The Typed Array object whose length to return.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (size_t) The length of the Typed Array object or 0 if the object is not a Typed Array object.
final int Function(JSContextRef ctx, JSObjectRef object, JSValueRefRef exception)
    jSObjectGetTypedArrayLength = jscLib!
        .lookup<NativeFunction<Uint32 Function(JSContextRef, JSObjectRef, JSValueRefRef)>>(
            'JSObjectGetTypedArrayLength')
        .asFunction();

/// Returns the byte length of a JavaScript Typed Array object.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The Typed Array object whose byte length to return.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (size_t) The byte length of the Typed Array object or 0 if the object is not a Typed Array object.
final int Function(JSContextRef ctx, JSObjectRef object, JSValueRefRef exception)
    jSObjectGetTypedArrayByteLength = jscLib!
        .lookup<NativeFunction<Uint32 Function(JSContextRef, JSObjectRef, JSValueRefRef)>>(
            'JSObjectGetTypedArrayByteLength')
        .asFunction();

/// Returns the byte offset of a JavaScript Typed Array object.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The Typed Array object whose byte offset to return.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (size_t) The byte offset of the Typed Array object or 0 if the object is not a Typed Array object.
final int Function(JSContextRef ctx, JSObjectRef object, JSValueRefRef exception)
    jSObjectGetTypedArrayByteOffset = jscLib!
        .lookup<NativeFunction<Uint32 Function(JSContextRef, JSObjectRef, JSValueRefRef)>>(
            'JSObjectGetTypedArrayByteOffset')
        .asFunction();

/// Returns the JavaScript Array Buffer object that is used as the backing of a JavaScript Typed Array object.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObjectRef whose Typed Array type data pointer to obtain.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObjectRef with a JSTypedArrayType of kJSTypedArrayTypeArrayBuffer or NULL if object is not a Typed Array.
final JSObjectRef Function(JSContextRef ctx, JSObjectRef object, JSValueRefRef exception)
    jSObjectGetTypedArrayBuffer = jscLib!
        .lookup<NativeFunction<JSObjectRef Function(JSContextRef, JSObjectRef, JSValueRefRef)>>(
            'JSObjectGetTypedArrayBuffer')
        .asFunction();

/// Creates a JavaScript Array Buffer object from an existing pointer.
/// If an exception is thrown during this function the bytesDeallocator will always be called.
/// [ctx] (JSContextRef) The execution context to use.
/// [bytes] (void*) A pointer to the byte buffer to be used as the backing store of the Typed Array object.
/// [byteLength] (size_t) The number of bytes pointed to by the parameter bytes.
/// [bytesDeallocator] (JSTypedArrayBytesDeallocator) The allocator to use to deallocate the external buffer when the Typed Array data object is deallocated.
/// [deallocatorContext] (void*) A pointer to pass back to the deallocator.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObjectRef Array Buffer whose backing store is the same as the one pointed to by bytes or NULL if there was an error.
final JSObjectRef Function(
    JSContextRef ctx,
        Pointer bytes,
        int byteLength,
        Pointer<NativeFunction<JSTypedArrayBytesDeallocator>> bytesDeallocator,
        Pointer deallocatorContext,
    JSValueRefRef exception) jSObjectMakeArrayBufferWithBytesNoCopy =
    jscLib!
        .lookup<
            NativeFunction<
                JSObjectRef Function(JSContextRef, Pointer, Uint32, Pointer, Pointer,
                    JSValueRefRef)>>('JSObjectMakeArrayBufferWithBytesNoCopy')
        .asFunction();

/// Returns a pointer to the data buffer that serves as the backing store for a JavaScript Typed Array object.
/// The pointer returned by this function is temporary and is not guaranteed to remain valid across JavaScriptCore API calls.
/// [ctx] (JSContextRef)
/// [object] (JSObjectRef) The Array Buffer object whose internal backing store pointer to return.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (void*) A pointer to the raw data buffer that serves as object's backing store or NULL if object is not an Array Buffer object.
final Pointer<Uint8> Function(JSContextRef ctx, JSObjectRef object, JSValueRefRef exception)
    jSObjectGetArrayBufferBytesPtr = jscLib!
        .lookup<NativeFunction<Pointer<Uint8> Function(JSContextRef, JSObjectRef, JSValueRefRef)>>(
            'JSObjectGetArrayBufferBytesPtr')
        .asFunction();

/// Returns the number of bytes in a JavaScript data object.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JS Array Buffer object whose length in bytes to return.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (size_t) The number of bytes stored in the data object.
final int Function(JSContextRef ctx, JSObjectRef object, JSValueRefRef exception)
    jSObjectGetArrayBufferByteLength = jscLib!
        .lookup<NativeFunction<IntPtr Function(JSContextRef, JSObjectRef, JSValueRefRef)>>(
            'JSObjectGetArrayBufferByteLength')
        .asFunction();
