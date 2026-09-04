import 'package:shared_preferences/shared_preferences.dart';

final class StudyFirstUseNoticeService {
  const StudyFirstUseNoticeService._();

  static const _studyKey = 'medcases.study.educational_notice.v1.accepted';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_studyKey) ?? false;
  }

  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_studyKey, true);
  }
}
