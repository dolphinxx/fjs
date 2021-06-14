// Borrowed from https://github.com/justjake/quickjs-emscripten/blob/master/c/interface.c#e58ca7bb8a3ddb008fc1bc5ef6406bb9f8a8591f
/**
 * interface.c
 *
 * We primarily use JSValue* (pointer to JSValue) when communicating with the
 * host javascript environment, because pointers are trivial to use for calls
 * into emscripten because they're just a number!
 *
 * As with the quickjs.h API, a JSValueConst* value is "borrowed" and should
 * not be freed. A JSValue* is "owned" and should be freed by the owner.
 *
 * Functions starting with "QJS_" are exported by generate.ts to:
 * - interface.h for native C code.
 * - ffi.ts for emscripten.
 */
#include <cassert>
#include <stdlib.h>

#include <string.h>
#include <stdio.h>
#include <math.h>  // For NAN
#include <stdbool.h>
#include "quickjs.h"
// #include "quickjs-libc.h"

#define PKG "fjs: "

#ifdef QJS_DEBUG_MODE
#define QJS_DEBUG(msg) qts_log(msg);
#define QJS_DUMP(value) qts_dump(ctx, value);
#else
#define QJS_DEBUG(msg) ;
#define QJS_DUMP(value) ;
#endif

extern "C"
{

/**
 * Signal to our FFI code generator that this string argument should be passed as a pointer
 * allocated by the caller on the heap, not a JS string on the stack.
 * https://github.com/emscripten-core/emscripten/issues/6860#issuecomment-405818401
 */
#define HeapChar const char

void qts_log(char* msg) {
  fputs(PKG, stderr);
  fputs(msg, stderr);
  fputs("\n", stderr);
}

void qts_dump(JSContext *ctx, JSValueConst value) {
  const char *str = JS_ToCString(ctx, value);
  if (!str) {
    QJS_DEBUG("QJS_DUMP: can't dump");
    return;
  }
  fputs(str, stderr);
  JS_FreeCString(ctx, str);
  putchar('\n');
}

void copy_prop_if_needed(JSContext* ctx, JSValueConst dest, JSValueConst src, const char* prop_name) {
  JSAtom prop_atom = JS_NewAtom(ctx, prop_name);
  JSValue dest_prop = JS_GetProperty(ctx, dest, prop_atom);
  if (JS_IsUndefined(dest_prop)) {
    JSValue src_prop = JS_GetProperty(ctx, src, prop_atom);
    if (!JS_IsUndefined(src_prop) && !JS_IsException(src_prop)) {
      JS_SetProperty(ctx, dest, prop_atom, src_prop);
    }
  } else {
    JS_FreeValue(ctx, dest_prop);
  }
  JS_FreeAtom(ctx, prop_atom);
}

JSValue *jsvalue_to_heap(JSValueConst value) {
  JSValue* result = static_cast<JSValue *>(malloc(sizeof(JSValue)));
  if (result) {
    memcpy(result, &value, sizeof(JSValue));
  }
  return result;
}

/**
 * C -> Host JS calls support
 */

// When host javascript loads this Emscripten module, it should set `bound_callback` to a dispatcher function.
typedef JSValue* QJS_C_To_HostCallbackFunc(JSContext *ctx, JSValueConst *this_ptr, int argc, JSValueConst *argv, JSValueConst *fn_data_ptr);
QJS_C_To_HostCallbackFunc* bound_callback = NULL;

void QJS_SetHostCallback(QJS_C_To_HostCallbackFunc* fp) {
  bound_callback = fp;
}

// We always use a pointer to this function with NewCFunctionData.
// The host JS should do it's own dispatch based on the value of *func_data.
JSValue qts_quickjs_to_c_callback(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv, int magic, JSValue *func_data) {
  if (bound_callback == NULL) {
    printf(PKG "callback from C, but no QJS_C_To_HostCallback set");
    abort();
  }

  JSValue* result_ptr = (*bound_callback)(ctx, &this_val, argc, argv, func_data);
  if (result_ptr == NULL) {
    return JS_UNDEFINED;
  }
  JSValue result = *result_ptr;
  free(result_ptr);
  return result;
}

JSValueConst *QJS_ArgvGetJSValueConstPointer(JSValueConst *argv, int index) {
  return &argv[index];
}

JSValue *QJS_NewFunction(JSContext *ctx, JSValueConst *func_data, const char* name) {
  JSValue func_obj = JS_NewCFunctionData(ctx, &qts_quickjs_to_c_callback, /* min argc */0, /* unused magic */0, /* func_data len */1, func_data);
  if (name != NULL) {
    JS_DefinePropertyValueStr(ctx, func_obj, "name", JS_NewString(ctx, name), JS_PROP_CONFIGURABLE);
  }
  return jsvalue_to_heap(func_obj);
}

JSValue *QJS_Throw(JSContext *ctx, JSValueConst* error) {
  JSValue copy = JS_DupValue(ctx, *error);
  return jsvalue_to_heap(JS_Throw(ctx, copy));
}

JSValue *QJS_NewError(JSContext *ctx) {
  return jsvalue_to_heap(JS_NewError(ctx));
}


/**
 * Interrupt handler - called regularly from QuickJS. Return !=0 to interrupt.
 * TODO: because this is perf critical, really send a new func pointer for each
 * call to QJS_RuntimeEnableInterruptHandler instead of using dispatch.
 */
typedef int QJS_C_To_HostInterruptFunc(JSRuntime *rt);
QJS_C_To_HostInterruptFunc *bound_interrupt = NULL;

int qts_interrupt_handler(JSRuntime *rt, void *_unused) {
  if (bound_interrupt == NULL) {
    printf(PKG "cannot call interrupt handler because no QJS_C_To_HostInterruptFunc set");
    abort();
  }
  return (*bound_interrupt)(rt);
}

void QJS_SetInterruptCallback(QJS_C_To_HostInterruptFunc *cb) {
  bound_interrupt = cb;
}

void QJS_RuntimeEnableInterruptHandler(JSRuntime *rt) {
  if (bound_interrupt == NULL) {
    printf(PKG "cannot enable interrupt handler because no QJS_C_To_HostInterruptFunc set");
    abort();
  }

  JS_SetInterruptHandler(rt, &qts_interrupt_handler, NULL);
}

void QJS_RuntimeDisableInterruptHandler(JSRuntime *rt) {
  JS_SetInterruptHandler(rt, NULL, NULL);
}

/**
 * Limits.
 */

/**
 * Memory limit. Set to -1 to disable.
 */
void QJS_RuntimeSetMemoryLimit(JSRuntime *rt, size_t limit) {
  JS_SetMemoryLimit(rt, limit);
}

/**
 * Memory diagnostics
 */

JSValue *QJS_RuntimeComputeMemoryUsage(JSRuntime *rt, JSContext *ctx) {
  JSMemoryUsage s;
  JS_ComputeMemoryUsage(rt, &s);

  // Note that we're going to allocate more memory just to report the memory usage.
  // A more sound approach would be to bind JSMemoryUsage struct directly - but that's
  // a lot of work. This should be okay in the mean time.
  JSValue result = JS_NewObject(ctx);

  // Manually generated via editor-fu from JSMemoryUsage struct definition in quickjs.h
  JS_SetPropertyStr(ctx, result, "malloc_limit", JS_NewInt64(ctx, s.malloc_limit));
  JS_SetPropertyStr(ctx, result, "memory_used_size", JS_NewInt64(ctx, s.memory_used_size));
  JS_SetPropertyStr(ctx, result, "malloc_count", JS_NewInt64(ctx, s.malloc_count));
  JS_SetPropertyStr(ctx, result, "memory_used_count", JS_NewInt64(ctx, s.memory_used_count));
  JS_SetPropertyStr(ctx, result, "atom_count", JS_NewInt64(ctx, s.atom_count));
  JS_SetPropertyStr(ctx, result, "atom_size", JS_NewInt64(ctx, s.atom_size));
  JS_SetPropertyStr(ctx, result, "str_count", JS_NewInt64(ctx, s.str_count));
  JS_SetPropertyStr(ctx, result, "str_size", JS_NewInt64(ctx, s.str_size));
  JS_SetPropertyStr(ctx, result, "obj_count", JS_NewInt64(ctx, s.obj_count));
  JS_SetPropertyStr(ctx, result, "obj_size", JS_NewInt64(ctx, s.obj_size));
  JS_SetPropertyStr(ctx, result, "prop_count", JS_NewInt64(ctx, s.prop_count));
  JS_SetPropertyStr(ctx, result, "prop_size", JS_NewInt64(ctx, s.prop_size));
  JS_SetPropertyStr(ctx, result, "shape_count", JS_NewInt64(ctx, s.shape_count));
  JS_SetPropertyStr(ctx, result, "shape_size", JS_NewInt64(ctx, s.shape_size));
  JS_SetPropertyStr(ctx, result, "js_func_count", JS_NewInt64(ctx, s.js_func_count));
  JS_SetPropertyStr(ctx, result, "js_func_size", JS_NewInt64(ctx, s.js_func_size));
  JS_SetPropertyStr(ctx, result, "js_func_code_size", JS_NewInt64(ctx, s.js_func_code_size));
  JS_SetPropertyStr(ctx, result, "js_func_pc2line_count", JS_NewInt64(ctx, s.js_func_pc2line_count));
  JS_SetPropertyStr(ctx, result, "js_func_pc2line_size", JS_NewInt64(ctx, s.js_func_pc2line_size));
  JS_SetPropertyStr(ctx, result, "c_func_count", JS_NewInt64(ctx, s.c_func_count));
  JS_SetPropertyStr(ctx, result, "array_count", JS_NewInt64(ctx, s.array_count));
  JS_SetPropertyStr(ctx, result, "fast_array_count", JS_NewInt64(ctx, s.fast_array_count));
  JS_SetPropertyStr(ctx, result, "fast_array_elements", JS_NewInt64(ctx, s.fast_array_elements));
  JS_SetPropertyStr(ctx, result, "binary_object_count", JS_NewInt64(ctx, s.binary_object_count));
  JS_SetPropertyStr(ctx, result, "binary_object_size", JS_NewInt64(ctx, s.binary_object_size));

  return jsvalue_to_heap(result);
}

char* QJS_RuntimeDumpMemoryUsage(JSRuntime *rt, int size) {
  char *result = new char[sizeof(char) * size];
  JSMemoryUsage s;
  JS_ComputeMemoryUsage(rt, &s);
  // JS_DumpMemoryUsage(memfile, &s, rt);
  JS_DumpMemoryUsageToCharArray(result, size, &s, rt);
  return result;
}

/**
 * Constant pointers. Because we always use JSValue* from the host Javascript environment,
 * we need helper fuctions to return pointers to these constants.
 */

JSValueConst QJS_Undefined = JS_UNDEFINED;
JSValueConst *QJS_GetUndefined() {
  return &QJS_Undefined;
}

JSValueConst QJS_Null = JS_NULL;
JSValueConst *QJS_GetNull() {
  return &QJS_Null;
}

JSValueConst QJS_False = JS_FALSE;
JSValueConst *QJS_GetFalse() {
  return &QJS_False;
}

JSValueConst QJS_True = JS_TRUE;
JSValueConst *QJS_GetTrue() {
  return &QJS_True;
}

JSValue *QJS_NewBool(JSContext *ctx, int32_t val) {
  return jsvalue_to_heap(JS_NewBool(ctx, val));
}

/**
 * Standard FFI functions
 */

JSRuntime *QJS_NewRuntime() {
  return JS_NewRuntime();
}

void QJS_FreeRuntime(JSRuntime *rt) {
  JS_FreeRuntime(rt);
}

JSContext *QJS_NewContext(JSRuntime *rt) {
  return JS_NewContext(rt);
}

void QJS_FreeContext(JSContext *ctx) {
  JS_FreeContext(ctx);
}

void QJS_FreeValuePointer(JSContext *ctx, JSValue *value) {
  JS_FreeValue(ctx, *value);
  free(value);
}

JSValue *QJS_DupValuePointer(JSContext* ctx, JSValueConst *val) {
  return jsvalue_to_heap(JS_DupValue(ctx, *val));
}

JSValue *QJS_NewObject(JSContext *ctx) {
  return jsvalue_to_heap(JS_NewObject(ctx));
}

JSValue *QJS_NewObjectProto(JSContext *ctx, JSValueConst *proto) {
  return jsvalue_to_heap(JS_NewObjectProto(ctx, *proto));
}

JSValue *QJS_NewArray(JSContext *ctx) {
  return jsvalue_to_heap(JS_NewArray(ctx));
}

JSValue *QJS_NewFloat64(JSContext *ctx, double num) {
  return jsvalue_to_heap(JS_NewFloat64(ctx, num));
}

double QJS_GetFloat64(JSContext *ctx, JSValueConst *value) {
  double result = NAN;
  JS_ToFloat64(ctx, &result, *value);
  return result;
}

JSValue *QJS_NewString(JSContext *ctx, HeapChar *string) {
  return jsvalue_to_heap(JS_NewString(ctx, string));
}

char* QJS_GetString(JSContext *ctx, JSValueConst *value) {
  const char* owned = JS_ToCString(ctx, *value);
  char* result = strdup(owned);
  JS_FreeCString(ctx, owned);
  return result;
}

int QJS_IsJobPending(JSRuntime *rt) {
  return JS_IsJobPending(rt);
}

/*
  runs pending jobs (Promises/async functions) until it encounters
  an exception or it executed the passed maxJobsToExecute jobs.

  Passing a negative value will run the loop until there are no more
  pending jobs or an exception happened

  Returns the executed number of jobs or the exception encountered
*/
JSValue *QJS_ExecutePendingJob(JSRuntime *rt, int maxJobsToExecute) {
  JSContext *pctx;
  int status = 1;
  int executed = 0;
  while (executed != maxJobsToExecute && status == 1) {
    status = JS_ExecutePendingJob(rt, &pctx);
    if (status == -1) {
      return jsvalue_to_heap(JS_GetException(pctx));
    } else if (status == 1) {
      executed++;
    }
  }
  return jsvalue_to_heap(JS_NewFloat64(pctx, executed));
}

JSValue *QJS_GetProp(JSContext *ctx, JSValueConst *this_val, JSValueConst *prop_name) {
  JSAtom prop_atom = JS_ValueToAtom(ctx, *prop_name);
  JSValue prop_val = JS_GetProperty(ctx, *this_val, prop_atom);
  JS_FreeAtom(ctx, prop_atom);
  return jsvalue_to_heap(prop_val);
}

void QJS_SetProp(JSContext *ctx, JSValueConst *this_val, JSValueConst *prop_name, JSValueConst *prop_value) {
  JSAtom prop_atom = JS_ValueToAtom(ctx, *prop_name);
  JSValue extra_prop_value = JS_DupValue(ctx, *prop_value);
  // TODO: should we use DefineProperty internally if this object doesn't have the property yet?
  JS_SetProperty(ctx, *this_val, prop_atom, extra_prop_value); // consumes extra_prop_value
  JS_FreeAtom(ctx, prop_atom);
}

void QJS_DefineProp(JSContext *ctx, JSValueConst *this_val, JSValueConst *prop_name, JSValueConst *prop_value, JSValueConst *get, JSValueConst *set, bool configurable, bool enumerable, bool writable, bool has_value) {
  JSAtom prop_atom = JS_ValueToAtom(ctx, *prop_name);

  int flags = 0;
  if (configurable) {
    flags = flags | JS_PROP_CONFIGURABLE;
    if (has_value) {
      flags = flags | JS_PROP_HAS_CONFIGURABLE;
    }
  }
  if (enumerable) {
    flags = flags | JS_PROP_ENUMERABLE;
    if (has_value) {
      flags = flags | JS_PROP_HAS_ENUMERABLE;
    }
  }
  if (writable) {
      flags = flags | JS_PROP_WRITABLE;
      if (has_value) {
          flags = flags | JS_PROP_HAS_WRITABLE;
      }
  }
  if (!JS_IsUndefined(*get)) {
    flags = flags | JS_PROP_HAS_GET;
  }
  if (!JS_IsUndefined(*set)) {
    flags = flags | JS_PROP_HAS_SET;
  }
  if (has_value) {
    flags = flags | JS_PROP_HAS_VALUE;
  }

  JS_DefineProperty(ctx, *this_val, prop_atom, *prop_value, *get, *set, flags);
  JS_FreeAtom(ctx, prop_atom);
}


JSValue *QJS_Call(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj, int argc, JSValueConst **argv_ptrs) {
  // convert array of pointers to array of values
  JSValueConst *argv = new JSValueConst[argc];
  int i;
  for (i=0; i<argc; i++) {
    argv[i] = *(argv_ptrs[i]);
  }

  return jsvalue_to_heap(JS_Call(ctx, *func_obj, *this_obj, argc, argv));
}

void QJS_CallVoid(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj, int argc, JSValueConst **argv_ptrs) {
  // convert array of pointers to array of values
  JSValueConst *argv = new JSValueConst[argc];
  int i;
  for (i=0; i<argc; i++) {
    argv[i] = *(argv_ptrs[i]);
  }

  JSValue res = JS_Call(ctx, *func_obj, *this_obj, argc, argv);
  JS_FreeValue(ctx, res);
}

/**
 * If maybe_exception is an exception, get the error.
 * Otherwise, return NULL.
 */
JSValue *QJS_ResolveException(JSContext *ctx, JSValue *maybe_exception) {
  if (JS_IsException(*maybe_exception)) {
    return jsvalue_to_heap(JS_GetException(ctx));
  }

  return NULL;
}

char *QJS_Dump(JSContext *ctx, JSValueConst *obj) {
  JSValue obj_json_value = JS_JSONStringify(ctx, *obj, JS_UNDEFINED, JS_UNDEFINED);
  if (!JS_IsException(obj_json_value)) {
    const char* obj_json_chars = JS_ToCString(ctx, obj_json_value);
    JS_FreeValue(ctx, obj_json_value);
    if (obj_json_chars != NULL) {
      JSValue enumerable_props = JS_ParseJSON(ctx, obj_json_chars, strlen(obj_json_chars), "<dump>");
      JS_FreeCString(ctx, obj_json_chars);
      if (!JS_IsException(enumerable_props)) {
        // Copy common non-enumerable props for different object types.
        // Errors:
        copy_prop_if_needed(ctx, enumerable_props, *obj, "name");
        copy_prop_if_needed(ctx, enumerable_props, *obj, "message");
        copy_prop_if_needed(ctx, enumerable_props, *obj, "stack");

        // Serialize again.
        JSValue enumerable_json = JS_JSONStringify(ctx, enumerable_props, JS_UNDEFINED, JS_UNDEFINED);
        JS_FreeValue(ctx, enumerable_props);

        char * result = QJS_GetString(ctx, &enumerable_json);
        JS_FreeValue(ctx, enumerable_json);
        return result;
      }
    }
  }

#ifdef QJS_DEBUG_MODE
  qts_log("Error dumping JSON:");
  js_std_dump_error(ctx);
#endif

  // Fallback: convert to string
  return QJS_GetString(ctx, obj);
}

JSValue *QJS_Eval(JSContext *ctx, HeapChar *js_code, size_t js_code_len, HeapChar *filename, int eval_flags) {
  return jsvalue_to_heap(JS_Eval(ctx, js_code, js_code_len, filename, eval_flags));
}

char* QJS_Typeof(JSContext *ctx, JSValueConst *value) {
  const char* result = "unknown";
  uint32_t tag = JS_VALUE_GET_TAG(*value);

  if (JS_IsNumber(*value)) { result = "number"; }
  else if (tag == JS_TAG_BIG_INT) { result = "bigint"; }
  else if (JS_IsBigFloat(*value)) { result = "bigfloat"; }
  else if (JS_IsBigDecimal(*value)) { result = "bigdecimal"; }
  else if (JS_IsFunction(ctx, *value)) { result = "function"; }
  else if (JS_IsBool(*value)) { result = "boolean"; }
  else if (JS_IsNull(*value)) { result = "object"; }
  else if (JS_IsUndefined(*value)) { result = "undefined"; }
  else if (JS_IsUninitialized(*value)) { result = "undefined"; }
  else if (JS_IsString(*value)) { result = "string"; }
  else if (JS_IsSymbol(*value)) { result = "symbol"; }
  else if (JS_IsObject(*value)) { result = "object"; }

  char* out = strdup(result);
  return out;
}

JSValue *QJS_GetGlobalObject(JSContext *ctx) {
  return jsvalue_to_heap(JS_GetGlobalObject(ctx));
}

JSValue *QJS_NewPromiseCapability(JSContext *ctx, JSValue **resolve_funcs_out) {
  JSValue resolve_funcs[2];
  JSValue promise = JS_NewPromiseCapability(ctx, resolve_funcs);
  resolve_funcs_out[0] = jsvalue_to_heap(resolve_funcs[0]);
  resolve_funcs_out[1] = jsvalue_to_heap(resolve_funcs[1]);
  return jsvalue_to_heap(promise);
}

void QJS_TestStringArg(const char *string) {
  // pass
}

  // Patch Start

  /* return -1 if exception (proxy case) or TRUE/FALSE */
  int QJS_IsArray(JSContext *ctx, JSValueConst *val) {
    return JS_IsArray(ctx, *val);
  }

  int QJS_ToBool(JSContext *ctx, JSValueConst *val) {
    return JS_ToBool(ctx, *val);
  }

  JSValue *QJS_NewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len) {
    return jsvalue_to_heap(JS_NewArrayBufferCopy(ctx, buf, len));
  }

  //static void djs_buf_free(JSRuntime *rt, void *opaque, void *ptr) {
  //  js_free_rt(rt, ptr);
  //}

  JSValue *QJS_NewArrayBuffer(JSContext *ctx, uint8_t *buf, size_t len, JSFreeArrayBufferDataFunc *free_func, void *opaque, int is_shared) {
    if (free_func == NULL) {
      return jsvalue_to_heap(JS_NewArrayBuffer(ctx, buf, len, nullptr, opaque, is_shared));
    }
    return jsvalue_to_heap(JS_NewArrayBuffer(ctx, buf, len, free_func, opaque, is_shared));
  }

  uint8_t *QJS_GetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj) {
    return JS_GetArrayBuffer(ctx, psize, *obj);
  }

  int QJS_GetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab, uint32_t *plen, JSValueConst *obj, int flags) {
    return JS_GetOwnPropertyNames(ctx, ptab, plen, *obj, flags);
  }

  void dart_free_prop_enums(JSContext *ctx, JSPropertyEnum *tab, uint32_t len)
  {
    uint32_t i;
    if (tab) {
      for(i = 0; i < len; i++)
        JS_FreeAtom(ctx, tab[i].atom);
      js_free(ctx, tab);
    }
  }

  /*
  * Get atoms of the propertyNames and store to patoms, return -1 when failed, otherwise the length of atoms returned.
  */
  int QJS_GetOwnPropertyNameAtoms(JSContext *ctx, intptr_t* patoms, JSValueConst *obj, int flags) {
    uint32_t len;
    JSPropertyEnum* ptab;
    int res = JS_GetOwnPropertyNames(ctx, &ptab, &len, *obj, flags);
    if(res != 0) {
      dart_free_prop_enums(ctx, ptab, len);
      return -1;
    }
    uint32_t *cp = (uint32_t*)malloc(sizeof(uint32_t) * len);
    for(int i = 0;i<len;i++) {
      cp[i] = ptab[i].atom;
	  //printf("atom[%d]:%d\n", i, cp[i]);
    }
    dart_free_prop_enums(ctx, ptab, len);
    *patoms = (intptr_t)cp;
    //printf("patoms:%Id\n", *patoms);
    return len;
  }

  void QJS_FreePropEnums(JSContext *ctx, JSPropertyEnum *tab, uint32_t len) {
    return dart_free_prop_enums(ctx, tab, len);
  }

  JSValue *QJS_AtomToString(JSContext *ctx, JSAtom atom) {
    return jsvalue_to_heap(JS_AtomToString(ctx, atom));
  }

  JSValue *QJS_GetProperty(JSContext *ctx, JSValueConst *this_obj, JSAtom prop) {
    return jsvalue_to_heap(JS_GetPropertyInternal(ctx, *this_obj, prop, *this_obj, 0));
  }

  int QJS_HasProp(JSContext* ctx, JSValueConst* this_obj, JSValueConst *prop_name) {
      JSAtom prop_atom = JS_ValueToAtom(ctx, *prop_name);
      int result = JS_HasProperty(ctx, *this_obj, prop_atom);
      JS_FreeAtom(ctx, prop_atom);
      return result;
  }

  int QJS_HasProperty(JSContext* ctx, JSValueConst *this_obj, JSAtom prop) {
      return JS_HasProperty(ctx, *this_obj, prop);
  }

  // copied from quickjs.c
  typedef enum {
      /* classid tag        */    /* union usage   | properties */
      JS_CLASS_OBJECT = 1,        /* must be first */
      JS_CLASS_ARRAY,             /* u.array       | length */
      JS_CLASS_ERROR,
      JS_CLASS_NUMBER,            /* u.object_data */
      JS_CLASS_STRING,            /* u.object_data */
      JS_CLASS_BOOLEAN,           /* u.object_data */
      JS_CLASS_SYMBOL,            /* u.object_data */
      JS_CLASS_ARGUMENTS,         /* u.array       | length */
      JS_CLASS_MAPPED_ARGUMENTS,  /*               | length */
      JS_CLASS_DATE,              /* u.object_data */
      JS_CLASS_MODULE_NS,
      JS_CLASS_C_FUNCTION,        /* u.cfunc */
      JS_CLASS_BYTECODE_FUNCTION, /* u.func */
      JS_CLASS_BOUND_FUNCTION,    /* u.bound_function */
      JS_CLASS_C_FUNCTION_DATA,   /* u.c_function_data_record */
      JS_CLASS_GENERATOR_FUNCTION, /* u.func */
      JS_CLASS_FOR_IN_ITERATOR,   /* u.for_in_iterator */
      JS_CLASS_REGEXP,            /* u.regexp */
      JS_CLASS_ARRAY_BUFFER,      /* u.array_buffer */
      JS_CLASS_SHARED_ARRAY_BUFFER, /* u.array_buffer */
      JS_CLASS_UINT8C_ARRAY,      /* u.array (typed_array) */
      JS_CLASS_INT8_ARRAY,        /* u.array (typed_array) */
      JS_CLASS_UINT8_ARRAY,       /* u.array (typed_array) */
      JS_CLASS_INT16_ARRAY,       /* u.array (typed_array) */
      JS_CLASS_UINT16_ARRAY,      /* u.array (typed_array) */
      JS_CLASS_INT32_ARRAY,       /* u.array (typed_array) */
      JS_CLASS_UINT32_ARRAY,      /* u.array (typed_array) */
#ifdef CONFIG_BIGNUM
      JS_CLASS_BIG_INT64_ARRAY,   /* u.array (typed_array) */
      JS_CLASS_BIG_UINT64_ARRAY,  /* u.array (typed_array) */
#endif
      JS_CLASS_FLOAT32_ARRAY,     /* u.array (typed_array) */
      JS_CLASS_FLOAT64_ARRAY,     /* u.array (typed_array) */
      JS_CLASS_DATAVIEW,          /* u.typed_array */
#ifdef CONFIG_BIGNUM
      JS_CLASS_BIG_INT,           /* u.object_data */
      JS_CLASS_BIG_FLOAT,         /* u.object_data */
      JS_CLASS_FLOAT_ENV,         /* u.float_env */
      JS_CLASS_BIG_DECIMAL,       /* u.object_data */
      JS_CLASS_OPERATOR_SET,      /* u.operator_set */
#endif
      JS_CLASS_MAP,               /* u.map_state */
      JS_CLASS_SET,               /* u.map_state */
      JS_CLASS_WEAKMAP,           /* u.map_state */
      JS_CLASS_WEAKSET,           /* u.map_state */
      JS_CLASS_MAP_ITERATOR,      /* u.map_iterator_data */
      JS_CLASS_SET_ITERATOR,      /* u.map_iterator_data */
      JS_CLASS_ARRAY_ITERATOR,    /* u.array_iterator_data */
      JS_CLASS_STRING_ITERATOR,   /* u.array_iterator_data */
      JS_CLASS_REGEXP_STRING_ITERATOR,   /* u.regexp_string_iterator_data */
      JS_CLASS_GENERATOR,         /* u.generator_data */
      JS_CLASS_PROXY,             /* u.proxy_data */
      JS_CLASS_PROMISE,           /* u.promise_data */
      JS_CLASS_PROMISE_RESOLVE_FUNCTION,  /* u.promise_function_data */
      JS_CLASS_PROMISE_REJECT_FUNCTION,   /* u.promise_function_data */
      JS_CLASS_ASYNC_FUNCTION,            /* u.func */
      JS_CLASS_ASYNC_FUNCTION_RESOLVE,    /* u.async_function_data */
      JS_CLASS_ASYNC_FUNCTION_REJECT,     /* u.async_function_data */
      JS_CLASS_ASYNC_FROM_SYNC_ITERATOR,  /* u.async_from_sync_iterator_data */
      JS_CLASS_ASYNC_GENERATOR_FUNCTION,  /* u.func */
      JS_CLASS_ASYNC_GENERATOR,   /* u.async_generator_data */

      JS_CLASS_INIT_COUNT, /* last entry for predefined classes */
  } ClassID;

  int8_t QJS_HandyTypeof(JSContext *ctx, JSValueConst *value) {
    uint32_t tag = JS_VALUE_GET_TAG(*value);
    if(JS_IsUninitialized(*value)) {
      return -1/*"uninitialized"*/;
    }
    if(tag == JS_TAG_UNDEFINED) {
      return 1/*"undefined"*/;
    }
    if (tag == JS_TAG_NULL) {
      return 2/*"null"*/;
    }
    if(tag == JS_TAG_BOOL) {
      return 3/*"boolean"*/;
    }
    if(tag == JS_TAG_STRING) {
      return 4/*"string"*/;
    }
    if(tag == JS_TAG_SYMBOL) {
      return 5/*"Symbol"*/;
    }
    if(JS_IsFunction(ctx, *value)) {
      return 6/*"function"*/;
    }


    if(tag == JS_TAG_INT) {
      return 7/*"int"*/;
    }
    if(JS_TAG_IS_FLOAT64(tag)) {
      return 8/*"float"*/;
    }
    if (tag == JS_TAG_BIG_INT) {
      return 9/*"BigInt"*/;
    }
    if(tag == JS_TAG_BIG_FLOAT) {
      return 10/*"BigFloat"*/;
    }
    if(tag == JS_TAG_BIG_DECIMAL) {
      return 11/*"BigDecimal"*/;
    }
    if(tag == JS_TAG_OBJECT) {
      JSClassID classID = JS_GetClassID(*value);
      if(classID == JS_CLASS_PROMISE) {
        return 12/*"Promise"*/;
      }
      if (classID == JS_CLASS_ARRAY_BUFFER) {
        return 13/*"ArrayBuffer"*/;
      }
      if (classID == JS_CLASS_SHARED_ARRAY_BUFFER) {
          return 14/*"SharedArrayBuffer"*/;
      }
      if (classID == JS_CLASS_DATE) {
          return 15/*"Date"*/;
      }
      if (classID == JS_CLASS_STRING) {
          return 16/*"String"*/;
      }
      if (classID == JS_CLASS_NUMBER) {
          return 17/*"Number"*/;
      }
      if (classID == JS_CLASS_BOOLEAN) {
          return 18/*"Boolean"*/;
      }
      if (classID == JS_CLASS_ERROR) {
          return 19/*"Error"*/;
      }
      if (classID == JS_CLASS_REGEXP) {
          return 20/*"RegExp"*/;
      }
      if(JS_IsArray(ctx, *value)) {
        return 21/*"Array"*/;
      }
      return 22/*"object"*/;
    }
    return 0/*"unknown"*/;
  }

  JSValue* QJS_NewDate(JSContext* ctx, int64_t timestamp) {
      JSValue globalObj = JS_GetGlobalObject(ctx);
      JSValue date_constructor = JS_GetPropertyStr(ctx, globalObj, "Date");
      JS_FreeValue(ctx, globalObj);
      JSValue t = JS_NewInt64(ctx, timestamp);
      JSValue result = JS_CallConstructor(ctx, date_constructor, 1, {&t});
      JS_FreeValue(ctx, t);
      JS_FreeValue(ctx, date_constructor);
      return jsvalue_to_heap(result);
  }

  JSValue* QJS_CallConstructor(JSContext* ctx, JSValueConst *func_obj,
      int argc, JSValueConst** argv_ptrs) {
      // convert array of pointers to array of values
      JSValueConst* argv = new JSValueConst[argc];
      int i;
      for (i = 0; i < argc; i++) {
          argv[i] = *(argv_ptrs[i]);
      }
      return jsvalue_to_heap(JS_CallConstructor(ctx, *func_obj, argc, argv));
  }

  void QJS_ToConstructor(JSContext* ctx, JSValueConst *func_obj) {
      JS_SetConstructorBit(ctx, *func_obj, 1);
  }

  JSValue* QJS_GetException(JSContext *ctx) {
    return jsvalue_to_heap(JS_GetException(ctx));
  }

  /* for test */
  void print_exception(JSContext *ctx, JSValue val) {
      JSValue exception = JS_GetException(ctx);
      JS_FreeValue(ctx, val);
      const char* error = JS_ToCString(ctx, exception);
      JS_FreeValue(ctx, exception);
      printf("Error:\n%s\n", error);
      JS_FreeCString(ctx, error);
  }

  typedef uint8_t QJS_Module_Loader(JSContext* ctx, char **buff, size_t *len, const char* module_name);
  QJS_Module_Loader *qjs_module_loader = NULL;

  JSModuleDef *js_module_loader(JSContext *ctx,
                                const char *module_name, void *opaque)
  {
      if (qjs_module_loader == NULL) {
          JS_ThrowReferenceError(ctx, "module loader not set");
          return NULL;
      }
    JSModuleDef *m;
    size_t buf_len = 0;
    char**buf = (char**)malloc(sizeof(char *));
    JSValue func_val;
    uint8_t result = qjs_module_loader(ctx, buf, &buf_len, module_name);
    //printf("qjs_module_loader result %d, buf_len:%Id\n", result, buf_len);
    //printf("module source:\n%s\n", *buf);

    if(result == 0) {
      //printf("could not load module filename '%s'", module_name);
      JS_ThrowReferenceError(ctx, "could not load module filename '%s'", module_name);
      return NULL;
    }
    /* compile the module */
    func_val = JS_Eval(ctx, *buf, buf_len, module_name, JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
    js_free(ctx, buf);
    if (JS_IsException(func_val)) {
        //print_exception(ctx, func_val);
        return NULL;
    }

    /* the module is already referenced, so we must free it */
    m = (JSModuleDef*)JS_VALUE_GET_PTR(func_val);
    JSValue meta_obj = JS_GetImportMeta(ctx, m);
    if (JS_IsException(meta_obj)) {
        //print_exception(ctx, meta_obj);
        return NULL;
    }

    // simply use module_name as url
    JS_DefinePropertyValueStr(ctx, meta_obj, "url", JS_NewString(ctx, module_name), JS_PROP_C_W_E);
    JS_DefinePropertyValueStr(ctx, meta_obj, "main", JS_NewBool(ctx, 0), JS_PROP_C_W_E);
    JS_FreeValue(ctx, meta_obj);
    JS_FreeValue(ctx, func_val);
    return m;
  }

 void QJS_SetModuleLoaderFunc(JSRuntime* rt, QJS_Module_Loader *handler) {
    qjs_module_loader = handler;
    JS_SetModuleLoaderFunc(rt, NULL, &js_module_loader, NULL);
  }

  const char* hello_world() {
      printf("C: Hello World\n");
      return "Hello World!";
  }
}
