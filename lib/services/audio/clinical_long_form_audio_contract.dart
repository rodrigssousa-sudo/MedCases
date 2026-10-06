enum ClinicalLongFormRecordingState {
  idle,
  recording,
  paused,
  stopped,
}

final class ClinicalLongFormRecordingConfig {
  const ClinicalLongFormRecordingConfig({
    this.continuous = false,
    this.unlimitedLocalCapture = false,
    this.append = false,
    this.segmentDuration = const Duration(minutes: 5),
    this.maxDuration = const Duration(hours: 6),
    this.requestedSampleRateHz = 24000,
    this.requestedBitRateBps = 64000,
    this.channels = 1,
    this.fileExtension = 'm4a',
  });

  final bool continuous;
  final bool unlimitedLocalCapture;
  final bool append;
  final Duration segmentDuration;
  final Duration maxDuration;

  /// Requested values only. Platform/codec may adjust at runtime.
  final int requestedSampleRateHz;
  final int requestedBitRateBps;
  final int channels;
  final String fileExtension;

  int get estimatedBytesPerSegment =>
      requestedBitRateBps * segmentDuration.inSeconds ~/ 8;

  int get estimatedBytesPerHour => requestedBitRateBps * 3600 ~/ 8;

  int get estimatedBytesAtMaxDuration =>
      requestedBitRateBps * maxDuration.inSeconds ~/ 8;

  void validate() {
    if (segmentDuration < const Duration(minutes: 1) ||
        segmentDuration > const Duration(minutes: 15)) {
      throw ArgumentError.value(segmentDuration, 'segmentDuration');
    }

    if (maxDuration <= Duration.zero ||
        (!continuous && maxDuration < segmentDuration) ||
        maxDuration > const Duration(hours: 12)) {
      throw ArgumentError.value(maxDuration, 'maxDuration');
    }

    if (requestedSampleRateHz < 16000 || requestedSampleRateHz > 96000) {
      throw ArgumentError.value(
        requestedSampleRateHz,
        'requestedSampleRateHz',
      );
    }

    if (requestedBitRateBps < 32000 || requestedBitRateBps > 256000) {
      throw ArgumentError.value(
        requestedBitRateBps,
        'requestedBitRateBps',
      );
    }

    if (channels != 1 && channels != 2) {
      throw ArgumentError.value(channels, 'channels');
    }

    if (append && !continuous)
      throw ArgumentError('append_requires_continuous');
    if (fileExtension.toLowerCase() != (continuous ? 'aac' : 'm4a')) {
      throw ArgumentError.value(fileExtension, 'fileExtension');
    }
  }
}

abstract interface class ClinicalLongFormFileCapture {
  Future<void> startSegment({
    required String path,
    required ClinicalLongFormRecordingConfig config,
  });

  Future<void> pause();

  Future<void> resume();

  Future<String?> stopSegment();

  Future<void> cancelSegment();

  Future<void> dispose();
}
