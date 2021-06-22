import 'dart:async';
import 'dart:convert';

import 'dart:io';

abstract class CookieManager {
  /// Add a [cookie] associated it with [uri] to this manager.
  FutureOr<void> set(Uri uri, Cookie cookie);

  /// Add [cookies] to this manager.
  FutureOr<void> setAll(Uri uri, List<Cookie> cookies);

  /// Get [Cookie]s that are associated with [uri].
  FutureOr<List<Cookie>> get(Uri uri);

  /// Get [Cookie]s that are associated with [uri] and filtered by [name].
  FutureOr<List<Cookie>> getByName(Uri uri, String name);

  /// Delete all [Cookie]s from this manager that are associated with [uri].
  FutureOr<void> delete(Uri uri);

  /// Delete all [Cookie]s from this manager that are associated with [uri] and filtered by [name].
  FutureOr<void> deleteByName(Uri uri, String name);

  /// Clear all [Cookie]s held by this manager
  FutureOr<void> deleteAll();

  static Map toJson(Cookie cookie) {
    return {
      'name': cookie.name,
      'value': cookie.value,
      'domain': cookie.domain,
      'path': cookie.path,
      'secure': cookie.secure,
      'httpOnly': cookie.httpOnly,
      if (cookie.expires != null) 'expires': cookie.expires!.toIso8601String(),
      if (cookie.maxAge != null) 'maxAge': cookie.maxAge,
      'RFC6265string': cookie.toString(),
    };
  }

  static Cookie fromJson(Map map) {
    Cookie result = Cookie(map['name']!, map['value']!);
    result.domain = map['domain'];
    result.path = map['path'];
    result.secure = map['secure'] == true;
    result.httpOnly = map['httpOnly'] == true;
    if (map['expires'] != null) {
      result.expires = DateTime.parse(map['expires'].endsWith('Z') ? 'yyyy-MM-ddTHH:mm:ss.mmmuuuZ' : 'yyyy-MM-ddTHH:mm:ss.mmmuuu');
    }
    if (map['maxAge'] != null) {
      result.maxAge = map['maxAge'];
    }
    return result;
  }

  static bool isExpired(Cookie cookie, DateTime createTime) {
    // check Max-Age
    if (cookie.maxAge != null) {
      if (cookie.maxAge! <= 0) {
        return true;
      }
      if (cookie.maxAge! + createTime.millisecondsSinceEpoch < DateTime.now().millisecondsSinceEpoch) {
        return true;
      }
    } else if (cookie.expires != null) {
      // check Expires
      if (cookie.expires!.millisecondsSinceEpoch < DateTime.now().millisecondsSinceEpoch) {
        return true;
      }
    }
    return false;
  }
}

typedef _Domain = String;
typedef _Host = String;

class CookieWrapper {
  late final Cookie cookie;
  late final DateTime createTime;

  CookieWrapper(this.cookie) : createTime = DateTime.now();

  Map toJson() {
    return {
      'createTime': createTime.millisecondsSinceEpoch,
      'cookie': CookieManager.toJson(cookie),
    };
  }

  CookieWrapper.fromJson(Map map) {
    this.createTime = DateTime.fromMillisecondsSinceEpoch(map['createTime']);
    this.cookie = CookieManager.fromJson(map['cookie']);
  }

  @override
  bool operator ==(Object other) {
    if (!(other is CookieWrapper)) {
      return false;
    }
    return this.createTime.millisecondsSinceEpoch == other.createTime.millisecondsSinceEpoch &&
        this.cookie.name == other.cookie.name &&
        this.cookie.value == other.cookie.value &&
        this.cookie.domain == other.cookie.domain &&
        this.cookie.path == other.cookie.path &&
        this.cookie.secure == other.cookie.secure &&
        this.cookie.httpOnly == other.cookie.httpOnly &&
        this.cookie.expires == other.cookie.expires &&
        this.cookie.maxAge == other.cookie.maxAge;
  }
}

/// A simple in-memory [CookieManager].
class InMemoryCookieManager implements CookieManager {
  final Map<_Domain, List<CookieWrapper>> domainCookies = {};
  final Map<_Host, List<CookieWrapper>> hostCookies = {};

  InMemoryCookieManager();

  @override
  void delete(Uri uri) {
    String host = uri.host;
    String path = uri.path;
    if (path.isEmpty) {
      path = '/';
    }
    domainCookies.forEach((_domain, cookies) {
      if (host.endsWith(_domain)) {
        cookies.removeWhere((cookie) {
          // check Path
          if (!_isPathMatch(path, cookie.cookie.path)) {
            return false;
          }
          // check Secure
          if (cookie.cookie.secure && uri.scheme != 'https') {
            return false;
          }
          return true;
        });
      }
    });
    hostCookies.forEach((_host, cookies) {
      if (host == _host) {
        cookies.removeWhere((cookie) {
          // check Path
          if (!_isPathMatch(path, cookie.cookie.path)) {
            return false;
          }
          // check Secure
          if (cookie.cookie.secure && uri.scheme != 'https') {
            return false;
          }
          return true;
        });
      }
    });
  }

  @override
  void deleteAll() {
    hostCookies.clear();
    domainCookies.clear();
  }

  @override
  void deleteByName(Uri uri, String name) {
    String host = uri.host;
    String path = uri.path;
    if (path.isEmpty) {
      path = '/';
    }
    domainCookies.forEach((_domain, cookies) {
      if (host.endsWith(_domain)) {
        cookies.removeWhere((cookie) {
          // check Name
          if (cookie.cookie.name != name) {
            return false;
          }
          // check Path
          if (!_isPathMatch(path, cookie.cookie.path)) {
            return false;
          }
          // check Secure
          if (cookie.cookie.secure && uri.scheme != 'https') {
            return false;
          }
          return true;
        });
      }
    });
    hostCookies.forEach((_host, cookies) {
      if (host == _host) {
        cookies.removeWhere((cookie) {
          // check Name
          if (cookie.cookie.name != name) {
            return false;
          }
          // check Path
          if (!_isPathMatch(path, cookie.cookie.path)) {
            return false;
          }
          // check Secure
          if (cookie.cookie.secure && uri.scheme != 'https') {
            return false;
          }
          return true;
        });
      }
    });
  }

  @override
  List<Cookie> get(Uri uri) {
    List<Cookie> result = [];
    String host = uri.host;
    String path = uri.path;
    if (path.isEmpty) {
      path = '/';
    }
    domainCookies.forEach((_domain, cookies) {
      if (host.endsWith(_domain)) {
        cookies.forEach((cookie) {
          // check Path
          if (!_isPathMatch(path, cookie.cookie.path)) {
            return;
          }
          // check Secure
          if (cookie.cookie.secure && uri.scheme != 'https') {
            return;
          }
          // check Expiration
          if (CookieManager.isExpired(cookie.cookie, cookie.createTime)) {
            return;
          }
          result.add(cookie.cookie);
        });
      }
    });
    hostCookies.forEach((_host, cookies) {
      if (host == _host) {
        cookies.forEach((cookie) {
          // check Path
          if (!_isPathMatch(path, cookie.cookie.path)) {
            return;
          }
          // check Secure
          if (cookie.cookie.secure && uri.scheme != 'https') {
            return;
          }
          // check Expiration
          if (CookieManager.isExpired(cookie.cookie, cookie.createTime)) {
            return;
          }
          result.add(cookie.cookie);
        });
      }
    });
    return result;
  }

  @override
  List<Cookie> getByName(Uri uri, String name) {
    List<Cookie> result = [];
    String host = uri.host;
    String path = uri.path;
    if (path.isEmpty) {
      path = '/';
    }
    domainCookies.forEach((_domain, cookies) {
      if (host.endsWith(_domain)) {
        cookies.forEach((cookie) {
          // check Name
          if (cookie.cookie.name != name) {
            return;
          }
          // check Path
          if (!_isPathMatch(path, cookie.cookie.path)) {
            return;
          }
          // check Secure
          if (cookie.cookie.secure && uri.scheme != 'https') {
            return;
          }
          // check Expiration
          if (CookieManager.isExpired(cookie.cookie, cookie.createTime)) {
            return;
          }
          result.add(cookie.cookie);
        });
      }
    });
    hostCookies.forEach((_host, cookies) {
      if (host == _host) {
        cookies.forEach((cookie) {
          // check Name
          if (cookie.cookie.name != name) {
            return;
          }
          // check Path
          if (!_isPathMatch(path, cookie.cookie.path)) {
            return;
          }
          // check Secure
          if (cookie.cookie.secure && uri.scheme != 'https') {
            return;
          }
          // check Expiration
          if (CookieManager.isExpired(cookie.cookie, cookie.createTime)) {
            return;
          }
          result.add(cookie.cookie);
        });
      }
    });
    return result;
  }

  @override
  void set(Uri uri, Cookie cookie) {
    if (cookie.domain == null) {
      _setCookie(hostCookies.putIfAbsent(uri.host, () => <CookieWrapper>[]), cookie);
      return;
    }
    _setCookie(domainCookies.putIfAbsent(cookie.domain!, () => <CookieWrapper>[]), cookie);
  }

  @override
  void setAll(Uri uri, List<Cookie> cookies) {
    cookies.forEach((cookie) {
      set(uri, cookie);
    });
  }

  bool _isPathMatch(String path, String? target) {
    if (target == null || target == path || target == '/') {
      return true;
    }
    String t = target.endsWith('/') ? target : target + '/';
    return path.startsWith(t);
  }

  /// delete cookies that are identical with [cookie] from [cookies] and add the new [cookie]
  void _setCookie(List<CookieWrapper> cookies, Cookie cookie) {
    cookies.removeWhere((_) => _isCookieEqual(_.cookie, cookie));
    cookies.add(CookieWrapper(cookie));
  }

  /// test whether [cookie1] and [cookie2] are identical, check domain, path, secure, name
  bool _isCookieEqual(Cookie cookie1, Cookie cookie2) {
    return cookie1.name == cookie2.name && cookie1.domain == cookie2.domain && cookie1.path == cookie2.path && cookie1.secure == cookie2.secure;
  }

  String stringify() {
    return jsonEncode([
      hostCookies,
      domainCookies,
    ]);
  }

  InMemoryCookieManager.restore(String json) {
    List l = jsonDecode(json);
    (l[0] as Map).cast<String, List>().forEach((key, value) {
      hostCookies[key] = value.map((_) => CookieWrapper.fromJson(_)).where((cookie) => !CookieManager.isExpired(cookie.cookie, cookie.createTime)).toList();
    });
    (l[1] as Map).cast<String, List>().forEach((key, value) {
      domainCookies[key] = value.map((_) => CookieWrapper.fromJson(_)).where((cookie) => !CookieManager.isExpired(cookie.cookie, cookie.createTime)).toList();
    });
  }
}
