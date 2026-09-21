import 'package:shared_preferences/shared_preferences.dart';

/// Stores navigation intent only. It never grants authentication or privileges.
class TestimonialIntent {
  static const _key = 'medcases_testimonial_intent_v1';
  static Future<void> request() async {
    await (await SharedPreferences.getInstance())
        .setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
  static Future<bool> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final when = prefs.getInt(_key);
    await prefs.remove(_key);
    if (when == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - when;
    return age >= 0 && age < const Duration(hours: 1).inMilliseconds;
  }
}
