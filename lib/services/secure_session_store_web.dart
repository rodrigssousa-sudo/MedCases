import 'dart:convert';
import 'dart:js_interop';

@JS('sessionStorage')
external _SessionStorage get _storage;
extension type _SessionStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// Browser tab-scoped session storage, not an OS keychain. No localStorage
/// refresh-token copy; same-origin script/XSS remains a browser security boundary.
class SecureSessionStore {
  static const _key = 'medcases.auth.session.v1';
  static Future<void> write(Map<String, String> record) async {
    _storage.setItem(_key, jsonEncode(record));
  }

  static Future<Map<String, String>?> read() async {
    final value = _storage.getItem(_key);
    return value == null
        ? null
        : Map<String, String>.from(jsonDecode(value) as Map);
  }

  static Future<void> clear() async {
    _storage.removeItem(_key);
  }
}
