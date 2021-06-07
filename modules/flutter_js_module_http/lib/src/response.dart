import 'dart:io';

class EncodableRedirectInfo extends RedirectInfo {
  late final int statusCode;

  late final String method;

  late final Uri location;

  EncodableRedirectInfo(this.statusCode, this.method, this.location);

  EncodableRedirectInfo.fromRedirectInfo(RedirectInfo raw)
      : statusCode = raw.statusCode,
        method = raw.method,
        location = raw.location;

  EncodableRedirectInfo.fromMap(dynamic map) {
    if (map is RedirectInfo) {
      statusCode = map.statusCode;
      method = map.method;
      location = map.location;
    } else {
      statusCode = map['statusCode'];
      method = map['method'];
      location =
          map['location'] is Uri ? map['location'] : Uri.parse(map['location']);
    }
  }

  Map toMap() {
    return {
      'statusCode': statusCode,
      'method': method,
      'location': location.toString(),
    };
  }

  Map toJson() => toMap();
}

class NativeResponse {
  Map<String, String> headers;
  bool isRedirect;
  bool persistentConnection;
  String reasonPhrase;
  int statusCode;
  dynamic body;
  List<EncodableRedirectInfo> redirects;

  NativeResponse({
    this.headers = const {},
    this.isRedirect = false,
    this.persistentConnection = true,
    this.reasonPhrase = '',
    required this.statusCode,
    this.body = '',
    this.redirects = const [],
  });

  NativeResponse.fromMap(Map map)
      : this(
          headers: (map['headers'] as Map).cast<String, String>(),
          isRedirect: map['isRedirect'],
          persistentConnection: map['persistentConnection'],
          reasonPhrase: map['reasonPhrase'],
          statusCode: map['statusCode'],
          body: map['body'],
          redirects: (map['redirects'] as List)
              .map((_) => EncodableRedirectInfo.fromMap(_))
              .toList(),
        );

  Map toMap() {
    return {
      'headers': headers,
      'isRedirect': isRedirect,
      'persistentConnection': persistentConnection,
      'reasonPhrase': reasonPhrase,
      'statusCode': statusCode,
      'body': body,
      'redirects': redirects,
    };
  }

  Map toJson() => toMap();
}
