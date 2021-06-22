import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../lib/src/cookie.dart';

void main() {
  group('cookie_manager', () {
    test('get/set', () {
      InMemoryCookieManager manager = InMemoryCookieManager();
      manager.set(Uri.parse('http://www.google.com'), Cookie('a', '123'));
      manager.set(Uri.parse('https://www.google.com'), Cookie('a', '123'));
      manager.set(Uri.parse('http://www.google.com'), Cookie('a', '123')..path='/a');
      manager.set(Uri.parse('http://www.google.com'), Cookie('a', '123')..domain='.google.com');
      manager.set(Uri.parse('http://www.google.com'), Cookie('a', '123')..domain='www.google.com');
      manager.set(Uri.parse('http://ww1.google.com'), Cookie('a', '123')..domain='ww1.google.com');
      expect(manager.hostCookies, hasLength(1));
      expect(manager.domainCookies, hasLength(3));

      manager.delete(Uri.parse('http://www.google.com'));
      expect(manager.hostCookies['www.google.com'], hasLength(1));
      expect(manager.domainCookies['.google.com'], isEmpty);
      expect(manager.domainCookies['www.google.com'], isEmpty);
      expect(manager.domainCookies['ww1.google.com'], hasLength(1));
    });
    test('serialize/deserialize', () {
      InMemoryCookieManager manager = InMemoryCookieManager();
      manager.set(Uri.parse('http://www.google.com'), Cookie('a', '123'));
      manager.set(Uri.parse('https://www.google.com'), Cookie('b', '123'));
      manager.set(Uri.parse('http://www.google.com'), Cookie('c', '123')..path='/a');
      manager.set(Uri.parse('http://www.google.com'), Cookie('d', '123')..domain='.google.com');
      manager.set(Uri.parse('https://www.google.com'), Cookie('e', '123')..domain='www.google.com'..secure=true);
      manager.set(Uri.parse('http://ww1.google.com'), Cookie('f', '123')..domain='ww1.google.com'..httpOnly=true);
      String json = manager.stringify();
      print(json);
      InMemoryCookieManager manager2 = InMemoryCookieManager.restore(json);
      expect(manager.hostCookies, equals(manager2.hostCookies));
      expect(manager.domainCookies, equals(manager2.domainCookies));
    });
    test('expires', () async {
      InMemoryCookieManager manager = InMemoryCookieManager();
      final uri = Uri.parse('https://www.google.com');
      manager.set(uri, Cookie('a', '123')..expires = DateTime.now().add(Duration(seconds: 2)));
      expect(manager.get(uri), hasLength(1));
      await Future.delayed(Duration(seconds: 4));
      expect(manager.get(uri), hasLength(0));
    });
  });
}