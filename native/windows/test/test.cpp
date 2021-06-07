#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "../build/quickjs.h"
#include "../../src/interface.cpp"

extern "C"
{

    void eval(JSContext* ctx, const char* buf, int buf_len) {
        
        JSValue val = JS_Eval(ctx, buf, buf_len, "<eval>", JS_EVAL_TYPE_GLOBAL);
        if (JS_IsException(val)) {
            JSValue exception = JS_GetException(ctx);
            JS_FreeValue(ctx, val);
            const char* error = JS_ToCString(ctx, exception);
            JS_FreeValue(ctx, exception);
            printf("Eval error:\n%s", error);
            JS_FreeCString(ctx, error);
        }
        else {
            JSValue json = JS_JSONStringify(ctx, val, JS_UNDEFINED, JS_UNDEFINED);
            JS_FreeValue(ctx, val);
            const char* result = JS_ToCString(ctx, json);
            JS_FreeValue(ctx, json);
            printf("%s", result);
            JS_FreeCString(ctx, result);
        }
        
    }

    void evalToString(JSContext* ctx, const char* buf, int buf_len) {

        JSValue val = JS_Eval(ctx, buf, buf_len, "<eval>", JS_EVAL_TYPE_GLOBAL);
        if (JS_IsException(val)) {
            JSValue exception = JS_GetException(ctx);
            JS_FreeValue(ctx, val);
            const char* error = JS_ToCString(ctx, exception);
            JS_FreeValue(ctx, exception);
            printf("Eval error:\n%s", error);
            JS_FreeCString(ctx, error);
        }
        else {
            const char* result = JS_ToCString(ctx, val);
            JS_FreeValue(ctx, val);
            printf("%s", result);
            JS_FreeCString(ctx, result);
        }
    }

    int printStringify(JSContext* ctx, JSValue val) {
        if (JS_IsException(val)) {
            JSValue exception = JS_GetException(ctx);
            //JS_FreeValue(ctx, val);
            const char* error = JS_ToCString(ctx, exception);
            JS_FreeValue(ctx, exception);
            printf("Eval error:\n%s\n", error);
            JS_FreeCString(ctx, error);
            return 1;
        }
        JSValue json = JS_JSONStringify(ctx, val, JS_UNDEFINED, JS_UNDEFINED);
        //JS_FreeValue(ctx, val);
        const char* result = JS_ToCString(ctx, json);
        JS_FreeValue(ctx, json);
        printf("%s\n", result);
        JS_FreeCString(ctx, result);
        return 0;
    }

    void test_GetOwnPropertyNameAtoms(JSContext* ctx) {
        const char* code = "({a:1,b:'2'})";
        JSValue val = JS_Eval(ctx, code, strlen(code), "test_GetOwnPropertyNameAtoms", JS_EVAL_TYPE_GLOBAL);
        intptr_t* result = (intptr_t*)malloc(sizeof(intptr_t));
        //JSPropertyEnum* ptab = (JSPropertyEnum*)malloc(sizeof(JSPropertyEnum));
        int length = QJS_GetOwnPropertyNameAtoms(ctx, result/*, &ptab*/, &val, JS_GPN_STRING_MASK | JS_GPN_SYMBOL_MASK | JS_GPN_ENUM_ONLY);
        printf("length:%d, result: %d,resultp:%p\n", length, *result, result);
        //uint32_t* p = (uint32_t*)*result;
        //uint32_t* p = result;
        if (length == -1) {
            JS_FreeValue(ctx, val);
            free(result);
            return;
        }
        uint32_t* atoms = (uint32_t *)(*result);
        free(result);
        for (int i = 0; i < length; i++) {
            printf("atom[%d]:%d\n", i, atoms[i]);
            JSValue prop = JS_GetProperty(ctx, val, atoms[i]);
            //JS_FreeAtom(ctx, atoms[i]);
            if (printStringify(ctx, prop)) {
                JS_FreeValue(ctx, prop);
                //dart_free_prop_enum(ctx, ptab, length);
                //js_free(ctx, ptab);
                JS_FreeValue(ctx, val);
                free(atoms);
                return;
            }
            JS_FreeValue(ctx, prop);
        }
        printf("iterate over\n");
        // free(p);
        //dart_free_prop_enum(ctx, ptab, length);
        //js_free(ctx, ptab);
        JS_FreeValue(ctx, val);
        free(atoms);
    }

    void test_GetOwnPropertyNames(JSContext* ctx) {
        const char* code = "({a:1,b:'2'})";
        JSPropertyEnum* ptab;
        uint32_t plen;
        JSValue val = JS_Eval(ctx, code, strlen(code), "test_GetOwnPropertyNameAtoms", JS_EVAL_TYPE_GLOBAL);
        int result = JS_GetOwnPropertyNames(ctx, &ptab, &plen, val, JS_GPN_STRING_MASK | JS_GPN_SYMBOL_MASK | JS_GPN_ENUM_ONLY);
        if (result != 0) {
            JS_FreeValue(ctx, val);
            return;
        }
        for (int i = 0; i < plen; i++) {
            JSValue propKey = JS_AtomToString(ctx, ptab[i].atom);
            printStringify(ctx, propKey);
            JS_FreeValue(ctx, propKey);
            JSValue propVal = JS_GetPropertyInternal(ctx, val, ptab[i].atom, val, 0);
            printStringify(ctx, propVal);
            JS_FreeValue(ctx, propVal);
            JS_FreeAtom(ctx, ptab[i].atom);
        }
        js_free(ctx, ptab);

        JS_FreeValue(ctx, val);
    }

    void testPointerArg(uint32_t *p) {
        uint32_t *a = NULL;
        uint32_t i = 1024;
        a = &i;
        *p = *a;
    }

    const char* _handyTypeof(JSContext* ctx, const char* code, size_t len) {
        printf("\n");
        JSValue val = JS_Eval(ctx, code, strlen(code), "<eval>", JS_EVAL_TYPE_GLOBAL);
        const char* type = QJS_HandyTypeof(ctx, &val);
        JS_FreeValue(ctx, val);
        return type;
    }

    void testHandyTypeof(JSContext* ctx) {
        {
            const char* code = "var a;a";
            printf("typeof `%s`:%s == undefined\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "var a=null;a";
            printf("typeof `%s`:%s == null\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "var a=true;a";
            printf("typeof `%s`:%s == boolean\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "new Boolean()";
            printf("typeof `%s`:%s == Boolean\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "var a=Symbol(1);a";
            printf("typeof `%s`:%s == Symbol\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "() => 0";
            printf("typeof `%s`:%s == function\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "12";
            printf("typeof `%s`:%s == int\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "12.1";
            printf("typeof `%s`:%s == float\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "Number(12.0)";
            printf("typeof `%s`:%s == int\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "new Number(12.0)";
            printf("typeof `%s`:%s == Number\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "new Promise((resolve, reject) => 0)";
            printf("typeof `%s`:%s == Promise\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "new Date()";
            printf("typeof `%s`:%s == Date\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "'1'";
            printf("typeof `%s`:%s == string\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "String(1)";
            printf("typeof `%s`:%s == string\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "new String(1)";
            printf("typeof `%s`:%s == String\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "[]";
            printf("typeof `%s`:%s == Array\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "new Array()";
            printf("typeof `%s`:%s == Array\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "var a=/./;a";
            printf("typeof `%s`:%s == RegExp\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
        {
            const char* code = "var a=new Error();a";
            printf("typeof `%s`:%s == Error\n", code, _handyTypeof(ctx, code, strlen(code)));
        }
    }

    //void test_NewArrayBuffer(JSContext *ctx) {
    //    const char* str = "Hello World!";
    //    uint8_t* buf = (uint8_t*)(&str[0]);
    //    JSValue *val = QJS_NewArrayBuffer(ctx, (uint8_t*)buf, strlen(str), NULL, nullptr, 0);
    //    size_t* psize = (size_t*)malloc(sizeof size_t);
    //    uint8_t * bf = JS_GetArrayBuffer(ctx, psize, *val);
    //    printf("%s", (char*)bf);
    //    JS_FreeValue(ctx, *val);
    //    free(psize);
    //}

    void test_NewArrayBuffer(JSContext* ctx) {
        const char* str = "Hello World!";
        uint8_t* buf = (uint8_t*)(&str[0]);
        JSValue* val = QJS_NewArrayBuffer(ctx, (uint8_t*)buf, strlen(str), NULL, nullptr, 0);
        size_t* psize = (size_t*)malloc(sizeof size_t);
        uint8_t* bf = QJS_GetArrayBuffer(ctx, psize, val);
        printf("%s", (char*)bf);
        JS_FreeValue(ctx, *val);
        free(psize);
    }

    void test_NewDate(JSContext* ctx) {
        JSValue *date = QJS_NewDate(ctx, 1622537565122);
        const char* type = QJS_HandyTypeof(ctx, date);
        printf("typeof:%s\n", type);
        JSValue strVal = JS_ToString(ctx, *date);
        const char* str = JS_ToCString(ctx, strVal);
        printf("%s\n", str);
        JS_FreeCString(ctx, str);
        JS_FreeValue(ctx, strVal);

        JSValue getYear = JS_GetPropertyStr(ctx, *date, "getYear");
        JSValue year = JS_Call(ctx, getYear, *date, 0, NULL);
        JS_FreeValue(ctx, getYear);
        int64_t yearVal = NAN;
        JS_ToInt64(ctx, &yearVal, year);
        JS_FreeValue(ctx, year);
        printf("year:%ld", yearVal);

        JS_FreeValue(ctx, *date);
    }

    uint8_t hello_module_loader(JSContext* ctx, char** buff, size_t* len, const char* module_name) {
        char* source = "export function hello(val) {return `Hello ${val}`;}";
        *buff = source;
        size_t l = strlen(source);
        *len = l;
        return 1;
    }

    void test_ModuleLoader(JSRuntime *rt, JSContext* ctx) {
        QJS_SetModuleLoaderFunc(rt, &hello_module_loader);
        const char* code = "import {hello} from \"my_module\";print(hello('world'));globalThis.result = hello('world')";
        JSValue val = JS_Eval(ctx, code, strlen(code), "<eval>", JS_EVAL_TYPE_MODULE);
        //JS_FreeValue(ctx, val);
        //const char* code2 = "hello('world')";
        //val = JS_Eval(ctx, code2, strlen(code2), "<eval>", JS_EVAL_TYPE_GLOBAL);

        if (JS_IsException(val)) {
            JSValue exception = JS_GetException(ctx);
            JS_FreeValue(ctx, val);
            const char* error = JS_ToCString(ctx, exception);
            JS_FreeValue(ctx, exception);
            printf("Eval error:\n%s", error);
            JS_FreeCString(ctx, error);
            return;
        }

        char* type = QJS_GetString(ctx, &val);
        printf("result: %s", type);
        JS_FreeValue(ctx, val);
        free(type);

        JSValue global = JS_GetGlobalObject(ctx);
        JSValue result = JS_GetPropertyStr(ctx, global, "result");
        char * res = QJS_GetString(ctx, &result);
        printf("res:%s", res);
        JS_FreeValue(ctx, global);
        JS_FreeValue(ctx, result);
    }
    
    JSValue js_print(JSContext* ctx, JSValueConst this_val, int argc, JSValueConst* argv) {
        const char * dump = QJS_Dump(ctx, &(argv[0]));
        //JS_FreeValue(ctx, this_val);
        //for (int i = 0; i < argc; i++) {
        //    JS_FreeValue(ctx, argv[i]);
        //}
        printf("%s\n", dump);
        return JS_UNDEFINED;
    }
    void setup_js_print(JSContext *ctx) {
        const char* fnName = "print";
        JSValue global = JS_GetGlobalObject(ctx);
        JS_SetPropertyStr(ctx, global, "print", JS_NewCFunction(ctx, &js_print, fnName, 1));
        JS_FreeValue(ctx, global);
    }

    JSValue js_constructor(JSContext* ctx, JSValueConst this_val, int argc, JSValueConst* argv) {
        JSValue result = JS_NewObject(ctx);
        JS_SetPropertyStr(ctx, result, "name", JS_DupValue(ctx, argv[0]));
        return result;
    }
    void test_CallConstructor(JSContext* ctx) {
        const char* fnName = "c";
        //JSValue constructor = JS_NewCFunction2(ctx, &js_constructor, fnName, 0, JS_CFUNC_constructor_or_func, 0);
        JSValue constructor = JS_NewCFunction(ctx, &js_constructor, fnName, 0);
        JS_SetConstructorBit(ctx, constructor, 1);
        JSValue* argv = (JSValue*)malloc(sizeof(JSValue));
        JSValue arg = JS_NewString(ctx, "Flutter");
        argv[0] = arg;
        JSValue result = JS_CallConstructor(ctx, constructor, 1, argv);
        printStringify(ctx, result);
        JS_FreeValue(ctx, arg);
        free(argv);
        JS_FreeValue(ctx, constructor);
        JS_FreeValue(ctx, result);
    }

  int main()
  {
      //hello_world();
      //uint32_t *n = (uint32_t *)malloc(sizeof(uint32_t));
      //testPointerArg(n);
      //printf("n1:%d", *n);
      //return 0;
      //

      JSRuntime* rt;
      JSContext* ctx;
      rt = JS_NewRuntime();
      ctx = JS_NewContext(rt);
      setup_js_print(ctx);
      
      
      test_CallConstructor(ctx);
      //test_ModuleLoader(rt, ctx);
      //test_NewDate(ctx);
      //test_NewArrayBuffer(ctx);
      //testHandyTypeof(ctx);
      //const char* str = "'12'";
      //eval(ctx, str, strlen(str));

      //test_GetOwnPropertyNameAtoms(ctx);
      //test_GetOwnPropertyNames(ctx);
      JS_FreeContext(ctx);
      JS_FreeRuntime(rt);
      return 0;
  }
}