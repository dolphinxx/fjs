import 'dart:convert';
import 'dart:io';

import 'package:fast_gbk/fast_gbk.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:fjs/vm.dart';
import '../test_server.dart';

testSimplest(Vm vm, HttpServer server) async {
  requestHandler = (request, response) async {
    if (request.requestedUri.path == '/ok') {
      response.contentLength = 3;
      response.statusCode = 200;
      response.write('OK!');
      return true;
    }
    return false;
  };
  final source = '''require('http').send('http://${server.address.address}:${server.port}/ok')''';
  print(source);
  vm.startEventLoop();
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
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
}

testUnknownEncoding(Vm vm, HttpServer server) async {
  Codec codec = GbkCodec(allowMalformed: true);
  String html = '''<!DOCTYPE html><html><head><meta charset="gbk" /></head><body><h1>世界你好！</h1></body></html>''';
  List<int> bytes = codec.encode(html);
  requestHandler = (request, response) async {
    if (request.requestedUri.path == '/ok') {
      response.headers.set('content-type', 'text/html');
      response.contentLength = bytes.length;
      response.statusCode = 200;
      response.add(bytes);
      return true;
    }
    return false;
  };
  final source = '''require('http').send('http://${server.address.address}:${server.port}/ok', {htmlPreferMetaCharset: true})''';
  print(source);
  vm.startEventLoop();
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
  expect(response, {
    'headers': {
      'x-frame-options': 'SAMEORIGIN',
      'content-type': 'text/html',
      'x-xss-protection': '1; mode=block',
      'x-content-type-options': 'nosniff',
      'content-length': '${bytes.length}'
    },
    'isRedirect': false,
    'persistentConnection': true,
    'reasonPhrase': 'OK',
    'statusCode': 200,
    'body': '$html',
    'redirects': [],
  });
}

test400(Vm vm, HttpServer server) async {
  requestHandler = (request, response) async {
    if (request.requestedUri.path == '/400') {
      response.statusCode = 400;
      response.reasonPhrase = 'Bad Request';
      return true;
    }
    return false;
  };
  final source = '''require('http').send('http://${server.address.address}:${server.port}/400')''';
  print(source);
  vm.startEventLoop();
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
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
}

test500_1(Vm vm, HttpServer server) async {
  requestHandler = (request, response) async {
    if (request.requestedUri.path == '/500') {
      response.statusCode = 500;
      response.reasonPhrase = 'Internal Server Error';
      return true;
    }
    return false;
  };
  final source = '''require('http').send('http://${server.address.address}:${server.port}/500')''';
  print(source);
  vm.startEventLoop();
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
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
}

test500_2(Vm vm, HttpServer server) async {
  requestHandler = (request, response) async {
    if (request.requestedUri.path == '/500') {
      throw 'Expected Exception';
    }
    return false;
  };
  final source = '''require('http').send('http://${server.address.address}:${server.port}/500')''';
  print(source);
  vm.startEventLoop();
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
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
}

testRedirects(Vm vm, HttpServer server) async {
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
  final source = '''require('http').send('$baseUrl/redirect')''';
  print(source);
  vm.startEventLoop();
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
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
}

testRequestFailed(Vm vm, HttpServer server) async {
  final source = '''require('http').send('http://an.unknown-host.com:${server.port}/exception')''';
  print(source);
  vm.startEventLoop();
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
  expect(response, {
    'reasonPhrase': contains('Failed host lookup: \'an.unknown-host.com\''),
    'statusCode': 0,
  });
}

testPostFormMap(Vm vm, HttpServer server) async {
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
  final source = '''
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
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
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
}

testPostFormString(Vm vm, HttpServer server) async {
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
  final source = '''
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
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
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
}

testAbort(Vm vm, HttpServer server) async {
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
  final source = '''
      const {send, AbortController} = require('http');
      const abortController = new AbortController();
      const response = send('http://${server.address.address}:${server.port}/abort', abortController);
      setTimeout(() => abortController.abort(), 2000);
      response;
      ''';
  print(source);
  vm.startEventLoop();
  final response = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
  expect(response, {
    'statusCode': 308,
    'reasonPhrase': 'Request aborted by client.',
  });
}

testCache(Vm vm, HttpServer server) async {
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
  final source = '''
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
}

testCookie(Vm vm, HttpServer server) async {
  List<List<Cookie>> cookies = [];
  int i = 0;
  requestHandler = (request, response) async {
    if (request.requestedUri.path == '/cookie') {
      cookies.add([...request.cookies]);
      if(request.cookies.where((_) => _.name == 'greeting').isEmpty) {
        response.cookies.add(Cookie('greeting', Uri.encodeComponent('Hello Flutter ${++i} times!'))..httpOnly = false);
      }
      response.contentLength = 3;
      response.statusCode = 200;
      response.write('OK!');
      return true;
    }
    return false;
  };
  final source = '''
      (async function() {
        const {send, cookieManager} = require('http');
        const url = 'http://${server.address.address}:${server.port}/cookie';
        const response1 = await send({url, headers: {'Cookie': 'id=123456'}});
        const response2 = await send({url});
        return {response1, response2, greeting: await cookieManager.getByName(url, 'greeting')}
      }())
      ''';
  vm.startEventLoop();
  final result = await vm.jsToDart(vm.evalCode(source, filename: '<test>'));
  expect(result['response1'], {
    'headers': {
      'x-frame-options': 'SAMEORIGIN',
      'content-type': 'text/plain; charset=utf-8',
      'x-xss-protection': '1; mode=block',
      'set-cookie': 'greeting=Hello%20Flutter%201%20times!',
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
    'statusCode': 200,
    'body': 'OK!',
    'redirects': [],
  });
  expect(i, 1);
  expect(cookies[0], hasLength(1));
  expect(cookies[0].first.name, 'id');
  expect(cookies[0].first.value, '123456');
  expect(cookies[1], hasLength(1));
  expect(cookies[1].first.name, 'greeting');
  expect(cookies[1].first.value, 'Hello%20Flutter%201%20times!');
  expect(result['greeting'], [
    {
      'name': 'greeting',
      'value': 'Hello%20Flutter%201%20times!',
      'domain': null,
      'path': null,
      'secure': false,
      'httpOnly': false,
      'RFC6265string': 'greeting=Hello%20Flutter%201%20times!'
    }
  ]);
}