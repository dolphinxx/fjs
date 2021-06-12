import 'dart:io';
import 'dart:async';

typedef RequestHandler = Future<bool> Function(HttpRequest request, HttpResponse response);

RequestHandler? requestHandler;

Future<HttpServer> serve() async {
  HttpServer server = await HttpServer.bind(
    '127.0.0.1',
    0,
  );
  print('TestServer listening on ${server.address.address}:${server.port}');
  server.listen((HttpRequest request) async {
    print('> ${request.method.toUpperCase()} ${request.uri} ${request.protocolVersion}');
    request.headers.forEach((name, values) {
      print('> $name: ${values.join(',')}');
    });
    HttpResponse response = request.response;
    try{
      if(requestHandler == null || !(await requestHandler!(request, response))) {
        response.statusCode = 404;
        response.reasonPhrase = 'No handler.';
      }
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