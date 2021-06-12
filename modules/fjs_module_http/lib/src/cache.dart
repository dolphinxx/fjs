
import 'response.dart';

abstract class CacheProvider {
  NativeResponse? get(Uri uri, String requestMethod, Map<String, String> requestHeaders, Map clientOptions);

  void put(Uri uri, String requestMethod, Map<String, String> requestHeaders, Map clientOptions, NativeResponse response);

  void flush();
}