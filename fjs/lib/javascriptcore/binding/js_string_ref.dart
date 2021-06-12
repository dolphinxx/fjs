import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'jsc_ffi.dart';

/// Creates a JavaScript string from a buffer of Unicode characters.
/// [chars] (JSChar*) The buffer of Unicode characters to copy into the new JSString.
/// [numChars] (size_t) The number of characters to copy from the buffer pointed to by chars.
/// [@result] (JSStringRef) A JSString containing chars. Ownership follows the Create Rule.
final JSStringRef Function(Pointer<Pointer> chars, Pointer numChars)
    jSStringCreateWithCharacters = jscLib!
        .lookup<NativeFunction<JSStringRef Function(Pointer<Pointer>, Pointer)>>(
            'JSStringCreateWithCharacters')
        .asFunction();

/// Creates a JavaScript string from a null-terminated UTF8 string.
/// [string] (char*) The null-terminated UTF8 string to copy into the new JSString.
/// [@result] (JSStringRef) A JSString containing string. Ownership follows the Create Rule.
final JSStringRef Function(Pointer<Utf8> string) jSStringCreateWithUTF8CString =
    jscLib!
        .lookup<NativeFunction<JSStringRef Function(Pointer<Utf8>)>>(
            'JSStringCreateWithUTF8CString')
        .asFunction();

/// Retains a JavaScript string.
/// [string] (JSStringRef) The JSString to retain.
/// [@result] (JSStringRef) A JSString that is the same as string.
final JSStringRef Function(JSStringRef string) jSStringRetain = jscLib!
    .lookup<NativeFunction<JSStringRef Function(JSStringRef)>>('JSStringRetain')
    .asFunction();

/// Releases a JavaScript string.
/// [string] (JSStringRef) The JSString to release.
final void Function(JSStringRef string) jSStringRelease = jscLib!
    .lookup<NativeFunction<Void Function(JSStringRef)>>('JSStringRelease')
    .asFunction();

/// Returns the number of Unicode characters in a JavaScript string.
/// [string] (JSStringRef) The JSString whose length (in Unicode characters) you want to know.
/// [@result] (size_t) The number of Unicode characters stored in string.
final int Function(JSStringRef string) jSStringGetLength = jscLib!
    .lookup<NativeFunction<Int32 Function(JSStringRef)>>('JSStringGetLength')
    .asFunction();

/// Returns a pointer to the Unicode character buffer that
/// serves as the backing store for a JavaScript string.
/// [string] (JSStringRef) The JSString whose backing store you want to access.
/// [@result] (const JSChar*) A pointer to the Unicode character buffer that serves as string's backing store, which will be deallocated when string is deallocated.
final JSCharArray Function(JSStringRef string) jSStringGetCharactersPtr = jscLib!
    .lookup<NativeFunction<JSCharArray Function(JSStringRef)>>(
        'JSStringGetCharactersPtr')
    .asFunction();

/// Returns the maximum number of bytes a JavaScript string will
/// take up if converted into a null-terminated UTF8 string.
/// [string] (JSStringRef) The JSString whose maximum converted size (in bytes) you want to know.
/// [@result] (size_t) The maximum number of bytes that could be required to convert string into a null-terminated UTF8 string. The number of bytes that the conversion actually ends up requiring could be less than this, but never more.
final int Function(JSStringRef string) jSStringGetMaximumUTF8CStringSize = jscLib!
    .lookup<NativeFunction<Uint32 Function(JSStringRef)>>(
        'JSStringGetMaximumUTF8CStringSize')
    .asFunction();

/// Converts a JavaScript string into a null-terminated UTF8 string,
/// and copies the result into an external byte buffer.
/// [string] (JSStringRef) The source JSString.
/// [buffer] (char*) The destination byte buffer into which to copy a null-terminated UTF8 representation of string. On return, buffer contains a UTF8 string representation of string. If bufferSize is too small, buffer will contain only partial results. If buffer is not at least bufferSize bytes in size, behavior is undefined.
/// [bufferSize] (size_t) The size of the external buffer in bytes.
/// [@result] (size_t) The number of bytes written into buffer (including the null-terminator byte).
final int Function(JSStringRef string, HeapCharPointer buffer, int bufferSize)
    jSStringGetUTF8CString = jscLib!
        .lookup<NativeFunction<Uint32 Function(JSStringRef, HeapCharPointer, Uint32)>>(
            'JSStringGetUTF8CString')
        .asFunction();

/// Tests whether two JavaScript strings match.
/// [a] (JSStringRef) The first JSString to test.
/// [b] (JSStringRef) The second JSString to test.
/// [@result] (bool) true if the two strings match, otherwise false.
final int Function(JSStringRef a, JSStringRef b) jSStringIsEqual = jscLib!
    .lookup<NativeFunction<Uint8 Function(JSStringRef, JSStringRef)>>('JSStringIsEqual')
    .asFunction();

/// Tests whether a JavaScript string matches a null-terminated UTF8 string.
/// [a] (JSStringRef) The JSString to test.
/// [b] (char*) The null-terminated UTF8 string to test.
/// [@result] (bool) true if the two strings match, otherwise false.
final int Function(JSStringRef a, HeapCharPointer b) jSStringIsEqualToUTF8CString =
    jscLib!
        .lookup<NativeFunction<Uint8 Function(JSStringRef, HeapCharPointer)>>(
            'JSStringIsEqualToUTF8CString')
        .asFunction();
