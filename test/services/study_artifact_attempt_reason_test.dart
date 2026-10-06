import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_artifact_attempt_client.dart';

void main() {
  test('visual format failure is classified without exposing payload', () {
    expect(StudyArtifactAttemptClient.reason(
      StateError('study_generation_failed:invalid_visual_payload')), 'PARSE_FAILURE');
    expect(StudyArtifactAttemptClient.reason(
      const FormatException('private source text')), 'PARSE_FAILURE');
  });
  test('network timeout, owner change and persistence stay distinguishable', () {
    expect(StudyArtifactAttemptClient.reason(TimeoutException('private URL')), 'PROVIDER_TIMEOUT');
    expect(StudyArtifactAttemptClient.reason(StateError('study_owner_changed')), 'AUTH');
    expect(StudyArtifactAttemptClient.reason(StateError('study_visual_persistence_failed')), 'PERSISTENCE_FAILURE');
    expect(StudyArtifactAttemptClient.reason(StateError('unexpected private content')), 'OTHER');
  });
}
