type Console = {
  log(...args: any[]):void;
  info(...args: any[]):void;
  debug(...args: any[]):void;
  error(...args: any[]):void;
};
declare var console:Console;

type HttpMethod = 'HEAD'|'GET'|'POST'|'PUT'|'PATCH'|'DELETE';
type FlutterJSHttpModuleHttpOptions = {
  method?:HttpMethod;
  url:string;
  followRedirects?: boolean;
  maxRedirects?: number;
  /**
   * Document from http.dart:
   * 
   * The requested persistent connection state.
   *
   * The default value is `true`.
   */
  persistentConnection?: boolean;
  headers?:Record<string, string>;
  body?: string|{[x: string]: any}
};
type FlutterJSHttpModuleClientOptions = {
  /**
   * Document from http.dart:
   * 
   * Gets and sets the connection timeout.
   *
   * When connecting to a new host exceeds this timeout, a [SocketException]
   * is thrown. The timeout applies only to connections initiated after the
   * timeout is set.
   * 
   * When this is `null`, the OS default timeout is used. The default is
   * `null`.
   */
  connectionTimeout?: number;
  /**
   * Document from http.dart:
   * 
   * Gets and sets the idle timeout of non-active persistent (keep-alive)
   * 
   * connections.
   * 
   * The default value is 15 seconds.
   */
  idleTimeout?: number;
  /**
   * Document from http.dart:
   * 
   * Gets and sets whether the body of a response will be automatically
   * uncompressed.
   *
   * The body of an HTTP response can be compressed. In most
   * situations providing the un-compressed body is most
   * convenient. Therefore the default behavior is to un-compress the
   * body. However in some situations (e.g. implementing a transparent
   * proxy) keeping the uncompressed stream is required.
   *
   * NOTE: Headers in the response are never modified. This means
   * that when automatic un-compression is turned on the value of the
   * header `Content-Length` will reflect the length of the original
   * compressed body. Likewise the header `Content-Encoding` will also
   * have the original value indicating compression.
   *
   * NOTE: Automatic un-compression is only performed if the
   * `Content-Encoding` header value is `gzip`.
   *
   * This value affects all responses produced by this client after the
   * value is changed.
   *
   * To disable, set to `false`.
   *
   * Default is `true`.
   */
  autoUncompress?: boolean;
  /**
   * Whether to automatically send & store cookies like in browser.
   * Default true.
   */
  followCookies?: boolean;
  /**
   * Set to false to disable underlying cache for this request.
   */
  cache?: boolean;
  /**
   * Preferred encoding, it is used when there is no encoding in response headers.
   * If this value ends with a `!`, then the encoding in response headers will be ignored.
   */
  encoding?: string;
  /**
   * Prevent default headers if any.
   * Default false.
   */
  preventDefaultHeaders?: boolean;
  /**
   * Prefer the charset specified in the html meta tag.
   * Default false.
   */
  htmlPreferMetaCharset?: boolean;
  /**
   * Custom options
   */
  [x:string]:any;
};
type FlutterJSHttpModuleResponse = {
  headers:Record<string, string>;
  isRedirect: boolean;
  persistentConnection: boolean;
  reasonPhrase: string;
  statusCode: number;
  body: string/* |ArrayBuffer */;
  redirects: {statusCode:number;method:HttpMethod;location:string}[];
};
type FlutterJSHttpModuleErrorResponse = {
  statusCode: 0;
  reasonPhrase: string;
};
type FlutterJSHttpModuleAbortController = {
  /**
   * Abort the attached request
   */
  abort():void;
};

declare module 'http' {
  function send(httpOptions:FlutterJSExtensionHttpOptions|string, abortController?: AbortController): Promise<FlutterJSExtensionResponse|FlutterJSExtensionErrorResponse>;
  function send(httpOptions:FlutterJSExtensionHttpOptions|string, clientOptions?:FlutterJSExtensionClientOptions, abortController?: AbortController): Promise<FlutterJSExtensionResponse|FlutterJSExtensionErrorResponse>;
  const AbortController: FlutterJSHttpModuleAbortController;
};