cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
project(test VERSION 1.0.0 LANGUAGES C CXX)
add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
set(SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../build)
file (STRINGS "${SOURCE_DIR}/VERSION" QUICKJS_VERSION)
set(QJS_SOURCE
	${SOURCE_DIR}/quickjs.c
	${SOURCE_DIR}/cutils.c
    ${SOURCE_DIR}/libregexp.c
    ${SOURCE_DIR}/libunicode.c
 #  ${QJS}/libbf.c
 #  ${QJS}/interface.cpp
	)
add_executable(test test.cpp ${QJS_SOURCE})
target_include_directories(test PRIVATE ${SOURCE_DIR})
target_compile_options(test PRIVATE "-DCONFIG_VERSION=\"${QUICKJS_VERSION}\"")
target_compile_options(test PRIVATE "-DDUMP_LEAKS")