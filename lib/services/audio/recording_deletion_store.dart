import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UID-scoped durable tombstones. A failed local erase remains blocked but
/// visible so the owner can retry; successful deletion is hidden permanently.
class RecordingDeletionStore {
  static String? Function()? ownerOverride;
  static String? get owner {
    if (ownerOverride != null) return ownerOverride!();
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static final Set<String> _blocked = {};
  static String _key(String uid, String sid) =>
      'medcases.recording.deleted.v1.${base64Url.encode(utf8.encode(uid))}.$sid';
  static bool blockedCached(String uid, String sid) =>
      _blocked.contains(_key(uid, sid));
  static Future<String?> state(String uid, String sid) async {
    final value =
        (await SharedPreferences.getInstance()).getString(_key(uid, sid));
    if (value != null) _blocked.add(_key(uid, sid));
    return value;
  }

  static Future<Map<String, dynamic>?> sourceBinding(String sourceId) async {
    final uid = owner;
    if (uid == null) throw StateError('recording_owner_changed');
    final prefs = await SharedPreferences.getInstance();
    final matches = <String, Map<String, dynamic>>{};
    for (final key in prefs
        .getKeys()
        .where((k) => k.startsWith('medcases.recorded.pending.$uid.'))) {
      try {
        final data =
            Map<String, dynamic>.from(jsonDecode(prefs.getString(key)!));
        if (data['sourceId'] == sourceId && data['sessionId'] is String)
          matches[data['sessionId']] = data;
      } catch (_) {}
    }
    if (owner != uid) throw StateError('recording_owner_changed');
    return matches.length == 1 ? matches.values.single : null;
  }

  static Future<void> removePendingBindings(String uid, String sid) async {
    if (owner != uid) throw StateError('recording_owner_changed');
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'medcases.recorded.pending.$uid.';
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      Map? data;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = decoded;
      } catch (_) {
        continue;
      }
      if (data?['sessionId'] != sid) continue;
      if (owner != uid) throw StateError('recording_owner_changed');
      if (!await prefs.remove(key))
        throw StateError('checkpoint_delete_failed');
    }
  }

  static Future<void> mark(String uid, String sid,
      {bool complete = false}) async {
    if (owner != uid) throw StateError('recording_owner_changed');
    final key = _key(uid, sid);
    _blocked.add(key);
    final ok = await (await SharedPreferences.getInstance())
        .setString(key, complete ? 'deleted' : 'deleting');
    if (!ok) throw StateError('tombstone_write_failed');
  }
}
