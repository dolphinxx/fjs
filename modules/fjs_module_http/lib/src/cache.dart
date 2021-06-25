
import 'dart:async';

import 'response.dart';

abstract class CacheProvider {
  FutureOr<NativeResponse?> get(Uri uri, String requestMethod, Map<String, String> requestHeaders, Map clientOptions);

  FutureOr<void> put(Uri uri, String requestMethod, Map<String, String> requestHeaders, Map clientOptions, NativeResponse response);

  FutureOr<void> flush();
}