class JSError extends Error{
  String? name;
  late String message;
  late final StackTrace stackTrace;
  JSError(message, [stackTrace]) {
    if (message is JSError) {
      this.message = message.message;
      this.stackTrace = message.stackTrace;
    } else {
      this.message = message.toString();
      this.stackTrace = stackTrace ?? StackTrace.current;
    }
  }

  @override
  String toString() {
    return '${name??"JSError"}: $message\n$stackTrace';
  }

  Map<String, String> toMap() {
    return {
      if(name != null) 'name': name!,
      'message': message,
      'stack': stackTrace.toString(),
    };
  }
}

class DisposeError extends Error {
  dynamic message;
  StackTrace? stackTrace;

  DisposeError([this.message, this.stackTrace]);

  String toString() {
    return 'DisposeError: $message\n$stackTrace';
  }
}

class BlockError extends Error {
  dynamic message;
  StackTrace? stackTrace;
  DisposeError? disposeError;

  BlockError([this.message, this.stackTrace]);

  String toString() {
    return 'BlockError: $message';
  }
}