import 'dart:convert';
import 'dart:io';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:fjs_module_http/src/request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getCharsetFromHTML', () {
    test('meta charset nomal', () {
      final html = '''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>第七十九章 让柳萱跪下求自己_赘婿当道_什么小说</title>
    <meta charset="utf-8">
    <meta http-equiv="Cache-Control" content="no-siteapp" />
    <meta http-equiv="Cache-Control" content="no-transform" />
    <meta name="keywords" content="赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读。" />
    <meta name="description" content="什么小说免费为大家提供赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读,如果你想第一时间观看下一章节,请留意以及收藏什么小说,方便你下次阅读赘婿当道最新章节。" />
    <meta http-equiv="mobile-agent" content="format=html5; url=https://m.sm.la/files/article/90/90465/" />
    <meta http-equiv="mobile-agent" content="format=xhtml; url=https://m.sm.la/files/article/90/90465/" />
    <link rel="alternate" media="only screen and (max-width:640px)" href="https://m.sm.la/files/article/90/90465/" />  
	<link rel="dns-prefetch" href="//www.sm.la"/>
	<link rel="dns-prefetch" href="//m.sm.la"/>
	<link rel="dns-prefetch" href="//sm.cdn.bcebos.com"/>
	<script data-ad-client="ca-pub-1074058122108724" async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/m.js"></script>
    <script type="text/javascript" src="//cdn.staticfile.org/jquery/1.10.0/jquery.min.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/common.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/reader.js"></script>
    <link rel="stylesheet" href="//sm.cdn.bcebos.com/style/style.css" />
</head>
<body>
<div id="wrapper">
  <script>login();</script>
  <div class="header">
    <div class="header_logo">
      <a href="https://www.sm.la/">什么小说</a>
    </div>
    <script>panel();</script>
  </div>
</body>
</html>
      ''';
      final actual = getCharsetFromHTML(html);
      expect(actual, 'utf-8');
    });
    test('meta charset wrong codec', () {
      final html = Utf8Codec(allowMalformed: true).decode(GbkCodec().encode('''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>第七十九章 让柳萱跪下求自己_赘婿当道_什么小说</title>
    <meta charset="utf-8">
    <meta http-equiv="Cache-Control" content="no-siteapp" />
    <meta http-equiv="Cache-Control" content="no-transform" />
    <meta name="keywords" content="赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读。" />
    <meta name="description" content="什么小说免费为大家提供赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读,如果你想第一时间观看下一章节,请留意以及收藏什么小说,方便你下次阅读赘婿当道最新章节。" />
    <meta http-equiv="mobile-agent" content="format=html5; url=https://m.sm.la/files/article/90/90465/" />
    <meta http-equiv="mobile-agent" content="format=xhtml; url=https://m.sm.la/files/article/90/90465/" />
    <link rel="alternate" media="only screen and (max-width:640px)" href="https://m.sm.la/files/article/90/90465/" />  
	<link rel="dns-prefetch" href="//www.sm.la"/>
	<link rel="dns-prefetch" href="//m.sm.la"/>
	<link rel="dns-prefetch" href="//sm.cdn.bcebos.com"/>
	<script data-ad-client="ca-pub-1074058122108724" async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/m.js"></script>
    <script type="text/javascript" src="//cdn.staticfile.org/jquery/1.10.0/jquery.min.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/common.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/reader.js"></script>
    <link rel="stylesheet" href="//sm.cdn.bcebos.com/style/style.css" />
</head>
<body>
<div id="wrapper">
  <script>login();</script>
  <div class="header">
    <div class="header_logo">
      <a href="https://www.sm.la/">什么小说</a>
    </div>
    <script>panel();</script>
  </div>
</body>
</html>
      '''));
      final actual = getCharsetFromHTML(html);
      expect(actual, 'utf-8');
    });
    test('meta content charset normal', () {
      final html = '''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>第七十九章 让柳萱跪下求自己_赘婿当道_什么小说</title>
    <meta http-equiv="Content-Type" content="text/html; charset=gbk" />
    <meta http-equiv="Cache-Control" content="no-siteapp" />
    <meta http-equiv="Cache-Control" content="no-transform" />
    <meta name="keywords" content="赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读。" />
    <meta name="description" content="什么小说免费为大家提供赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读,如果你想第一时间观看下一章节,请留意以及收藏什么小说,方便你下次阅读赘婿当道最新章节。" />
    <meta http-equiv="mobile-agent" content="format=html5; url=https://m.sm.la/files/article/90/90465/" />
    <meta http-equiv="mobile-agent" content="format=xhtml; url=https://m.sm.la/files/article/90/90465/" />
    <link rel="alternate" media="only screen and (max-width:640px)" href="https://m.sm.la/files/article/90/90465/" />  
	<link rel="dns-prefetch" href="//www.sm.la"/>
	<link rel="dns-prefetch" href="//m.sm.la"/>
	<link rel="dns-prefetch" href="//sm.cdn.bcebos.com"/>
	<script data-ad-client="ca-pub-1074058122108724" async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/m.js"></script>
    <script type="text/javascript" src="//cdn.staticfile.org/jquery/1.10.0/jquery.min.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/common.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/reader.js"></script>
    <link rel="stylesheet" href="//sm.cdn.bcebos.com/style/style.css" />
</head>
<body>
<div id="wrapper">
  <script>login();</script>
  <div class="header">
    <div class="header_logo">
      <a href="https://www.sm.la/">什么小说</a>
    </div>
    <script>panel();</script>
  </div>
</body>
</html>
      ''';
      final actual = getCharsetFromHTML(html);
      expect(actual, 'gbk');
    });
    test('meta content charset wrong codec', () {
      final html = Utf8Codec(allowMalformed: true).decode(GbkCodec().encode('''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>第七十九章 让柳萱跪下求自己_赘婿当道_什么小说</title>
    <meta http-equiv="Content-Type" content="text/html; charset=gbk" />
    <meta http-equiv="Cache-Control" content="no-siteapp" />
    <meta http-equiv="Cache-Control" content="no-transform" />
    <meta name="keywords" content="赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读。" />
    <meta name="description" content="什么小说免费为大家提供赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读,如果你想第一时间观看下一章节,请留意以及收藏什么小说,方便你下次阅读赘婿当道最新章节。" />
    <meta http-equiv="mobile-agent" content="format=html5; url=https://m.sm.la/files/article/90/90465/" />
    <meta http-equiv="mobile-agent" content="format=xhtml; url=https://m.sm.la/files/article/90/90465/" />
    <link rel="alternate" media="only screen and (max-width:640px)" href="https://m.sm.la/files/article/90/90465/" />  
	<link rel="dns-prefetch" href="//www.sm.la"/>
	<link rel="dns-prefetch" href="//m.sm.la"/>
	<link rel="dns-prefetch" href="//sm.cdn.bcebos.com"/>
	<script data-ad-client="ca-pub-1074058122108724" async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/m.js"></script>
    <script type="text/javascript" src="//cdn.staticfile.org/jquery/1.10.0/jquery.min.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/common.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/reader.js"></script>
    <link rel="stylesheet" href="//sm.cdn.bcebos.com/style/style.css" />
</head>
<body>
<div id="wrapper">
  <script>login();</script>
  <div class="header">
    <div class="header_logo">
      <a href="https://www.sm.la/">什么小说</a>
    </div>
    <script>panel();</script>
  </div>
</body>
</html>
      '''));
      final actual = getCharsetFromHTML(html);
      expect(actual, 'gbk');
    });
    test('missing charset', () {
      final html = '''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>第七十九章 让柳萱跪下求自己_赘婿当道_什么小说</title>
    <meta http-equiv="Content-Type" content="text/html" />
    <meta http-equiv="Cache-Control" content="no-siteapp" />
    <meta http-equiv="Cache-Control" content="no-transform" />
    <meta name="keywords" content="赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读。" />
    <meta name="description" content="什么小说免费为大家提供赘婿当道正文  第七十九章 让柳萱跪下求自己全文阅读,如果你想第一时间观看下一章节,请留意以及收藏什么小说,方便你下次阅读赘婿当道最新章节。" />
    <meta http-equiv="mobile-agent" content="format=html5; url=https://m.sm.la/files/article/90/90465/" />
    <meta http-equiv="mobile-agent" content="format=xhtml; url=https://m.sm.la/files/article/90/90465/" />
    <link rel="alternate" media="only screen and (max-width:640px)" href="https://m.sm.la/files/article/90/90465/" />  
	<link rel="dns-prefetch" href="//www.sm.la"/>
	<link rel="dns-prefetch" href="//m.sm.la"/>
	<link rel="dns-prefetch" href="//sm.cdn.bcebos.com"/>
	<script data-ad-client="ca-pub-1074058122108724" async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/m.js"></script>
    <script type="text/javascript" src="//cdn.staticfile.org/jquery/1.10.0/jquery.min.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/common.js"></script>
    <script type="text/javascript" src="//sm.cdn.bcebos.com/style/reader.js"></script>
    <link rel="stylesheet" href="//sm.cdn.bcebos.com/style/style.css" />
</head>
<body>
<div id="wrapper">
  <script>login();</script>
  <div class="header">
    <div class="header_logo">
      <a href="https://www.sm.la/">什么小说</a>
    </div>
    <script>panel();</script>
  </div>
</body>
</html>
      ''';
      final actual = getCharsetFromHTML(html);
      expect(actual, isNull);
    });
  });
  group('isBrotliEncoding', () {
    test('empty headers', () {
      final actual = isBrotliEncoding(_MockHttpHeaders({}));
      expect(actual, isFalse);
    });
    test('empty value', () {
      final actual = isBrotliEncoding(_MockHttpHeaders({
        'content-encoding': [],
      }));
      expect(actual, isFalse);
    });
    test('missing', () {
      final actual = isBrotliEncoding(_MockHttpHeaders({
        'content-type': ['text/html; charset=gb2312'],
      }));
      expect(actual, isFalse);
    });
    test('gzip', () {
      final actual = isBrotliEncoding(_MockHttpHeaders({
        'content-encoding': ['gzip'],
      }));
      expect(actual, isFalse);
    });
    test('lowercase', () {
      final actual = isBrotliEncoding(_MockHttpHeaders({
        'content-encoding': ['br'],
      }));
      expect(actual, isTrue);
    });
    test('uppercase', () {
      final actual = isBrotliEncoding(_MockHttpHeaders({
        'content-encoding': ['BR'],
      }));
      expect(actual, isTrue);
    });
    test('send', () async {
      final response = await send(
          HttpClient(),
          {
            'url': 'https://m.23hh.com/book/6/6727/',
            'headers': {
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
              'Accept-Encoding': 'gzip, deflate, br',
              'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
              'Cache-Control': 'max-age=0',
              'Connection': 'keep-alive',
              'Upgrade-Insecure-Requests': '1',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36'
            },
          },
          {},
          encodingMap: {
            'gb2312': const GbkCodec(allowMalformed: true),
          },
          verbose: true);
      print(response.body);
      expect(response.body, contains('<html'));
    });
  });
}

class _MockHttpHeaders extends HttpHeaders {
  Map<String, List<String>> _data;

  _MockHttpHeaders(this._data);

  @override
  List<String>? operator [](String name) {
    return _data[name];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    throw UnimplementedError();
  }

  @override
  void clear() {
    throw UnimplementedError();
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    throw UnimplementedError();
  }

  @override
  void noFolding(String name) {
    throw UnimplementedError();
  }

  @override
  void remove(String name, Object value) {
    throw UnimplementedError();
  }

  @override
  void removeAll(String name) {
    throw UnimplementedError();
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    throw UnimplementedError();
  }

  @override
  String? value(String name) {
    throw UnimplementedError();
  }

}