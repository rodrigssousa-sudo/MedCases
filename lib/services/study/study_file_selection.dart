import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'study_file_selection_native.dart'
    if (dart.library.html) 'study_file_selection_web.dart' as platform;

class MeasuredStudyFile {
  const MeasuredStudyFile(this.file, this.durationMs);
  final PlatformFile file;
  final int? durationMs;
}

Future<MeasuredStudyFile?> selectStudyFile(
    {required bool audio,
    required bool longInput,
    required List<String> extensions}) async {
  final owner = FirebaseAuth.instance.currentUser?.uid;
  if (owner == null) throw StateError('AUDIO_AUTH_REQUIRED');
  final file = await platform.select(extensions, longInput, audio);
  if (file == null) return null;
  try {
    final duration = audio ? await platform.duration(file) : null;
    if (audio && (duration == null || duration <= 0))
      throw PlatformException(code: 'AUDIO_DURATION_UNAVAILABLE');
    if (owner != FirebaseAuth.instance.currentUser?.uid)
      throw StateError('AUDIO_USER_CHANGED');
    return MeasuredStudyFile(file, duration);
  } catch (_) {
    platform.release(file);
    rethrow;
  }
}

void releaseStudyFile(MeasuredStudyFile file) => platform.release(file.file);
