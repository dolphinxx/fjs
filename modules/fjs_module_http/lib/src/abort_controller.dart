import 'dart:io';

class AbortController {
  bool _aborted = false;
  bool get aborted => _aborted;
  HttpClientRequest? _request;
  /// Attach request to this controller, if it is already aborted, an [AbortException] will be thrown immediately.
  void attach(HttpClientRequest request) {
    if(_aborted) {
      request.abort(AbortException(request.uri));
    }
    _request = request;
  }

  void abort() {
    if(_aborted) {
      return;
    }
    _aborted = true;
    if(_request != null) {
      _request!.abort(AbortException(_request!.uri));
    }
  }
}

class AbortException extends HttpException{
  AbortException(Uri? uri):super('Request aborted by client.', uri: uri);
}