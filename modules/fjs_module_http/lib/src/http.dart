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
  Map<String, dynamic>? httpOptions;
  Map<String, dynamic>? clientOptions;
  RequestInterceptor? requestInterceptor;
  ResponseInterceptor? responseInterceptor;
  BeforeSendInterceptor? beforeSendInterceptor;
  bool verbose;
  int _requestNextId = 1;

  /// Provide a [httpClientProvider] to have customization of `HttpClient` instance creation.
  ///
  /// If your desired charsets are not appear in `Encoding`, provider them through [encodingMap].
  ///
  /// Use [httpOptions] and [clientOptions] to apply default settings.
  FlutterJSHttpModule({
    HttpClient httpClientProvider()?,
    Map<String, Encoding>? encodingMap,
    bool? verbose,
    this.httpOptions,
    this.clientOptions,
    this.cacheProvider,
    this.beforeSendInterceptor,
    this.requestInterceptor,
    this.responseInterceptor,
  }):verbose = verbose??false {
    client = (httpClientProvider??() => HttpClient())();
    if(encodingMap != null) {
      _encodingMap.addAll(encodingMap);
    }
  }

  final String name = 'http';

  JSValuePointer resolve(Vm vm, List<String> path, String? version) {
    return vm.dartToJS({
      'send': vm.newFunction('send', (args, {thisObj}) {
        dynamic args0 = vm.jsToDart(args[0]);
        final httpOptions = args0 is String ? <String, dynamic>{'url': args0} : args0;
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
        return vm.dartToJS(perform(requestId, httpOptions.cast<String, dynamic>(), clientOptions.cast<String, dynamic>()));
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

  Future perform(int requestId, Map<String, dynamic> httpOptions, Map<String, dynamic> clientOptions) async {
    if(this.clientOptions != null) {
      this.clientOptions!.forEach((key, value) {
        if(!clientOptions.containsKey(key)) {
          clientOptions[key] = value;
        }
      });
    }
    if(this.httpOptions != null) {
      this.httpOptions!.forEach((key, value) {
        if(key == 'headers') {
          Map headers = httpOptions.putIfAbsent(key, () => Map<String, String>());
          if(clientOptions['preventDefaultHeaders'] != true) {
            (value as Map<String, String>).forEach((k, v) {
              headers.putIfAbsent(k, () => v);
            });
          }
        } else {
          if(!httpOptions.containsKey(key)) {
            httpOptions[key] = value;
          }
        }
      });
    }
    AbortController _abortController = AbortController();

    _abortControllers[requestId] = _abortController;
    try {
      return await send(client, httpOptions, clientOptions, cacheProvider: cacheProvider, encodingMap: _encodingMap, abortController: _abortController, beforeSendInterceptor: beforeSendInterceptor, requestInterceptor: requestInterceptor, responseInterceptor: responseInterceptor, verbose: verbose);
    } catch(err, stackTrace) {
      if(err is HttpException) {
        return {"statusCode": err is AbortException ? 308 : 0, "reasonPhrase": err.message};
      } else {
        if(verbose) {
          print('Request for ${httpOptions["url"]} failed.\n$err\n$stackTrace');
        }
        return {"statusCode": 0, "reasonPhrase": err.toString()};
      }
    } finally {
      _abortControllers.remove(requestId);
    }
  }
}