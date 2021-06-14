import 'dart:convert';
import 'dart:io';
import 'package:fjs/error.dart';
import 'package:fjs/vm.dart';
import 'package:fjs/types.dart';
import 'package:fjs/module.dart';

import 'request.dart';
import 'cache.dart';
import 'abort_controller.dart';

class FlutterJSHttpModule implements FlutterJSModule{
  final Map<String, Encoding> _encodingMap = {};
  final Map<int, AbortController> _abortControllers = {};
  late final HttpClient client;
  CacheProvider? cacheProvider;
  RequestInterceptor? requestInterceptor;
  ResponseInterceptor? responseInterceptor;
  bool quiet;
  int _requestNextId = 1;

  /// Provider a [httpClientProvider] to have customization of `HttpClient` instance creation.
  ///
  /// If your desired charsets are not appear in `Encoding`, provider them through [encodingMap].
  ///
  /// Only fatal messages are printed if [quiet] is true.
  FlutterJSHttpModule({
    HttpClient httpClientProvider()?,
    Map<String, Encoding>? encodingMap,
    bool? quiet,
    this.cacheProvider,
    this.requestInterceptor,
    this.responseInterceptor,
  }):quiet = quiet??true {
    client = (httpClientProvider??() => HttpClient())();
    if(encodingMap != null) {
      _encodingMap.addAll(encodingMap);
    }
  }

  final String name = 'http';

  JSValuePointer resolve(Vm vm, path) {
    return vm.dartToJS({
      'send': vm.newFunction('send', (args, {thisObj}) {
        dynamic args0 = vm.jsToDart(args[0]);
        final httpOptions = args0 is String ? {'url': args0} : args0;
        JSValuePointer? abortControllerPtr;
        Map clientOptions;
        if(args.length == 1) {
          clientOptions = {};
        } else if(args.length == 2 && vm.hasProperty(args[1], 'abort')) {
          abortControllerPtr = args[1];
          clientOptions = {};
        } else {
          clientOptions = vm.jsToDart(args[1])??{};
        }
        final requestId = _requestNextId++;
        if(abortControllerPtr != null) {
          // assign requestId to abortController, so we can get it back from abort call.
          vm.setProperty(abortControllerPtr, 'requestId', vm.dartToJS(requestId));
        }
        return vm.dartToJS(perform(requestId, httpOptions, clientOptions));
      }),
      'AbortController': vm.newConstructor((args, {thisObj}) {
        return vm.newObject({
          'requestId': -1,
          'abort': vm.newFunction('abort', (args, {thisObj}) {
            final requestId = vm.jsToDart(vm.getProperty(thisObj!, 'requestId'));
            if(requestId == null) {
              throw JSError('Not request attached to this controller.');
            }
            _abortControllers[requestId]?.abort();
          }),
        });
      }),
    });
  }

  void dispose() {
    client.close();
  }

  Future perform(int requestId, Map httpOptions, Map clientOptions) async {
    AbortController _abortController = AbortController();

    _abortControllers[requestId] = _abortController;
    try {
      return await send(client, httpOptions, clientOptions, cacheProvider: cacheProvider, encodingMap: _encodingMap, abortController: _abortController, requestInterceptor: requestInterceptor, responseInterceptor: responseInterceptor);
    } catch(err, stackTrace) {
      if(err is HttpException) {
        return {"statusCode": err is AbortException ? 308 : 0, "reasonPhrase": err.message};
      } else {
        if(!quiet) {
          print('Request for ${httpOptions["url"]} failed.\n$err\n$stackTrace');
        }
        return {"statusCode": 0, "reasonPhrase": err.toString()};
      }
    } finally {
      _abortControllers.remove(requestId);
    }
  }
}