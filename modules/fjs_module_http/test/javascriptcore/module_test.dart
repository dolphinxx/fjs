import 'dart:convert';
import 'dart:io';

import 'package:fjs/javascriptcore/vm.dart';
import 'package:fjs/vm.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/src/http.dart';
import '../test_cache_provider.dart';
import '../test_server.dart';

void main() {
  group('default http_client', () {
    late Vm vm;
    late HttpServer server;
    setUp(() async {
      vm = JavaScriptCoreVm();
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
      requestHandler = (request, response) async {
        if (request.requestedUri.path == '/ok') {
          response.contentLength = 3;
          response.statusCode = 200;
          response.write('OK!');
          return true;
        }
        return false;
      };
      final source =
      '''require('http').send('http://${server.address.address}:${server.port}/ok')''';
      print(source);
      vm.startEventLoop();
      final response =
      await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
      expect(response, {
        'headers': {
          'x-frame-options': 'SAMEORIGIN',
          'content-type': 'text/plain; charset=utf-8',
          'x-xss-protection': '1; mode=block',
          'x-content-type-options': 'nosniff',
          'content-length': '3'
        },
        'isRedirect': false,
        'persistentConnection': true,
        'reasonPhrase': 'OK',
        'statusCode': 200,
        'body': 'OK!',
        'redirects': [],
      });
    }, timeout: Timeout(Duration(seconds: 100)));
    test('400', () async {
      requestHandler = (request, response) async {
        if (request.requestedUri.path == '/400') {
          response.statusCode = 400;
          response.reasonPhrase = 'Bad Request';
          return true;
        }
        return false;
      };
      final source =
      '''require('http').send('http://${server.address.address}:${server.port}/400')''';
      print(source);
      vm.startEventLoop();
      final response =
      await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
      expect(response, {
        'headers': {
          'x-frame-options': 'SAMEORIGIN',
          'content-type': 'text/plain; charset=utf-8',
          'x-xss-protection': '1; mode=block',
          'x-content-type-options': 'nosniff',
          'content-length': '0'
        },
        'isRedirect': false,
        'persistentConnection': true,
        'reasonPhrase': 'Bad Request',
        'statusCode': 400,
        'body': '',
        'redirects': [],
      });
    }, timeout: Timeout(Duration(seconds: 100)));
    test('500-1', () async {
      requestHandler = (request, response) async {
        if (request.requestedUri.path == '/500') {
          response.statusCode = 500;
          response.reasonPhrase = 'Internal Server Error';
          return true;
        }
        return false;
      };
      final source =
      '''require('http').send('http://${server.address.address}:${server.port}/500')''';
      print(source);
      vm.startEventLoop();
      final response =
      await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
      expect(response, {
        'headers': {
          'x-frame-options': 'SAMEORIGIN',
          'content-type': 'text/plain; charset=utf-8',
          'x-xss-protection': '1; mode=block',
          'x-content-type-options': 'nosniff',
          'content-length': '0'
        },
        'isRedirect': false,
        'persistentConnection': true,
        'reasonPhrase': 'Internal Server Error',
        'statusCode': 500,
        'body': '',
        'redirects': [],
      });
    }, timeout: Timeout(Duration(seconds: 100)));
    test('500-2', () async {
      requestHandler = (request, response) async {
        if (request.requestedUri.path == '/500') {
          throw 'Expected Exception';
        }
        return false;
      };
      final source =
      '''require('http').send('http://${server.address.address}:${server.port}/500')''';
      print(source);
      vm.startEventLoop();
      final response =
      await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
      expect(response, {
        'headers': {
          'x-frame-options': 'SAMEORIGIN',
          'content-type': 'text/plain; charset=utf-8',
          'x-xss-protection': '1; mode=block',
          'x-content-type-options': 'nosniff',
          'content-length': '0'
        },
        'isRedirect': false,
        'persistentConnection': true,
        'reasonPhrase': 'Expected Exception',
        'statusCode': 500,
        'body': '',
        'redirects': [],
      });
    }, timeout: Timeout(Duration(seconds: 100)));
    test('redirects', () async {
      String baseUrl = 'http://${server.address.address}:${server.port}';
      requestHandler = (request, response) async {
        if (request.requestedUri.path == '/redirect') {
          response.statusCode = 301;
          response.headers.set('location', '/redirect2');
          return true;
        }
        if (request.requestedUri.path == '/redirect2') {
          response.headers.set('location', '$baseUrl/ok');
          response.statusCode = 302;
          return true;
        }
        if (request.requestedUri.path == '/ok') {
          response.contentLength = 3;
          response.statusCode = 200;
          response.write('OK!');
          return true;
        }
        return false;
      };
      final source =
      '''require('http').send('$baseUrl/redirect')''';
      print(source);
      vm.startEventLoop();
      final response =
      await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
      expect(response, {
        'headers': {
          'x-frame-options': 'SAMEORIGIN',
          'content-type': 'text/plain; charset=utf-8',
          'x-xss-protection': '1; mode=block',
          'x-content-type-options': 'nosniff',
          'content-length': '3'
        },
        'isRedirect': false,
        'persistentConnection': true,
        'reasonPhrase': 'OK',
        'statusCode': 200,
        'body': 'OK!',
        'redirects': [
          {
            'method': 'GET',
            'location': '$baseUrl/redirect2',
            'statusCode': 301,
          },
          {
            'method': 'GET',
            'location': '$baseUrl/ok',
            'statusCode': 302,
          }
        ],
      });
    }, timeout: Timeout(Duration(seconds: 100)));
    test('request failed', () async {
      final source =
      '''require('http').send('http://an.unknown-host.com:${server.port}/exception')''';
      print(source);
      vm.startEventLoop();
      final response =
      await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
      expect(response, {
        'reasonPhrase': contains('Failed host lookup: \'an.unknown-host.com\''),
        'statusCode': 0,
      });
    }, timeout: Timeout(Duration(seconds: 100)));
    test('post form map', () async {
      Map<String, String>? requestForm;
      requestHandler = (request, response) async {
        if (request.requestedUri.path == '/post_form') {
          String query = await utf8.decodeStream(request);
          requestForm = Uri.splitQueryString(query, encoding: utf8);
          response.contentLength = 3;
          response.statusCode = 200;
          response.write('OK!');
          return true;
        }
        return false;
      };
      final source =
      '''
      require('http').send({
        url: 'http://${server.address.address}:${server.port}/post_form',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: {greeting: 'Hi!', "year": 2021, 'happy': true}
      })
      ''';
      print(source);
      vm.startEventLoop();
      final response =
      await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
      expect(requestForm, {
        'greeting': 'Hi!',
        'year': '2021',
        'happy': 'true',
      });
      expect(response, {
        'headers': {
          'x-frame-options': 'SAMEORIGIN',
          'content-type': 'text/plain; charset=utf-8',
          'x-xss-protection': '1; mode=block',
          'x-content-type-options': 'nosniff',
          'content-length': '3'
        },
        'isRedirect': false,
        'persistentConnection': true,
        'reasonPhrase': 'OK',
        'statusCode': 200,
        'body': 'OK!',
        'redirects': [],
      });
    }, timeout: Timeout(Duration(seconds: 100)));
    test('post form string', () async {
      Map<String, String>? requestForm;
      requestHandler = (request, response) async {
        if (request.requestedUri.path == '/post_form') {
          String query = await utf8.decodeStream(request);
          requestForm = Uri.splitQueryString(query, encoding: utf8);
          response.contentLength = 3;
          response.statusCode = 200;
          response.write('OK!');
          return true;
        }
        return false;
      };
      final source =
      '''
      require('http').send({
        url: 'http://${server.address.address}:${server.port}/post_form',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: `greeting=Hi!&year=2021&happy=true`
      })
      ''';
      print(source);
      vm.startEventLoop();
      final response =
      await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
      expect(requestForm, {
        'greeting': 'Hi!',
        'year': '2021',
        'happy': 'true',
      });
      expect(response, {
        'headers': {
          'x-frame-options': 'SAMEORIGIN',
          'content-type': 'text/plain; charset=utf-8',
          'x-xss-protection': '1; mode=block',
          'x-content-type-options': 'nosniff',
          'content-length': '3'
        },
        'isRedirect': false,
        'persistentConnection': true,
        'reasonPhrase': 'OK',
        'statusCode': 200,
        'body': 'OK!',
        'redirects': [],
      });
    }, timeout: Timeout(Duration(seconds: 100)));
    test('abort', () async {
      requestHandler = (request, response) async {
        if (request.requestedUri.path == '/abort') {
          // wait for abort call
          await Future.delayed(Duration(seconds: 10));
          response.contentLength = 3;
          response.statusCode = 200;
          response.write('OK!');
          return true;
        }
        return false;
      };
      final source =
      '''
      const {send, AbortController} = require('http');
      const abortController = new AbortController();
      const response = send('http://${server.address.address}:${server.port}/abort', abortController);
      setTimeout(() => abortController.abort(), 2000);
      response;
      ''';
      print(source);
      vm.startEventLoop();
      final response =
      await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
      expect(response, {
        'statusCode': 308,
        'reasonPhrase': 'Request aborted by client.',
      });
    }, timeout: Timeout(Duration(seconds: 100)));
  });
  group('cache http_client', () {
    test('cache', () async {
      HttpServer server = await serve();
      Vm vm = JavaScriptCoreVm();
      vm.registerModule(FlutterJSHttpModule(cacheProvider: TestCacheProvider()));
      try{
        requestHandler = (request, response) async {
          if (request.requestedUri.path == '/cache') {
            // simulate time-consuming operation.
            await Future.delayed(Duration(seconds: 10));
            response.contentLength = 3;
            response.statusCode = 200;
            response.write('OK!');
            return true;
          }
          return false;
        };
        final source =
        '''
      (async function() {
        const {send} = require('http');
        const begin = new Date().getTime();
        const response1 = await send({url: 'http://${server.address.address}:${server.port}/cache', headers: {'Cache-Control': 'max-age=0'}});
        const response2 = await send({url: 'http://${server.address.address}:${server.port}/cache', headers: {'Cache-Control': 'max-age=0'}});
        const coast = new Date().getTime() - begin;
        return {response1, response2, coast}
      }())
      ''';
        print(source);
        vm.startEventLoop();
        final result = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
        expect(result['response1'], {
          'headers': {
            'x-frame-options': 'SAMEORIGIN',
            'content-type': 'text/plain; charset=utf-8',
            'x-xss-protection': '1; mode=block',
            'x-content-type-options': 'nosniff',
            'content-length': '3'
          },
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'OK',
          'statusCode': 200,
          'body': 'OK!',
          'redirects': [],
        });
        expect(result['response2'], {
          'headers': {
            'x-frame-options': 'SAMEORIGIN',
            'content-type': 'text/plain; charset=utf-8',
            'x-xss-protection': '1; mode=block',
            'x-content-type-options': 'nosniff',
            'content-length': '3'
          },
          'isRedirect': false,
          'persistentConnection': true,
          'reasonPhrase': 'OK',
          'statusCode': 304,
          'body': 'OK!',
          'redirects': [],
        });
        expect(result['coast'], lessThan(15000));
      } catch(err, stackTrace) {
        print('$err\n$stackTrace');
      }
      vm.dispose();
      server.close();
    }, timeout: Timeout(Duration(seconds: 100)));
  });
}
