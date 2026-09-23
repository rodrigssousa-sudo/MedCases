import 'private_session_epoch.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'canonical_catalog_cipher.dart';
import 'private_data_cipher_native.dart';

/// Credentials are AES-GCM encrypted with a UID-bound OS key, in the existing
/// app-private, no-backup protected directory. No credentials in preferences.
class SecureSessionStore {
  static const _channel = MethodChannel('medcases/audio_at_rest_v2');
  static Future<File> _file(String uid) async {
    final root = await _channel.invokeMethod<String>('secureRoot');
    if (root == null) throw StateError('SECURE_SESSION_ROOT_UNAVAILABLE');
    return File('$root/session-${catalogUidHash(uid)}.v1');
  }

  static Future<void> write(Map<String, String> record) async {
    final epoch = PrivateSessionEpoch.current;
    final uid = record['uid']!;
    final cipher = createPrivateDataCipher();
    final sealed = await cipher.seal(uid, 'session.v1:$uid',
        Uint8List.fromList(utf8.encode(jsonEncode(record))));
    final file = await _file(uid);
    if (epoch != PrivateSessionEpoch.current ||
        FirebaseAuth.instance.currentUser?.uid != uid)
      throw StateError('STALE_USER_OPERATION');
    final staged = File('${file.path}.staged');
    await staged.writeAsBytes(sealed, flush: true);
    await _channel
        .invokeMethod<void>('protectDurableFile', {'path': staged.path});
    if (epoch != PrivateSessionEpoch.current ||
        FirebaseAuth.instance.currentUser?.uid != uid)
      throw StateError('STALE_USER_OPERATION');
    await staged.rename(file.path);
  }

  static Future<Map<String, String>?> read() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final file = await _file(uid);
    if (!await file.exists()) return null;
    final clear = await createPrivateDataCipher()
        .open(uid, 'session.v1:$uid', await file.readAsBytes());
    final value =
        Map<String, String>.from(jsonDecode(utf8.decode(clear)) as Map);
    if (value['uid'] != uid) throw StateError('SECURE_SESSION_OWNER_MISMATCH');
    return value;
  }

  static Future<void> clear() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final file = await _file(uid);
    if (await file.exists()) await file.delete();
  }
}
