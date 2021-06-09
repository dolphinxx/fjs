cmake_minimum_required(VERSION 3.7)
project(libquickjs VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -DDEBUGGER_SERVER_PORT=${DEBUGGER_SERVER_PORT}")
#set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DQUICKJS")

set(QUICK_JS_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build)
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

#set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/libs)

set_target_properties(libquickjs PROPERTIES PREFIX "")

# when run without gralde
if(STRIP)
    set_target_properties(libquickjs
        PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY
        "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${ANDROID_ABI}")

    add_custom_command(TARGET libquickjs POST_BUILD
        COMMAND ${CMAKE_STRIP} -g -S -d --strip-unneeded --strip-debug
        "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${ANDROID_ABI}/libquickjs.so"
        COMMENT "Strip debug symbols done on final binary.")
endif()

target_compile_options(libquickjs PRIVATE "-DCONFIG_VERSION=\"${QUICKJS_VERSION}\"")
target_compile_options(libquickjs PRIVATE "-DDUMP_LEAKS")

find_library(log-lib log)
target_link_libraries(libquickjs ${log-lib})