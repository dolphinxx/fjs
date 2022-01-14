import 'dart:convert';
import 'dart:io';
import 'package:fjs/error.dart';
import 'package:fjs/vm.dart';
import 'package:fjs/types.dart';
import 'package:fjs/module.dart';

import 'request.dart';
import 'cache.dart';
import 'cookie.dart';
import 'abort_controller.dart';

typedef HttpClientProvider = HttpClient Function();

class FlutterJSHttpModule implements FlutterJSModule{
  final Map<String, Encoding> _encodingMap = {};
  final Map<int, AbortController> _abortControllers = {};
  HttpClientProvider httpClientProvider;
  CacheProvider? cacheProvider;
  CookieManager? cookieManager;
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
    HttpClientProvider? httpClientProvider,
    Map<String, Encoding>? encodingMap,
    bool? verbose,
    this.httpOptions,
    this.clientOptions,
    this.cacheProvider,
    this.cookieManager,
    this.beforeSendInterceptor,
    this.requestInterceptor,
    this.responseInterceptor,
  }):verbose = verbose??false,httpClientProvider = httpClientProvider?? (() => HttpClient()) {
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
      'cookieManager': cookieManager == null ? vm.$undefined : vm.dartToJS({
        'set': vm.newFunction('_set', (args, {thisObj}) {
          String uri = vm.jsToDart(args[0]);
          dynamic cookie = vm.jsToDart(args[1]);
          if(cookie is List) {
            return vm.dartToJS(cookieManager!.setAll(Uri.parse(uri), cookie.map((raw) => Cookie.fromSetCookieValue(raw)).toList()));
          }
          return vm.dartToJS(cookieManager!.set(Uri.parse(uri), Cookie.fromSetCookieValue(cookie)));
        }),
        'get': vm.newFunction('_get', (args, {thisObj}) {
          String uri = vm.jsToDart(args[0]);
          return vm.dartToJS(Future.value(cookieManager!.get(Uri.parse(uri))).then((cookies) => cookies.map((cookie) => CookieManager.toJson(cookie)).toList()));
        }),
        'getByName': vm.newFunction('getByName', (args, {thisObj}) {
          String uri = vm.jsToDart(args[0]);
          String name = vm.jsToDart(args[1]);
          return vm.dartToJS(Future.value(cookieManager!.getByName(Uri.parse(uri), name)).then((cookies) => cookies.map((cookie) => CookieManager.toJson(cookie)).toList()));
        }),
        'delete': vm.newFunction('_delete', (args, {thisObj}) {
          String uri = vm.jsToDart(args[0]);
          return vm.dartToJS(cookieManager!.delete(Uri.parse(uri)));
        }),
        'deleteByName': vm.newFunction('deleteByName', (args, {thisObj}) {
          String uri = vm.jsToDart(args[0]);
          String name = vm.jsToDart(args[1]);
          return vm.dartToJS(cookieManager!.deleteByName(Uri.parse(uri), name));
        }),
        'deleteAll': vm.newFunction('deleteAll', (args, {thisObj}) {
          return vm.dartToJS(cookieManager!.deleteAll());
        }),
      }),
    });
  }

  void dispose() {
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
    HttpClient client = httpClientProvider();
    try {
      return (await send(client, httpOptions, clientOptions, cacheProvider: cacheProvider, cookieManager: cookieManager, encodingMap: _encodingMap, abortController: _abortController, beforeSendInterceptor: beforeSendInterceptor, requestInterceptor: requestInterceptor, responseInterceptor: responseInterceptor, verbose: verbose)).toMap();
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
      client.close();
    }
  }
}