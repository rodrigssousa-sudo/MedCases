import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Internal metadata destinations only; never accepts a URL or grants access.
class GuideNavigationIntent {
  static const _key = 'medcases_guide_intent_v1';
  static Future<String?> canonicalId(String slug) async {
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) return null;
    final rows = jsonDecode(await rootBundle
        .loadString('assets/public_landing/featured_guides.json')) as List;
    for (final row in rows) {
      if (row['slug'] == slug) return row['id'] as String;
    }
    return null;
  }

  static Future<bool> request(String slug) async {
    if (await canonicalId(slug) == null) return false;
    await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(
            {'slug': slug, 'at': DateTime.now().millisecondsSinceEpoch}));
    return true;
  }

  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
  static Future<String?> pendingId() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    try {
      final row = jsonDecode(raw) as Map;
      final age = DateTime.now().millisecondsSinceEpoch - (row['at'] as int);
      if (age < 0 || age >= const Duration(hours: 1).inMilliseconds) {
        await clear();
        return null;
      }
      return canonicalId(row['slug'] as String);
    } catch (_) {
      await clear();
      return null;
    }
  }
}
