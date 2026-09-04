import 'plantao_provenance.dart';
import 'plantao_response_structure.dart';

enum PlantaoResultStatus { completed, blocked, unavailable, failed }

class PlantaoResult {
  const PlantaoResult({
    required this.requestId,
    required this.status,
    required this.message,
    this.structure,
    this.provenance,
  });

  final String requestId;
  final PlantaoResultStatus status;
  final String message;
  final PlantaoResponseStructure? structure;
  final PlantaoProvenance? provenance;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'requestId': requestId,
      'status': status.name,
      'message': message,
      'structure': structure?.toJson(),
      'provenance': provenance?.toJson(),
    };
  }
}
