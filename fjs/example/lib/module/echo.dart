import 'dart:convert';
import 'dart:io';
import 'dart:async';

Future<HttpServer> serve() async {
  HttpServer server = await HttpServer.bind(
    '127.0.0.1',
    0,
  );
  server.listen((HttpRequest request) async {
    String body = await utf8.decodeStream(request);
    HttpResponse response = request.response;
    try{
      response.statusCode = 200;
      response.writeln('< ${request.method.toUpperCase()} ${request.uri} ${request.protocolVersion}');
      if(request.persistentConnection) {
        response.writeln('< persistent connection');
      }
      request.headers.forEach((name, values) {
        print('< $name: ${values.join(',')}');
      });

      response.writeln();
      response.writeln(body);
      response.writeln();
      await response.flush();
    } catch (e, s) {
      print('$e\n$s');
      response.statusCode = 500;
      response.reasonPhrase = e.toString();
    } finally {
      try {
        await response.close();
      } catch (e, s) {
        print('Exception when close response.\n$e\n$s');
      }
      print('< ${response.statusCode}');
      response.headers.forEach((name, values) {
        print('< $name: ${values.join(',')}');
      });
    }
  });
  return server;
}