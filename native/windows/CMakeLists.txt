cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
project(quickjs VERSION 1.0.0 LANGUAGES C CXX)
add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
# set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
set(PLUGIN_NAME "libquickjs")
set(QUICK_JS_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${QUICK_JS_LIB_DIR})
file (STRINGS "${QUICK_JS_LIB_DIR}/VERSION" QUICKJS_VERSION)
add_library(libquickjs
             SHARED
             ${QUICK_JS_LIB_DIR}/cutils.c
             ${QUICK_JS_LIB_DIR}/libregexp.c
             ${QUICK_JS_LIB_DIR}/libunicode.c
             ${QUICK_JS_LIB_DIR}/quickjs.c
            #  ${CMAKE_CURRENT_SOURCE_DIR}/src/libbf.c
             ${QUICK_JS_LIB_DIR}/interface.cpp
             ${QUICK_JS_LIB_DIR}/quickjs.def
    )

# set_target_properties(${PLUGIN_NAME} PROPERTIES
#   CXX_VISIBILITY_PRESET hidden)

# target_compile_features(libquickjs PRIVATE c_std_17)
target_compile_options(libquickjs PRIVATE "-DCONFIG_VERSION=\"${QUICKJS_VERSION}\"")
target_compile_options(libquickjs PRIVATE "-DDUMP_LEAKS")
# target_compile_options(libquickjs PRIVATE "-std=gnu++14")