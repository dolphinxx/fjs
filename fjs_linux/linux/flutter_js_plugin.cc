#include "include/fjs_linux/fjs_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <glib.h>

#include <cstring>

#define FJS_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), fjs_plugin_get_type(), \
                              FlutterJsPlugin))

struct _FlutterJsPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterJsPlugin, fjs_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void fjs_plugin_handle_method_call(
    FlutterJsPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    struct utsname uname_data = {};
    uname(&uname_data);
    g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
    g_autoptr(FlValue) result = fl_value_new_string(version);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void fjs_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(fjs_plugin_parent_class)->dispose(object);
}

static void fjs_plugin_class_init(FlutterJsPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fjs_plugin_dispose;
}

static void fjs_plugin_init(FlutterJsPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlutterJsPlugin* plugin = FJS_PLUGIN(user_data);
  fjs_plugin_handle_method_call(plugin, method_call);
}

// Gets the directory the current executable is in, borrowed from:
// https://github.com/flutter/engine/blob/master/shell/platform/linux/fl_dart_project.cc#L27
//
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in https://github.com/flutter/engine/blob/master/LICENSE.
static gchar* get_executable_dir() {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", &error);
  if (exe_path == nullptr) {
    g_critical("Failed to determine location of executable: %s",
               error->message);
    return nullptr;
  }

  return g_path_get_dirname(exe_path);
}

void fjs_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterJsPlugin* plugin = FJS_PLUGIN(
      g_object_new(fjs_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "fjs",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
  // get the current executable dir
  g_autofree gchar* executable_dir = get_executable_dir();
  // resolve the shared library path 
  g_autofree gchar* lib_path = g_build_filename(executable_dir, "lib", "libquickjs.so", nullptr);
  // share the libpath to Dart through an environment variable
  setenv("LIBQUICKJSC_PATH", lib_path, 0);
}

