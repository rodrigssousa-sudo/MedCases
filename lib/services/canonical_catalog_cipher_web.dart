import 'entitlement_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'canonical_catalog_cipher.dart';

@JS('crypto')
external _Crypto get _crypto;
@JS('indexedDB')
external _Factory get _indexedDB;
extension type _Crypto(JSObject _) implements JSObject {
  external _Subtle get subtle;
  external JSUint8Array getRandomValues(JSUint8Array bytes);
}
extension type _Subtle(JSObject _) implements JSObject {
  external JSPromise<JSAny> generateKey(
      JSAny algorithm, bool extractable, JSArray<JSString> usages);
  external JSPromise<JSArrayBuffer> encrypt(
      JSAny algorithm, JSAny key, JSUint8Array bytes);
  external JSPromise<JSArrayBuffer> decrypt(
      JSAny algorithm, JSAny key, JSUint8Array bytes);
}
extension type _Factory(JSObject _) implements JSObject {
  external _Request open(String name, int version);
}
extension type _Request(JSObject _) implements JSObject {
  external JSAny? get result;
  external set onsuccess(JSFunction callback);
  external set onerror(JSFunction callback);
  external set onupgradeneeded(JSFunction callback);
}
extension type _Database(JSObject _) implements JSObject {
  external _Store createObjectStore(String name);
  external _Transaction transaction(String name, String mode);
  external void close();
}
extension type _Transaction(JSObject _) implements JSObject {
  external _Store objectStore(String name);
  external set oncomplete(JSFunction callback);
  external set onabort(JSFunction callback);
  external set onerror(JSFunction callback);
}
extension type _Store(JSObject _) implements JSObject {
  @JS('get')
  external _Request read(String key);
  external _Request put(JSAny value, String key);
}
Future<JSAny?> _result(_Request request) {
  final done = Completer<JSAny?>();
  request.onsuccess = ((JSAny? _) {
    if (!done.isCompleted) done.complete(request.result);
  }).toJS;
  request.onerror = ((JSAny? _) {
    if (!done.isCompleted) done.completeError(StateError('CATALOG_KEY_STORE'));
  }).toJS;
  return done.future;
}

/// Browser-only non-extractable AES keys; clear documents never enter storage.
class WebCanonicalCatalogCipher implements CanonicalCatalogCipher {
  WebCanonicalCatalogCipher(
      {String? Function()? currentUid, bool Function()? authorized})
      : _currentUid = currentUid ??
            (() => EntitlementService.instance.current.resolvedUid),
        _authorized =
            authorized ?? (() => EntitlementService.instance.isPremium);
  final String? Function() _currentUid;
  final bool Function() _authorized;
  void _check(String uid) {
    if (_currentUid() != uid || !_authorized())
      throw StateError('CACHE_NOT_AUTHORIZED');
  }

  Future<_Database> _database() async {
    final request = _indexedDB.open('medcases.catalog.keys.v1', 1);
    request.onupgradeneeded = ((JSAny? _) {
      _Database(request.result as JSObject).createObjectStore('keys');
    }).toJS;
    return _Database(await _result(request) as JSObject);
  }

  Future<JSAny> _key(String uid, {required bool create}) async {
    _check(uid);
    final db = await _database();
    final alias = catalogUidHash(uid);
    try {
      final existing = await _result(
          db.transaction('keys', 'readonly').objectStore('keys').read(alias));
      if (existing != null) return existing;
      if (!create) throw StateError('CACHE_KEY_MISSING');
      final generated = await _crypto.subtle
          .generateKey({'name': 'AES-GCM', 'length': 256}.jsify()!, false,
              ['encrypt'.toJS, 'decrypt'.toJS].toJS)
          .toDart;
      final tx = db.transaction('keys', 'readwrite');
      final store = tx.objectStore('keys');
      final done = Completer<void>();
      tx.oncomplete = ((JSAny? _) {
        if (!done.isCompleted) done.complete();
      }).toJS;
      void fail(JSAny? _) {
        if (!done.isCompleted)
          done.completeError(StateError('CACHE_KEY_TRANSACTION'));
      }

      tx.onerror = fail.toJS;
      tx.onabort = fail.toJS;
      final raced = await _result(store.read(alias));
      if (raced == null) await _result(store.put(generated, alias));
      await done.future;
      return raced ?? generated;
    } finally {
      db.close();
    }
  }

  Future<Uint8List> _crypt(bool encrypt, JSAny key, Uint8List nonce,
      String metadata, Uint8List bytes) async {
    final algorithm = {
      'name': 'AES-GCM',
      'iv': nonce.toJS,
      'additionalData': Uint8List.fromList(utf8.encode(metadata)).toJS,
      'tagLength': 128
    }.jsify()!;
    final result = await (encrypt
            ? _crypto.subtle.encrypt(algorithm, key, bytes.toJS)
            : _crypto.subtle.decrypt(algorithm, key, bytes.toJS))
        .toDart;
    return Uint8List.view(result.toDart);
  }

  @override
  Future<Uint8List> seal(
      String uid, String metadata, Uint8List plaintext) async {
    _check(uid);
    final nonce = Uint8List(12);
    _crypto.getRandomValues(nonce.toJS);
    final result = Uint8List.fromList([
      ...nonce,
      ...await _crypt(
          true, await _key(uid, create: true), nonce, metadata, plaintext)
    ]);
    _check(uid);
    return result;
  }

  @override
  Future<Uint8List> open(
      String uid, String metadata, Uint8List ciphertext) async {
    _check(uid);
    final result = await _crypt(false, await _key(uid, create: false),
        ciphertext.sublist(0, 12), metadata, ciphertext.sublist(12));
    _check(uid);
    return result;
  }
}

CanonicalCatalogCipher createCatalogCipher() => WebCanonicalCatalogCipher();
