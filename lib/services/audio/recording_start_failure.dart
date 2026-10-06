import 'dart:io';

/// Metadata only: never includes native error messages, paths or audio.
class RecordingStartFailure implements Exception {
  const RecordingStartFailure(this.code, this.stage);
  final String code, stage;
  static RecordingStartFailure from(Object error, String stage) {
    if (error is RecordingStartFailure) return error;
    if (error is FileSystemException) {
      return RecordingStartFailure('FILESYSTEM_CREATE_FAILED', stage);
    }
    if (error is StateError &&
        {'MONTHLY_USAGE_LIMIT', 'TRANSCRIPTION_LIMIT_REACHED'}
            .contains(error.message)) {
      return RecordingStartFailure('QUOTA_UNAVAILABLE', stage);
    }
    if (error is StateError &&
        {
          'RATE_LIMITED',
          'CONCURRENT_RESERVATION_LIMIT',
          'RECORDING_LIMIT_REACHED',
          'TECHNICAL_RECORDING_LIMIT'
        }.contains(error.message))
      return RecordingStartFailure(error.message, stage);
    return RecordingStartFailure('UNKNOWN_RECORDING_START_FAILURE', stage);
  }

  bool get microphone =>
      code == 'MIC_PERMISSION_DENIED' || code == 'MIC_PERMISSION_RESTRICTED';
  String message({required bool isEs}) {
    if (code == 'RATE_LIMITED')
      return isEs
          ? 'Hay demasiadas solicitudes seguidas. Inténtalo nuevamente en unos instantes.'
          : 'Muitas solicitações em sequência. Tente novamente em instantes.';
    if (code == 'TECHNICAL_RECORDING_LIMIT')
      return isEs
          ? 'Se alcanzó el límite técnico de esta grabación.'
          : 'O limite técnico desta gravação foi atingido.';
    if (code == 'RECORDING_LIMIT_REACHED')
      return isEs
          ? 'Alcanzaste el límite disponible para grabación.'
          : 'Você atingiu o limite disponível para gravação.';
    if (microphone)
      return isEs
          ? 'MedCases necesita acceso al micrófono para iniciar la grabación.'
          : 'O MedCases precisa de acesso ao microfone para iniciar a gravação.';
    if (code == 'QUOTA_UNAVAILABLE')
      return isEs
          ? 'No hay tiempo de transcripción disponible.'
          : 'Não há tempo de transcrição disponível.';
    if (code == 'RECORDER_ALREADY_ACTIVE' || code == 'ACTIVE_SOURCE_CONFLICT')
      return isEs
          ? 'Ya hay una grabación o un procesamiento en curso.'
          : 'Já existe uma gravação ou um processamento em andamento.';
    return isEs
        ? 'No pudimos iniciar la grabación. Inténtalo nuevamente.'
        : 'Não foi possível iniciar a gravação. Tente novamente.';
  }

  @override
  String toString() => '$code:$stage';
}
