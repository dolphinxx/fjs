import 'dart:convert';

import '../lib/src/response.dart';
import '../lib/src/cache.dart';

class CacheData {
  NativeResponse data;
  int cacheTime;

  CacheData(this.data, this.cacheTime);
}

class TestCacheProvider extends CacheProvider {
  Map<String, CacheData> _cache = {};

  @override
  NativeResponse? get(Uri uri, String requestMethod,
      Map<String, String> requestHeaders, Map clientOptions) {
    String? cacheControl =
        requestHeaders['Cache-Control'] ?? requestHeaders['cache-control'];
    if (cacheControl?.startsWith('max-age=') == true) {
      int maxAge = int.parse(cacheControl!.substring(8));

      CacheData? data = _cache[uri.toString()];
      if (data != null &&
          (maxAge == 0 ||
              data.cacheTime + maxAge <
                  DateTime.now().millisecondsSinceEpoch)) {
        NativeResponse response =
            NativeResponse.fromMap(jsonDecode(jsonEncode(data.data)));
        response.statusCode = 304;
        return response;
      }
    }
    return null;
  }

  @override
  void flush() {
    _cache.clear();
  }

  @override
  void put(Uri uri, String requestMethod, Map<String, String> requestHeaders,
      Map clientOptions, NativeResponse response) {
    String? cacheControl =
        requestHeaders['Cache-Control'] ?? requestHeaders['cache-control'];
    if (cacheControl?.startsWith('max-age=') == true) {
      _cache[uri.toString()] =
          CacheData(response, DateTime.now().millisecondsSinceEpoch);
    }
  }
}
