import '../entitlement_service.dart';

/// Effective server-authorized capture duration, bounded by the session ceiling.
class RecordingDurationPolicy {
  const RecordingDurationPolicy(this.tier, {required this.limit});
  final EntitlementTier tier;
  bool get premium => tier == EntitlementTier.premium;
  final Duration limit;
  const RecordingDurationPolicy.local()
      : tier = EntitlementTier.free,
        limit = Duration.zero;
  bool get unlimited => limit == Duration.zero;
  bool reached(Duration elapsed) => !unlimited && elapsed >= limit;
  Duration remaining(Duration elapsed) =>
      elapsed >= limit ? Duration.zero : limit - elapsed;

  String remainingLabel(Duration elapsed, {required bool isEs}) {
    final seconds = (remaining(elapsed).inMilliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')} '
        'restantes';
  }

  String? warning(Duration elapsed, {required bool isEs}) {
    final left = remaining(elapsed).inMilliseconds;
    if (unlimited || left <= 0) return null;
    if (left <= 10000) return '10 segundos restantes';
    if (left <= 60000) return '1 minuto restante';
    if (left <= 300000) {
      return '5 minutos restantes';
    }
    return null;
  }

  String completion({required bool isEs}) => isEs
      ? 'Se alcanzó el límite técnico de esta grabación. El audio fue guardado.'
      : 'O limite técnico desta gravação foi atingido. O áudio foi salvo.';
}
