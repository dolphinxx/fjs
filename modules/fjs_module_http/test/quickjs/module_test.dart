import 'dart:io';

import 'package:fjs/quickjs/vm.dart';
import 'package:fjs/vm.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/cookie.dart';
import '../../lib/src/http.dart';
import '../test_cache_provider.dart';
import '../test_server.dart';
import '../tests/module_tests.dart';

void main() {
  group('default http_client', () {
    late Vm vm;
    late HttpServer server;
    setUp(() async {
      vm = QuickJSVm();
      vm.registerModule(FlutterJSHttpModule());
      server = await serve();
    });
    tearDown(() {
      try {
        vm.dispose();
      } catch (_) {}
      server.close();
    });
    test('simplest', () async {
      await testSimplest(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
    test('400', () async {
      await test400(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
    test('500-1', () async {
      await test500_1(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
    test('500-2', () async {
      await test500_2(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
    test('redirects', () async {
      await testRedirects(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
    test('request failed', () async {
      await testRequestFailed(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
    test('post form map', () async {
      await testPostFormMap(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
    test('post form string', () async {
      await testPostFormString(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
    test('abort', () async {
      await testAbort(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
  });
  group('cache http_client', () {
    late Vm vm;
    late HttpServer server;
    setUp(() async {
      vm = QuickJSVm();
      vm.registerModule(FlutterJSHttpModule(cacheProvider: TestCacheProvider()));
      server = await serve();
    });
    tearDown(() {
      try {
        vm.dispose();
      } catch (_) {}
      server.close();
    });
    test('cache', () async {
      await testCache(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
  });
  group('cookie http_client', () {
    late Vm vm;
    late HttpServer server;
    setUp(() async {
      vm = QuickJSVm();
      vm.registerModule(FlutterJSHttpModule(cookieManager: InMemoryCookieManager()));
      server = await serve();
    });
    tearDown(() {
      try {
        vm.dispose();
      } catch (_) {}
      server.close();
    });
    test('cookie', () async {
      await testCookie(vm, server);
    }, timeout: Timeout(Duration(seconds: 100)));
  });
}
